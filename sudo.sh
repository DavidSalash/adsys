
PATH=$PATH/usr/sbin
echo $PATH
apt update && apt install sudo -y
usermod -aG sudo as
su - as
sudo whoami



# Limpiar reglas anteriores
iptables -F
iptables -t nat -F
iptables -X

# Habilitar reenvío de paquetes
echo 1 > /proc/sys/net/ipv4/ip_forward

# 1. Permitir tráfico dentro de la intranet
iptables -A FORWARD -i enp0s9 -o enp0s10 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s9 -j ACCEPT
iptables -A FORWARD -i enp0s9 -o enp0s9 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s10 -j ACCEPT
iptables -A FORWARD -s 192.168.21.0/24 -d 192.168.23.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.22.0/24 -d 192.168.23.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.23.0/24 -d 192.168.21.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.23.0/24 -d 192.168.22.0/24 -j ACCEPT

# 2. Permitir tráfico de salida desde intranet a Internet
iptables -A FORWARD -i enp0s9 -o enp0s3 -j ACCEPT
iptables -A FORWARD -i enp0s10 -o enp0s3 -j ACCEPT
iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
iptables -A FORWARD -o enp0s3 -j ACCEPT

# 3. Hacer NAT para el tráfico saliente hacia Internet
iptables -t nat -A POSTROUTING -s 192.168.21.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.22.0/24 -o enp0s3 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.23.0/24 -o enp0s3 -j MASQUERADE

# 4. Redirección de puertos (Port Forwarding desde Host)
# - HTTP a debian2 (por ejemplo, 192.168.21.22)
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 80 -j DNAT --to-destination 192.168.21.22:80

# - SSH a debian5 (por ejemplo, 192.168.22.25)
iptables -t nat -A PREROUTING -i enp0s8 -p tcp --dport 22 -j DNAT --to-destination 192.168.22.25:22

# 5. Permitir conexiones establecidas y relacionadas
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# 6. Permitir tráfico entrante solo a puertos autorizados desde la extranet
iptables -A FORWARD -i enp0s8 -p tcp --dport 80 -d 192.168.21.22 -j ACCEPT
iptables -A FORWARD -i enp0s8 -p tcp --dport 22 -d 192.168.22.25 -j ACCEPT

# 7. Denegar todo lo demás desde la extranet
iptables -A FORWARD -i enp0s8 -j DROP

# 8. ICMP (ping)
# - Permitir pings desde intranet
iptables -A INPUT -s 192.168.21.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.22.0/24 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -s 192.168.23.0/24 -p icmp --icmp-type echo-request -j ACCEPT

# - Denegar pings desde Host
iptables -A INPUT -s 192.168.56.0/24 -p icmp --icmp-type echo-request -j DROP
