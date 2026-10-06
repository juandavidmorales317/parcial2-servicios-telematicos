# Segundo parcial - Servicios Telemáticos

Juan David Morales, código 2230123.

Montaje con tres máquinas Ubuntu 22.04 en VMware, creadas con Vagrant (caja `bento/ubuntu-22.04`).

| Máquina | Hostname | Red externa | Red interna |
|---|---|---|---|
| Servidor 1 (UFW) | srv1-2230123 | 192.168.70.10 | 192.168.50.3 |
| Servidor 2 (vsftpd, SFTP) | srv2-2230123 | no tiene | 192.168.50.2 |
| Cliente | cli-2230123 | 192.168.70.20 | no tiene |

La "IP pública" del enunciado es 192.168.70.10, la del Servidor 1 que ve el cliente. El cliente no tiene ruta hacia 192.168.50.0/24, así que solo llega al Servidor 2 pasando por el Servidor 1.

## Archivos de configuración

- `srv1/before.rules`: reglas NAT (DNAT) del Servidor 1 para el puerto 21, el rango pasivo 50000-50010 y el puerto 2222.
- `srv2/vsftpd.conf`: FTPS con TLS explícito y rango pasivo 50000-50010.
- `srv2/sshd_config`: usuario `sftp_2230123` enjaulado con `ChrootDirectory` y `ForceCommand internal-sftp`.
- `cli/resolved.conf`: DNS sobre TLS con Cloudflare y Google.
- `cli/99-dns.yaml`: evita que el DNS por DHCP de VMware se use en la interfaz eth0.

## Scripts

En `scripts/` están los comandos que se corrieron en cada máquina: `srv1.sh`, `srv2.sh` y `cli.sh`. Los `adduser` piden la contraseña a mano.

## Notas

- Las reglas `ufw route` del puerto 21 y del 22 se agregaron después de comprobar que sin ellas la conexión desde el cliente falla.
- En el Servidor 1 se usó `ufw disable` y `iptables -t nat -F` antes de volver a activar, porque `ufw reload` duplica las reglas NAT.
- Los comandos `resolvectl dns eth0` y `resolvectl domain eth0` del cliente no persisten tras un reinicio.
- El repositorio no incluye claves privadas (`servidor.key`, `ca.key`).
