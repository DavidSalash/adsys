#!/bin/bash

# Interfaces
IF_NAT="enp0s3"
IF_INTRA1="enp0s8"     # Red interna 2
IF_INTRA2="enp0s9"     # Red interna 3
IF_HOSTONLY="enp0s10"  # Pública hacia el Host

# IPs destino
IP_WEB=192.168.11.2
IP_SSH=192.168.13.5

# Limpiar reglas anteriores
iptables -F
iptables -X
iptables -Z

# Crear cadenas personalizadas para log
iptables -N LOG_INPUT_ACCEPT
iptables -A LOG_INPUT_ACCEPT -j LOG --log-level 7 --log-prefix "[INPUT_ACCEPT]: "
iptables -A LOG_INPUT_ACCEPT -j ACCEPT

iptables -N LOG_INPUT_DROP
iptables -A LOG_INPUT_DROP -j LOG --log-level 7 --log-prefix "[INPUT_DROP]: "
iptables -A LOG_INPUT_DROP -j DROP

iptables -N LOG_FORWARD_DROP
iptables -A LOG_FORWARD_DROP -j LOG --log-level 7 --log-prefix "[FORWARD_DROP]: "
iptables -A LOG_FORWARD_DROP -j DROP

# Política por defecto
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

# Permitir loopback
iptables -A INPUT -i lo -j LOG_INPUT_ACCEPT

# Permitir pings solo desde la intranet
iptables -A INPUT -p icmp --icmp-type echo-request -i $IF_INTRA1 -j LOG_INPUT_ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -i $IF_INTRA2 -j LOG_INPUT_ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -i $IF_HOSTONLY -j LOG_INPUT_DROP

# Permitir tráfico iniciado desde la máquina (relacionado/establecido)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j LOG_INPUT_ACCEPT

# INTRANET -> INTRANET: permitir todo
iptables -A FORWARD -i $IF_INTRA1 -o $IF_INTRA2 -j ACCEPT
iptables -A FORWARD -i $IF_INTRA2 -o $IF_INTRA1 -j ACCEPT
iptables -A FORWARD -i $IF_INTRA1 -o $IF_INTRA1 -j ACCEPT
iptables -A FORWARD -i $IF_INTRA2 -o $IF_INTRA2 -j ACCEPT

# INTRANET -> EXTRANET (salida permitida)
iptables -A FORWARD -i $IF_INTRA1 -o $IF_HOSTONLY -j ACCEPT
iptables -A FORWARD -i $IF_INTRA2 -o $IF_HOSTONLY -j ACCEPT

# EXTRANET -> INTRANET: permitir solo web y ssh (DNAT + reglas específicas)

## Web: limitar a 25 conexiones por segundo por IP
iptables -A FORWARD -p tcp -i $IF_HOSTONLY -d $IP_WEB --dport 80 -m conntrack --ctstate NEW \
  -m limit --limit 25/second --limit-burst 25 -j ACCEPT

## SSH: limitar a 3 conexiones por minuto por IP
iptables -A FORWARD -p tcp -i $IF_HOSTONLY -d $IP_SSH --dport 22 -m conntrack --ctstate NEW \
  -m recent --set --name SSH --rsource
iptables -A FORWARD -p tcp -i $IF_HOSTONLY -d $IP_SSH --dport 22 -m conntrack --ctstate NEW \
  -m recent --update --seconds 60 --hitcount 3 --name SSH --rsource -j LOG_FORWARD_DROP
iptables -A FORWARD -p tcp -i $IF_HOSTONLY -d $IP_SSH --dport 22 -j ACCEPT

# NAT (enp0s10 es la IP pública que se usa como origen para todo)
iptables -t nat -F

## MASQUERADE para salida a internet
iptables -t nat -A POSTROUTING -o $IF_HOSTONLY -s 192.168.0.0/16 -j MASQUERADE

## Port forwarding (DNAT) desde host hacia servicios
iptables -t nat -A PREROUTING -i $IF_HOSTONLY -p tcp --dport 80 -j DNAT --to-destination $IP_WEB:80
iptables -t nat -A PREROUTING -i $IF_HOSTONLY -p tcp --dport 22 -j DNAT --to-destination $IP_SSH:22

# Reglas de log por defecto al final
iptables -A INPUT -j LOG_INPUT_DROP
iptables -A FORWARD -j LOG_FORWARD_DROP
