#!/bin/bash

echo "[+] Limpiando reglas anteriores..."
iptables -F
iptables -t nat -F
iptables -X

echo "[+] Activando reenvío de paquetes..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# -------------------------------------
# VARIABLES - AJUSTAR SI CAMBIAS IPs
# -------------------------------------
DEBIAN2_WEB_IP="192.168.21.22"
DEBIAN5_SSH_IP="192.168.22.25"

# ------------------------------
# 1. Tráfico Intranet completo
# ------------------------------
echo "[+] Permitimos todo el tráfico entre redes internas..."
iptables -A FORWARD -i enp0s9 -o enp0s10 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s9 -j ACCEPT
iptables -A FORWARD -i enp0s9 -o enp0s9 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s10 -j ACCEPT
iptables -A FORWARD -s 192.168.21.0/24 -d 192.168.23.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.22.0/24 -d 192.168.23.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.23.0/24 -d 192.168.21.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.23.0/24 -d 192.168.22.0/24 -j ACCEPT

# ------------------------------------------
# 2. Permitir tráfico de salida (Internet y Host)
# ------------------------------------------
echo "[+] Permitimos tráfico de salida a Internet y Host..."
iptables -A FORWARD -i enp0s9 -o enp0s3 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s3 -j ACCEPT
iptables -A FORWARD -o enp0s3 -j ACCEPT
iptables -A FORWARD -o enp0s8 -j ACCEPT

# -------------------------------
# 3. NAT para salida a Internet
# -------------------------------
echo "[+] Aplicando NAT (MASQUERADE)..."
iptables -t nat -A POSTROUTING -s 192.168.21.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.22.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.23.0/24 -o enp0s3 -j MASQUERADE

# -----------------------------------------------
# 4. Port Forwarding desde Host a debian2 y debian5
# -----------------------------------------------
echo "[+] Redirigiendo puertos desde la extranet..."
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 80 -j DNAT --to-destination $DEBIAN2_WEB_IP:80
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 22 -j DNAT --to-destination $DEBIAN5_SSH_IP:22

# ------------------------------------------------------
# 5. Permitir conexiones establecidas y relacionadas
# ------------------------------------------------------
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# ------------------------------------------
# 6. Permitir tráfico de entrada autorizado
# ------------------------------------------
iptables -A FORWARD -i enp0s8 -p tcp --dport 80 -d $DEBIAN2_WEB_IP -j ACCEPT
iptables -A FORWARD -i enp0s8 -p tcp --dport 22 -d $DEBIAN5_SSH_IP -j ACCEPT

# ------------------------------------------
# 7. Denegar todo lo demás desde extranet
# ------------------------------------------
iptables -A FORWARD -i enp0s8 -j DROP

# ------------------------------------------
# 8. Pings: permitir desde intranet, denegar desde Host
# ------------------------------------------
iptables -A INPUT -s 192.168.21.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.22.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.23.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.56.0/24 -p icmp --icmp-type echo-request -j DROP
