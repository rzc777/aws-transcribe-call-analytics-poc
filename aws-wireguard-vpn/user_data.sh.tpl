#!/bin/bash
set -euxo pipefail

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard qrencode iptables-persistent

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

sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

mkdir -p /opt/wireguard

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
