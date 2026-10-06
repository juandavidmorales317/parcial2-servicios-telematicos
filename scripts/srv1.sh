#!/bin/bash
# Servidor 1 (srv1-2230123): UFW como unico punto de entrada, con DNAT hacia srv2 (192.168.50.2)
# Interfaz externa: eth1 (192.168.70.10). Interfaz interna: eth2 (192.168.50.3). eth0 es la NAT de Vagrant.
# Se ejecuta como usuario vagrant.

sudo hostnamectl set-hostname srv1-2230123

# Reenvio IP
sudo sed -i 's|^#net/ipv4/ip_forward=1|net/ipv4/ip_forward=1|' /etc/ufw/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1

# Reglas NAT al inicio de before.rules (antes del bloque *filter)
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.orig
cat > /tmp/nat.txt <<'EOF'
*nat
:PREROUTING ACCEPT [0:0]
-A PREROUTING -i eth1 -p tcp --dport 21 -j DNAT --to-destination 192.168.50.2:21
-A PREROUTING -i eth1 -p tcp --dport 50000:50010 -j DNAT --to-destination 192.168.50.2
-A PREROUTING -i eth1 -p tcp --dport 2222 -j DNAT --to-destination 192.168.50.2:22
COMMIT

EOF
sudo sh -c 'cat /tmp/nat.txt /etc/ufw/before.rules.orig > /etc/ufw/before.rules'

# Politicas por defecto
sudo ufw default deny incoming
sudo ufw default deny routed
sudo ufw default allow outgoing

# Administracion SSH del propio servidor 1
sudo ufw allow 22/tcp

# Reenvio hacia srv2: rango pasivo de FTPS
sudo ufw route allow proto tcp from any to 192.168.50.2 port 50000:50010

# Estas dos reglas se agregaron despues de comprobar que, sin ellas,
# la conexion al 21 (FTPS) y al 2222 (SFTP) falla desde el cliente.
sudo ufw route allow proto tcp from any to 192.168.50.2 port 21
sudo ufw route allow proto tcp from any to 192.168.50.2 port 22

# Se apaga y se vuelve a encender para no duplicar las reglas NAT (ufw reload las duplica)
sudo ufw disable
sudo iptables -t nat -F
sudo ufw --force enable

# Evidencias
sudo ufw status verbose
sudo iptables -t nat -L -n -v
