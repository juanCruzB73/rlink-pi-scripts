#!/bin/bash
# pi-scripts/install.sh — instalador idempotente
#
# Deja la Pi lista para arrancar sola al kiosco al prender, sin pedir
# usuario/contraseña en pantalla, con las ttys secundarias cerradas y
# los permisos de la clave del agente ajustados.
#
# Pensado para correr sobre Raspberry Pi OS Lite (trixie) recién grabado:
# - usuario rladmin creado (por rpi-imager o raspi-config)
# - Chromium + X mínimos ya instalados
#
# Volvelo a correr cuantas veces quieras: cada paso verifica antes de
# cambiar.
set -euo pipefail

aqui="$(cd "$(dirname "$0")" && pwd)"
log() { echo "[$(date +%H:%M:%S)] $*"; }

[ "$(id -u)" -eq 0 ] || { echo "corré con sudo"; exit 1; }

# 1. Archivos del usuario rladmin
log "Copiando home/rladmin → /home/rladmin"
install -d -o rladmin -g rladmin -m 755 /home/rladmin/.config/openbox
for f in .bash_profile .xinitrc kiosk.sh; do
  install -o rladmin -g rladmin -m 644 "$aqui/home/rladmin/$f" "/home/rladmin/$f"
done
chmod 755 /home/rladmin/kiosk.sh
install -o rladmin -g rladmin -m 644 \
  "$aqui/home/rladmin/.config/openbox/autostart" \
  /home/rladmin/.config/openbox/autostart

# 2. Binarios en /usr/local/bin
log "Instalando rlink-arranque, rlink-reporte, rlink-medir, rlink-setup, rlink-reset, rlink-limpiar, rlink-cmd"
for b in rlink-arranque rlink-reporte rlink-medir rlink-setup rlink-reset rlink-limpiar rlink-cmd; do
  if [ -f "$aqui/usr/local/bin/$b" ]; then
    install -m 755 "$aqui/usr/local/bin/$b" "/usr/local/bin/$b"
  fi
done

# 2b. Paquetes apt necesarios para rlink-cmd (mosquitto_sub/pub).
# apt-get install -y es idempotente: si ya está, no hace nada.
if ! command -v mosquitto_sub >/dev/null 2>&1; then
  log "Instalando mosquitto-clients (necesario para rlink-cmd)"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends mosquitto-clients
fi

# 3. Servicios y timers systemd
log "Instalando units"
for u in rlink-reporte.service rlink-setup.service rlink-limpiar.service rlink-limpiar.timer rlink-cmd.service; do
  if [ -f "$aqui/etc/systemd/system/$u" ]; then
    install -m 644 "$aqui/etc/systemd/system/$u" "/etc/systemd/system/$u"
  fi
done

# 4. Autologin en tty1
log "Habilitando autologin de rladmin en tty1"
install -d -m 755 /etc/systemd/system/getty@tty1.service.d
install -m 644 \
  "$aqui/etc/systemd/system/getty@tty1.service.d/autologin.conf" \
  /etc/systemd/system/getty@tty1.service.d/autologin.conf

# 5. Clave del agente: 640 root:rladmin (si existe)
#    kiosk.sh corre como rladmin y necesita leer la clave para pasarla a Chromium
#    en el query ?agent=. Si queda en 600 root:root, el URL sale con agent vacío
#    y la pantalla no se vincula (quedó así en una iteración anterior y la Pi
#    arrancaba en blanco).
if [ -f /etc/rlink-agent-key ]; then
  log "Ajustando permisos de /etc/rlink-agent-key a 640 root:rladmin"
  chown root:rladmin /etc/rlink-agent-key
  chmod 640 /etc/rlink-agent-key
fi

# 6. HDMI estable (evitar bordes negros).
#
# NOTA: antes probamos con hdmi_force_hotplug / hdmi_drive / config_hdmi_boost
# pero esas tres son flags "legacy" (pre-KMS) y en Raspberry Pi OS trixie con
# driver vc4 KMS entran en conflicto: el GPU de Chromium no levanta
# (dmesg muestra __vc4_hvs_stop_channel / vc4_crtc_disable, y Chromium muere
# con "GPU process launch failed error_code=1002"). Hoy el "no se duerme la
# pantalla" lo garantizan los xset del autostart (-dpms, s off, s noblank),
# así que alcanza con disable_overscan.
cfg=/boot/firmware/config.txt
if [ -f "$cfg" ]; then
  # Limpieza de la versión vieja del bloque, si quedó aplicada en SDs ya
  # instaladas antes de este cambio.
  if grep -q "^# rlink HDMI estable" "$cfg" && grep -q "^hdmi_force_hotplug=1" "$cfg"; then
    log "Removiendo flags HDMI legacy de $cfg (conflicto con vc4 KMS)"
    # Borra desde el header del bloque hasta la línea de disable_overscan inclusive.
    sed -i '/^# rlink HDMI estable/,/^disable_overscan=1/d' "$cfg"
  fi
  if ! grep -q "^# rlink HDMI estable" "$cfg"; then
    log "Agregando bloque HDMI estable a $cfg"
    cat >> "$cfg" <<'EOF'

# rlink HDMI estable — evita bordes negros. Mantener compatibilidad con KMS.
disable_overscan=1
EOF
  fi
fi

# 7. Reload + enable
log "systemd daemon-reload + enable de servicios"
systemctl daemon-reload
systemctl enable rlink-reporte.service >/dev/null 2>&1 || true
systemctl enable rlink-setup.service   >/dev/null 2>&1 || true
systemctl enable rlink-cmd.service     >/dev/null 2>&1 || true
systemctl enable --now rlink-limpiar.timer >/dev/null 2>&1 || true

cat <<EOF

Listo. Los cambios activos sin reboot: servicios rlink-*, permisos de la
clave. El autologin y el enmascarado de ttys se toman en el próximo
reboot (o systemctl restart getty@tty1, pero eso corta el X que está
corriendo).

Para probarlo:  sudo reboot
EOF
