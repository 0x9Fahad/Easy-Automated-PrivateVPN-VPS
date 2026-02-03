#!/usr/bin/env bash
set -euo pipefail

# ================== CONFIG ==================
WG_IF="${WG_IF:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_SERVER_ADDR="${WG_SERVER_ADDR:-10.8.0.1/24}"
# ============================================

if [[ $EUID -ne 0 ]]; then
  echo "[!] Run as root: sudo bash $0"
  exit 1
fi

echo "[*] Detecting outbound interface..."
OUT_IF="$(ip route | awk '/default/ {print $5; exit}')"
if [[ -z "${OUT_IF}" ]]; then
  echo "[!] Could not detect outbound interface."
  exit 1
fi
echo "[+] Outbound interface: ${OUT_IF}"

echo "[*] Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y wireguard ufw iptables curl

echo "[*] Enabling IPv4 forwarding..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

echo "[*] Generating server keys..."
umask 077
mkdir -p /etc/wireguard
if [[ ! -f /etc/wireguard/server_private.key ]]; then
  wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
fi

SERVER_PRIV="$(cat /etc/wireguard/server_private.key)"
SERVER_PUB="$(cat /etc/wireguard/server_public.key)"

echo "[*] Writing WireGuard config..."
cat > "/etc/wireguard/${WG_IF}.conf" <<EOF
[Interface]
Address = ${WG_SERVER_ADDR}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}

PostUp = iptables -A FORWARD -i ${WG_IF} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${OUT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_IF} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${OUT_IF} -j MASQUERADE
EOF

chmod 600 "/etc/wireguard/${WG_IF}.conf"

echo "[*] Configuring firewall..."
ufw allow OpenSSH >/dev/null || true
ufw allow "${WG_PORT}/udp" >/dev/null || true
ufw --force enable >/dev/null || true

echo "[*] Starting WireGuard..."
systemctl enable "wg-quick@${WG_IF}" >/dev/null
systemctl restart "wg-quick@${WG_IF}"

VPS_IP="$(curl -s ifconfig.me || true)"

echo
echo "============= SERVER READY ============="
echo "Server public key: ${SERVER_PUB}"
echo "Endpoint: ${VPS_IP}:${WG_PORT}"
echo "Interface: ${WG_IF}"
echo "======================================="

# Machine-readable output for client script
echo "OK SERVER_PUB=${SERVER_PUB}"
echo "OK WG_PORT=${WG_PORT}"
echo "OK VPS_IP=${VPS_IP:-}"
