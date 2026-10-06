#!/bin/bash
# Cliente Linux (cli-2230123, 192.168.70.20): DNS sobre TLS con systemd-resolved y pruebas de FTPS y SFTP
# Se ejecuta como usuario vagrant.

sudo hostnamectl set-hostname cli-2230123

# ---------- DNS sobre TLS ----------
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.orig
sudo tee /etc/systemd/resolved.conf > /dev/null <<'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
FallbackDNS=1.0.0.1#cloudflare-dns.com 8.8.4.4#dns.google
DNSOverTLS=yes
EOF

# Evita que el DNS entregado por DHCP (VMware, sin DoT) se use en eth0
sudo tee /etc/netplan/99-dns.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        use-dns: false
EOF
sudo chmod 600 /etc/netplan/*.yaml
sudo netplan apply

sudo systemctl restart systemd-resolved
# Estos dos comandos no sobreviven a un reinicio de la VM; hay que repetirlos al arrancar
sudo resolvectl dns eth0 1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
sudo resolvectl domain eth0 "~."

ls -l /etc/resolv.conf      # debe apuntar a stub-resolv.conf (127.0.0.53)
resolvectl status           # +DNSOverTLS en la linea Protocols

# Consultas por el stub (sin @servidor)
sudo apt install -y dnsutils
resolvectl query google.com
dig github.com
dig uao.edu.co

# Captura con DoT activo (puerto 853)
sudo timeout 10 tcpdump -i eth0 -Z root -w /vagrant/dot.pcap 'port 853 or port 53' &
sleep 1; resolvectl flush-caches; resolvectl query wikipedia.org; wait

# Captura con DoT desactivado (puerto 53)
sudo sed -i 's/^DNSOverTLS=yes/DNSOverTLS=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
sudo timeout 10 tcpdump -i eth0 -Z root -w /vagrant/dns_plano.pcap 'port 853 or port 53' &
sleep 1; resolvectl flush-caches; resolvectl query wikipedia.org; wait

# Se vuelve a activar DoT
sudo sed -i 's/^DNSOverTLS=no/DNSOverTLS=yes/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
sudo resolvectl dns eth0 1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
sudo resolvectl domain eth0 "~."

# dig directo a 8.8.8.8: sale por UDP/53, sin DoT
sudo timeout 6 tcpdump -n -i eth0 'port 53 or port 853' &
sleep 1; dig @8.8.8.8 example.com +short; wait

# Bloqueo del 853 con DoT = yes (la resolucion falla)
sudo iptables -A OUTPUT -p tcp --dport 853 -j REJECT
resolvectl flush-caches
resolvectl query example.net
sudo iptables -D OUTPUT -p tcp --dport 853 -j REJECT

# ---------- Pruebas FTPS (desde el cliente, ca.crt copiado a ~) ----------
cp /vagrant/ca.crt ~/ca.crt
echo QUIT | openssl s_client -connect 192.168.70.10:21 -starttls ftp -CAfile ~/ca.crt
echo "prueba ftps 2230123" > 2230123.txt
sudo apt install -y lftp
lftp -u ftpuser 192.168.70.10 -e "set ftp:ssl-force true; set ftp:ssl-protect-data true; set ssl:ca-file /home/vagrant/ca.crt; set ssl:verify-certificate yes"

# ---------- Prueba SFTP por el puerto 2222 de srv1 ----------
sftp -P 2222 sftp_2230123@192.168.70.10
# Dentro de sftp: ls, cd upload, put /home/vagrant/2230123.txt, get 2230123.txt descargado_sftp.txt
nc -zv -w 5 192.168.50.2 22   # debe fallar: el 22 de srv2 no es alcanzable directo
