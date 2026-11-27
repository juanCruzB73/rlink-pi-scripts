# ~/.bash_profile — paso 1 del arranque del kiosko
#
# Bash lo ejecuta al iniciar sesión (login shell). Si la sesión es la de la
# pantalla física (tty1) y todavía no hay entorno gráfico, arranca X con
# `startx`, que a su vez lee ~/.xinitrc.
#
# - `exec` reemplaza la shell por X: si X se cierra, la sesión termina y
#   getty vuelve a pedir login (o vuelve a entrar solo, si hay autologin).
# - Por SSH (que no es tty1) no hace nada, así se puede entrar sin levantar
#   otra pantalla.
#
# Ojo: esto corre recién cuando alguien inicia sesión en tty1. Para que la
# pantalla arranque sola después de un corte de luz hace falta autologin en
# tty1 (raspi-config → System Options → Boot / Auto Login → Console Autologin).

# Iniciar entorno gráfico automáticamente en tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
