#!/bin/bash
# WireGuard Add Client Script
# Modes: local | mediaserver | fullvpn

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: wg-addclient.sh <clientname> <ip-last-octet> <mode>"
    echo "Modes:"
    echo "  local       - Access all local subnets only"
    echo "  mediaserver - Access 192.168.69.50 only"
    echo "  fullvpn     - All traffic through VPN (tinfoil hat mode)"
    exit 1
fi

CLIENT=$1
CLIENT_IP="10.8.0.$2"
MODE=$3
SERVER_PUBLIC=$(sudo cat /etc/wireguard/server_public.key)

case $MODE in
    local)
        ALLOWED="10.0.0.0/24, 192.168.69.0/24, 192.168.10.0/24, 192.168.144.0/24, 192.168.55.0/24"
        ;;
    mediaserver)
        ALLOWED="192.168.69.50/32"
        ;;
    fullvpn)
        ALLOWED="0.0.0.0/0, ::/0"
        ;;
    *)
        echo "Unknown mode: $MODE. Use local, mediaserver, or fullvpn."
        exit 1
        ;;
esac

PRIVATE=$(wg genkey)
PUBLIC=$(echo "$PRIVATE" | wg pubkey)

sudo tee -a /etc/wireguard/wg0.conf > /dev/null <<WGEOF

[Peer]
# $CLIENT ($MODE)
PublicKey = $PUBLIC
AllowedIPs = $CLIENT_IP/32
WGEOF

sudo systemctl restart wg-quick@wg0

mkdir -p ~/wg-clients
cat > ~/wg-clients/$CLIENT.conf <<WGEOF
[Interface]
PrivateKey = $PRIVATE
Address = $CLIENT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = wg.vpn.speakfreely.uk:51820
AllowedIPs = $ALLOWED
PersistentKeepalive = 25
WGEOF

echo "============================================"
echo " Client : $CLIENT"
echo " Mode   : $MODE"
echo " VPN IP : $CLIENT_IP"
echo " Routes : $ALLOWED"
echo "============================================"
echo ""
qrencode -t ansiutf8 < ~/wg-clients/$CLIENT.conf
