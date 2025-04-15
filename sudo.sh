#!/bin/bash


iptables -F
iptables -t nat -F
iptables -X

# ------------------------------
# 1. Tráfico Intranet completo
# ------------------------------

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

iptables -A FORWARD -i enp0s9 -o enp0s3 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s3 -j ACCEPT
iptables -A FORWARD -o enp0s3 -j ACCEPT
iptables -A FORWARD -o enp0s8 -j ACCEPT

# -------------------------------
# 3. NAT para salida a Internet
# -------------------------------

iptables -t nat -A POSTROUTING -s 192.168.21.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.22.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.23.0/24 -o enp0s3 -j MASQUERADE

# -----------------------------------------------
# 4. Port Forwarding desde Host a debian2 y debian5
# -----------------------------------------------
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 80 -j DNAT --to-destination 192.168.21.22:80
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 22 -j DNAT --to-destination 192.168.23.25:22


# ------------------------------------------------------
# 5. Permitir conexiones establecidas y relacionadas
# ------------------------------------------------------
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# ------------------------------------------
# 6. Permitir tráfico de entrada autorizado
# ------------------------------------------
iptables -A FORWARD -i enp0s8 -p tcp --dport 80 -d 192.168.21.22 -j ACCEPT
iptables -A FORWARD -i enp0s8 -p tcp --dport 22 -d 192.168.23.25 -j ACCEPT

# ------------------------------------------
# 7. Denegar todo lo demás desde extranet
# ------------------------------------------
#iptables -A FORWARD -i enp0s8 -j DROP

# ------------------------------------------
# 8. Pings: permitir desde intranet, denegar desde Host
# ------------------------------------------
iptables -A INPUT -s 192.168.21.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.22.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.23.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.56.0/24 -p icmp --icmp-type echo-request -j DROP
