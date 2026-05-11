#!/bin/bash
set -euxo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard qrencode iptables

SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

NIC=$(ip route | awk '/default/ {print $5}' | head -n1)

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${wg_server_ip}
ListenPort = ${wireguard_port}
PrivateKey = $SERVER_PRIV
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $NIC -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $NIC -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = ${wg_client_ip}
EOF

cat > /etc/sysctl.d/99-wireguard-forward.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl --system

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

mkdir -p /opt/wireguard
chmod 700 /opt/wireguard

cat > /opt/wireguard/windows-client.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = ${wg_client_ip}
DNS = ${wg_dns}

[Peer]
PublicKey = $SERVER_PUB
AllowedIPs = 0.0.0.0/0
Endpoint = ${wg_host}:${wireguard_port}
PersistentKeepalive = 25
EOF
chmod 600 /opt/wireguard/windows-client.conf

qrencode -t ansiutf8 < /opt/wireguard/windows-client.conf > /opt/wireguard/windows-client.qr.txt

cat > /usr/local/bin/restart-docker.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo "[INFO] restarting docker recovery script..."

if ! command -v docker >/dev/null 2>&1; then
  echo "[WARN] docker is not installed on this instance. Nothing to restart."
  exit 0
fi

systemctl daemon-reload
systemctl restart docker
sleep 5

echo "[INFO] docker containers:"
docker ps -a || true

# Recover common WireGuard container names if this instance is running a docker-based VPN variant.
for container_name in wg-easy wireguard; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$container_name"; then
    echo "[INFO] starting/restarting container: $container_name"
    docker start "$container_name" || docker restart "$container_name" || true
  fi
done

echo "[INFO] docker recovery completed."
EOF
chmod +x /usr/local/bin/restart-docker.sh

cat > /etc/systemd/system/docker-recovery.service <<'EOF'
[Unit]
Description=Recover Docker containers after EC2 reboot
After=docker.service network-online.target
Wants=network-online.target
ConditionPathExists=/usr/bin/docker

[Service]
Type=oneshot
ExecStart=/usr/local/bin/restart-docker.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker-recovery.service || true
