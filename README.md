# Easy-PrivateVPN-VPS
Fully automated private VPN on any VPS using WireGuard. Server bootstrap + client auto-connect.
Private VPN on your own VPS using WireGuard.  
One-command setup for security, red teams, and bug bounty.

Easy-PrivateVPN-VPS lets you:
- Create your own private VPN on any Ubuntu VPS
- Automatically configure the server
- Automatically register and connect clients
- Keep full control of keys and infrastructure
- Rotate IPs instantly by recreating the VPS

No Docker. No cloud lock-in. No third-party VPN providers.

---

## Features

- One-command server setup
- One-command client onboarding
- Secure WireGuard defaults
- Automatic NAT & firewall configuration
- Client keys generated locally
- No passwords inside VPN
- Multi-client support
- Works on any Ubuntu VPS

---

## Requirements

### Server (VPS)
- Ubuntu 20.04 / 22.04 / 24.04
- Public IPv4
- SSH access with sudo

### Client
- Linux / WSL / macOS
- SSH access to the VPS
- `sudo` privileges

---

## Installation

This project consists of two scripts:

- **Server script** → runs on your VPS  
- **Client script** → runs on your local machine  

Total setup time: **~2 minutes**.

---

## Step 1 — Setup the Server (VPS)

SSH into your VPS and create the server script:

```bash
sudo nano /usr/local/bin/wg_server_bootstrap.sh
```

Paste the server script from this repo, then:

```
sudo chmod +x /usr/local/bin/wg_server_bootstrap.sh
sudo /usr/local/bin/wg_server_bootstrap.sh
```

# This will:

- Install WireGuard

- Enable IP forwarding

- Configure firewall

- Generate server keys

- Start the VPN service

## Step 2 — Setup the Client (Local Machine)
On your local machine (WSL/Linux/macOS):

```
nano ~/wg_client_autosetup.sh
```
Paste the client script from this repo, then:

```
chmod +x ~/wg_client_autosetup.sh
```
Run it:

```
./wg_client_autosetup.sh user@VPS_IP VPS_IP 51820 2
```

# You will be prompted for:

1) VPS SSH password

2) VPS sudo password

# The script will:

Generate client keys locally

- SSH into the VPS

- Register your client

- Create local VPN config

- Bring the VPN up automatically

## Step 3 — Verify Connection
Check your public IP:

```
curl ifconfig.me
```

If it shows your VPS IP, the VPN is active.

## Toggle VPN
Turn off
```
sudo wg-quick down wg0
```
Turn on
```
sudo wg-quick up wg0
```
Status
```
sudo wg
```
