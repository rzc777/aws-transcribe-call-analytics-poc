#!/bin/bash
set -euxo pipefail

apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

mkdir -p /opt/wg-easy/data

cat > /opt/wg-easy/start.sh <<'EOF'
#!/bin/bash
set -euxo pipefail

docker rm -f wg-easy || true

docker run -d \
  --name wg-easy \
  -e INIT_ENABLED=true \
  -e INIT_USERNAME="${wg_admin_username}" \
  -e INIT_PASSWORD="${wg_admin_password}" \
  -e INIT_HOST="${wg_host}" \
  -e INIT_PORT="${wireguard_port}" \
  -e INIT_DNS="${wg_default_dns}" \
  -v /opt/wg-easy/data:/etc/wireguard \
  -p ${wireguard_port}:${wireguard_port}/udp \
  -p ${web_ui_port}:51821/tcp \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.ip_forward=1" \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:15
EOF

chmod +x /opt/wg-easy/start.sh
/opt/wg-easy/start.sh
