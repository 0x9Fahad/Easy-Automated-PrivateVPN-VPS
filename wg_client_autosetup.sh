#!/usr/bin/env bash
set -euo pipefail

# Usage:
# ./wg_client_autosetup.sh <ssh_user@vps_ip> <vps_ip> [port] [client_last_octet]
#


if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ssh_user@vps_ip> <vps_ip> [port] [client_last_octet]"
  exit 1
fi

SSH_TARGET="$1"
VPS_IP="$2"
WG_PORT="${3:-51820}"
CLIENT_LAST="${4:-2}"

WG_IF="wg0"
CLIENT_IP="10.8.0.${CLIENT_LAST}"
CLIENT_ADDR="${CLIENT_IP}/24"
DNS_SERVER="1.1.1.1"

echo "[*] Installing WireGuard locally..."
sudo apt-get update -y
sudo apt-get install -y wireguard resolvconf curl

echo "[*] Generating client keys..."
umask 077
mkdir -p ~/.wireguard
wg genkey | tee ~/.wireguard/client_private.key | wg pubkey > ~/.wireguard/client_public.key

CLIENT_PRIV="$(cat ~/.wireguard/client_private.key)"
CLIENT_PUB="$(cat ~/.wireguard/client_public.key)"

echo "[+] Client public key: ${CLIENT_PUB}"

echo "[*] Bootstrapping server (sudo password will be requested)..."
SERVER_OUT="$(ssh -t -o StrictHostKeyChecking=accept-new "${SSH_TARGET}" "sudo /usr/local/bin/wg_server_bootstrap.sh")"

SERVER_PUB="$(echo "${SERVER_OUT}" | sed -n 's/^OK SERVER_PUB=\(.*\)$/\1/p' | tail -n1)"
SERVER_PORT="$(echo "${SERVER_OUT}" | sed -n 's/^OK WG_PORT=\(.*\)$/\1/p' | tail -n1)"

if [[ -n "${SERVER_PORT}" ]]; then
  WG_PORT="${SERVER_PORT}"
fi

echo "[+] Server public key: ${SERVER_PUB}"
echo "[+] Endpoint: ${VPS_IP}:${WG_PORT}"

echo "[*] Adding client peer on server..."
ssh -t "${SSH_TARGET}" "sudo bash -lc '
CONF=/etc/wireguard/${WG_IF}.conf
grep -q \"${CLIENT_PUB}\" \"\$CONF\" || cat >> \"\$CONF\" <<EOF

[Peer]
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}/32
EOF
systemctl restart wg-quick@${WG_IF}
'"

echo "[*] Writing local client config..."
sudo mkdir -p /etc/wireguard
sudo bash -lc "cat > /etc/wireguard/${WG_IF}.conf" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_ADDR}
DNS = ${DNS_SERVER}

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${VPS_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

sudo chmod 600 /etc/wireguard/${WG_IF}.conf

echo "[*] Bringing VPN up..."
sudo wg-quick down ${WG_IF} >/dev/null 2>&1 || true
sudo wg-quick up ${WG_IF}

echo
echo "============= DONE ============="
echo "Client IP: ${CLIENT_ADDR}"
echo "Check:"
echo "  sudo wg"
echo "  curl ifconfig.me"
echo "Toggle:"
echo "  sudo wg-quick down wg0"
echo "  sudo wg-quick up wg0"
echo "==============================="
