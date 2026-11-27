# Scripts de la Pi de prueba

Copia de los archivos propios de `rlinkmanager2` (Raspberry Pi 4 de 1 GB, Debian 13), tomada el
2026-10-15. La estructura de carpetas replica las rutas de la Pi.

Es lo que corre hoy en la prueba de la versión 100 % web, sin sidecar. Reemplaza en la práctica a
`start-browser.sh`, que levanta un Rails local y tiene el token fijo.

Cada archivo tiene comentarios que explican qué hace. Esos comentarios se agregaron en el repo y
no están en la Pi; el código es el mismo.

Cómo arranca la pantalla, en orden:

```
autologin rladmin en tty1 → .bash_profile → startx → .xinitrc → openbox
                          → .config/openbox/autostart → dex-arranque
                               ├─ setup.sh (si no se vinculó todavía)
                               └─ kiosk.sh → chromium --kiosk (en loop)

systemd → dex-reporte.service → dex-reporte (aparte del kiosko: reporta aunque X se caiga)
        → dex-setup.service   → dex-setup   (red, hotspot, portal)
```

El autologin lo da `etc/systemd/system/getty@tty1.service.d/autologin.conf`. `.bash_profile`
hace `exec startx`: X reemplaza al bash, así que en tty1 no queda shell interactiva. Para
administrar hay dos caminos: Ctrl+Alt+F2..F6 (login normal pidiendo usuario y contraseña) o
SSH. Cualquier cosa privilegiada sigue pidiendo contraseña de sudo.

| Archivo | Qué hace |
|---|---|
| `home/rladmin/.bash_profile` | Al iniciar sesión en tty1, ejecuta `startx` |
| `home/rladmin/.xinitrc` | Arranca `openbox-session` |
| `home/rladmin/.config/openbox/autostart` | Lanza `kiosk.sh` |
| `home/rladmin/kiosk.sh` | Desactiva el blanking (`xset`), oculta el cursor (`unclutter`) y relanza Chromium `--kiosk` contra `https://carteleria.rlink.com.ar/player?host=<hostname>&agent=<clave>` cada vez que se cierra. Esa URL muestra el código de vinculación o entra a la pantalla asignada (ver [plan-vinculacion-dispositivos.md](../docs/plan-vinculacion-dispositivos.md)). La clave del agente la lee de `/etc/dex-agent-key`. En `rlinkmanager2` está en uso desde el 16/10; la versión anterior, que abría la raíz del sitio (y por eso caía en el login del admin), quedó en `~/kiosk.sh.viejo` |
| `usr/local/bin/dex-reporte` | Agente: cada 60 s manda memoria, swap, CMA, RAM de Chromium, CPU, temperatura, throttling, reinicios y red (Wi-Fi o cable, nombre de la red, señal en dBm y si hay internet) al admin (Dispositivos → lista y ficha del equipo, con gráficos y alertas). La red la lee con `nmcli`, así que necesita NetworkManager (viene en Raspberry Pi OS desde bookworm). Sin red guarda hasta una semana y la manda al volver. Genera `/etc/dex-agent-key` la primera vez |
| `etc/systemd/system/dex-reporte.service` | Corre `dex-reporte` como servicio (root, `Restart=always`, `Nice=10`). Log: `journalctl -u dex-reporte -f` |
| `usr/local/bin/dex-medir` | Medición cada 10 s a CSV ([docs/medicion-pi4-1gb.md](../docs/medicion-pi4-1gb.md) §4.1). No arranca solo después de un reinicio: en `rlinkmanager2` quedó detenido con el reinicio del 16/10 (el CSV sigue en `/var/tmp/E8.csv`) |

Instalar en una Pi nueva (usuario `rladmin`):

```bash
sudo apt update
sudo apt install -y xserver-xorg xinit openbox unclutter chromium qrencode network-manager
sudo bash install.sh
sudo reboot
```

`install.sh` es idempotente: copia los `home/rladmin/`, instala los `/usr/local/bin/dex-*`,
los units de systemd, deja el autologin de `rladmin` en tty1 y ajusta `/etc/dex-agent-key` a
600 root. El reboot activa el autologin; si lo salteás, la sesión del kiosco que ya está
corriendo sigue andando pero el cambio de autologin no se toma.

Para armar la imagen de la SD con todo esto preinstalado, ver
[../docs/imagen-pi.md](../docs/imagen-pi.md).

Actualizar el agente en una Pi que ya lo tiene (no pierde lo pendiente: queda en
`/var/lib/dex-reporte/`):

```bash
sudo cp /usr/local/bin/dex-reporte /usr/local/bin/dex-reporte.anterior
sudo install -m 755 usr/local/bin/dex-reporte /usr/local/bin/
sudo systemctl restart dex-reporte
journalctl -u dex-reporte -f      # sin "envío fallido" = está mandando
```

Cambiar `kiosk.sh` siempre con `mv` de un archivo nuevo, nunca editándolo en el lugar: el loop
que está corriendo lee el script mientras se ejecuta. El cambio se toma en el próximo arranque de
X (o reiniciando la Pi).

Falta en esta copia:
- **El loop que escribe `~/registro.txt`.** Se tipeó a mano en una terminal y no quedó guardado.
  `dex-reporte` lo reemplaza.
