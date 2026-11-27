#!/bin/sh
# ~/.xinitrc — paso 2 del arranque del kiosko
#
# `startx` (llamado desde ~/.bash_profile) ejecuta este archivo una vez que X
# está andando. Arranca Openbox, un gestor de ventanas mínimo: no hay
# escritorio, barra ni íconos, lo que ahorra RAM en la Pi de 1 GB.
#
# Al iniciar, Openbox ejecuta ~/.config/openbox/autostart. Si Openbox se
# cierra, X se cierra con él.
exec openbox-session
