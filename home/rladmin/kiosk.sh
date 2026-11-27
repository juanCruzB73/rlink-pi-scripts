#!/bin/bash
# ~/kiosk.sh — paso 4 del arranque: el kiosko de cartelería
#
# Lo lanza ~/.config/openbox/autostart. Deja la pantalla siempre encendida,
# sin cursor, y mantiene Chromium a pantalla completa mostrando el player.
# Si Chromium se cierra o se cae, lo vuelve a abrir a los 5 s.
#
# Cadena completa: tty1 → .bash_profile → startx → .xinitrc → openbox
#                  → autostart → kiosk.sh → chromium
#
# Notas:
# - Esta copia ya apunta a /player (vinculación por código). Requiere que esa
#   versión del servidor esté desplegada; hasta entonces la Pi sigue con la
#   URL vieja.
# - Chromium abre la página directamente desde el servidor: no hay Rails ni
#   sidecar en la Pi. El modo offline lo dan el service worker y el Cache
#   Storage del navegador.
# - El paquete chromium de Raspberry Pi OS agrega sus propias flags además de
#   las de acá (por ejemplo --use-angle=gles y --enable-gpu-rasterization).
#   Se ven con: ps -o cmd -C chromium
# - Para reiniciar Chromium a mano (por ejemplo, el reinicio de madrugada del
#   protocolo de medición): pkill -o chromium. Este loop lo vuelve a abrir.

# Desactivar protector de pantalla
xset s off        # sin protector de pantalla
xset s noblank    # que X no ponga la pantalla en negro
xset -dpms        # sin ahorro de energía: el monitor nunca se apaga

# Ocultar cursor
# Lo esconde tras 0,5 s sin mover el mouse; -root lo oculta también sobre el fondo.
unclutter -idle 0.5 -root &

# URL del servidor de contenidos
# /player es la entrada fija de todos los kioscos: la primera vez muestra un código para
# vincular el equipo desde Admin → Dispositivos; después entra sola a la pantalla asignada (y
# se cambia sola si en el admin le asignan otra). ?host= es para que el admin muestre el
# hostname del equipo; ?agent= es la clave de rlink-reporte, para que el servidor una las
# métricas de la Pi con este navegador. Ver docs/plan-vinculacion-dispositivos.md.
# (Antes abría la raíz del sitio, que lleva al login del admin.)
AGENT=$(cat /etc/rlink-agent-key 2>/dev/null)
URL="https://carteleria.rlink.com.ar/player?host=$(hostname)&agent=${AGENT}"

# Ejecutar Chromium y reiniciarlo si se cierra
while true; do

    # --kiosk                             pantalla completa, sin barras ni forma de salir
    # --no-first-run                      sin el asistente de primer uso
    # --no-default-browser-check          sin preguntar si es el navegador predeterminado
    # --disable-session-crashed-bubble    sin el cartel "Chromium no se cerró correctamente"
    #                                     después de un corte de luz o de un pkill
    # --disable-infobars                  sin barras de aviso arriba de la página
    # --autoplay-policy=...               deja arrancar los videos con sonido sin que
    #                                     nadie toque la pantalla
    chromium \
      --kiosk \
      --no-first-run \
      --no-default-browser-check \
      --disable-session-crashed-bubble \
      --disable-infobars \
      --autoplay-policy=no-user-gesture-required \
      --no-sandbox \
      --disable-gpu \
      --in-process-gpu \
      --enable-logging=stderr --v=1 \
      "$URL" > /tmp/chromium.log 2>&1

    echo "Chromium finalizado. Reiniciando en 5 segundos..."
    sleep 5

done
