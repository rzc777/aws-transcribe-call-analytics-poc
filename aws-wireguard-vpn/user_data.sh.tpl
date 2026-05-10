#!/bin/bash
set -euxo pipefail

apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

mkdir -p /opt/wg-easy

cat > /opt/wg-easy/docker-compose.yml <<EOF
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    environment:
      - PASSWORD=${wg_password}
      - WG_DEFAULT_DNS=${wg_default_dns}
      - WG_PORT=${wireguard_port}
      - WG_ALLOWED_IPS=0.0.0.0/0
    volumes:
      - /opt/wg-easy/data:/etc/wireguard
    ports:
      - "${wireguard_port}:${wireguard_port}/udp"
      - "${web_ui_port}:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
EOF

cd /opt/wg-easy

docker compose up -d || docker run -d \
  --name wg-easy \
  -e PASSWORD=${wg_password} \
  -e WG_DEFAULT_DNS=${wg_default_dns} \
  -e WG_PORT=${wireguard_port} \
  -e WG_ALLOWED_IPS=0.0.0.0/0 \
  -v /opt/wg-easy/data:/etc/wireguard \
  -p ${wireguard_port}:${wireguard_port}/udp \
  -p ${web_ui_port}:51821/tcp \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.ip_forward=1" \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:latest
