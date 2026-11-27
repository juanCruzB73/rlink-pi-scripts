#!/bin/bash
# Script de instalación que corre UNA SOLA VEZ al primer boot
# Se deshabilita a sí mismo cuando termina

set -euo pipefail

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a /var/log/rlink-install.log; }

[ "$(id -u)" -eq 0 ] || { log "ERROR: debe ser root"; exit 1; }

log "=== RLINK FIRST-TIME INSTALLATION ==="

# Si el archivo de mark existe, significa que ya se ejecutó
MARK=/etc/rlink-installed
if [ -f "$MARK" ]; then
  log "Ya instalado. Saliendo."
  exit 0
fi

# Buscar pi-scripts en ubicaciones comunes
SCRIPTS_DIR=""
for path in /tmp/pi-scripts /root/pi-scripts ~/pi-scripts ./pi-scripts; do
  if [ -f "$path/install.sh" ]; then
    SCRIPTS_DIR="$path"
    break
  fi
done

if [ -z "$SCRIPTS_DIR" ]; then
  log "ERROR: No se encontró pi-scripts/install.sh"
  log "Buscar en: /tmp/pi-scripts, /root/pi-scripts, etc."
  exit 1
fi

log "Usando scripts de: $SCRIPTS_DIR"

# Ejecutar install.sh
cd "$SCRIPTS_DIR"
if bash install.sh; then
  log "✓ Instalación completada"
else
  log "ERROR durante la instalación"
  exit 1
fi

# Marcar como instalado
touch "$MARK"

# Deshabilitar el servicio de instalación
log "Deshabilitando el servicio de instalación..."
systemctl disable rlink-install.service 2>/dev/null || true

log "=== FIN DE INSTALACIÓN ==="
log "Servicios habilitados:"
systemctl is-enabled rlink-reporte rlink-setup || true

log "La Pi está lista. Próximo arranque: kiosco o setup según configuración."
