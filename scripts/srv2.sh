#!/bin/bash
# Servidor 2 (srv2-2230123, 192.168.50.2): vsftpd con FTPS y OpenSSH con SFTP enjaulado
# Se ejecuta como usuario vagrant. Los adduser piden la contrasena a mano.

sudo hostnamectl set-hostname srv2-2230123

# Ruta de retorno hacia la red del cliente, pasando por srv1
sudo tee /etc/netplan/60-ruta.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    eth1:
      routes:
        - to: 192.168.70.0/24
          via: 192.168.50.3
EOF
sudo chmod 600 /etc/netplan/*.yaml
sudo netplan apply

# ---------- CA y certificado del servidor (OpenSSL) ----------
mkdir -p ~/certs && cd ~/certs
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
  -subj "/C=CO/ST=Valle del Cauca/L=Cali/O=UAO/CN=CA Servicios Telematicos 2230123" -out ca.crt
openssl genrsa -out servidor.key 2048
openssl req -new -key servidor.key \
  -subj "/C=CO/ST=Valle del Cauca/L=Cali/O=UAO/CN=192.168.70.10" -out servidor.csr
cat > servidor.ext <<'EOF'
subjectAltName=IP:192.168.70.10,IP:192.168.50.2,DNS:srv1-2230123
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF
openssl x509 -req -in servidor.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out servidor.crt -days 365 -sha256 -extfile servidor.ext
openssl verify -CAfile ca.crt servidor.crt
cp ca.crt servidor.crt servidor.key /vagrant/

# ---------- vsftpd (FTPS, TLS explicito) ----------
sudo apt update && sudo apt install -y vsftpd
sudo cp /vagrant/servidor.crt /etc/ssl/certs/servidor.crt
sudo cp /vagrant/servidor.key /etc/ssl/private/servidor.key
sudo chmod 600 /etc/ssl/private/servidor.key
sudo adduser ftpuser

sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
sudo tee /etc/vsftpd.conf > /dev/null <<'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd

# TLS explicito
ssl_enable=YES
rsa_cert_file=/etc/ssl/certs/servidor.crt
rsa_private_key_file=/etc/ssl/private/servidor.key
force_local_logins_ssl=YES
force_local_data_ssl=YES
ssl_sslv2=NO
ssl_sslv3=NO
ssl_tlsv1=NO
ssl_ciphers=HIGH
require_ssl_reuse=NO

# Modo pasivo
pasv_enable=YES
pasv_min_port=50000
pasv_max_port=50010
pasv_address=192.168.70.10
EOF
sudo systemctl restart vsftpd
sudo ss -tlnp | grep :21

# ---------- SFTP con OpenSSH (usuario enjaulado) ----------
sudo adduser --gecos "" sftp_2230123
sudo mkdir -p /srv/sftp/sftp_2230123/upload
sudo chown root:root /srv/sftp /srv/sftp/sftp_2230123
sudo chmod 755 /srv/sftp /srv/sftp/sftp_2230123
sudo chown sftp_2230123:sftp_2230123 /srv/sftp/sftp_2230123/upload

sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
sudo tee -a /etc/ssh/sshd_config > /dev/null <<'EOF'

Match User sftp_2230123
    ChrootDirectory /srv/sftp/sftp_2230123
    ForceCommand internal-sftp
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOF
sudo sshd -t
sudo systemctl restart ssh

# Huella de la clave de host, para compararla con la que muestra el cliente
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
