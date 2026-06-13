#!/bin/bash
# ============================================================
# MANEJO DE PAQUETES - Auditoría de dependencias
# Herramienta: pip-audit (CVE database scan)
# ============================================================

REPORT_DIR=${1:-"reports"}
REQUIREMENTS=${2:-"requirements.txt"}

echo "============================================"
echo " Manejo de Paquetes - Auditoría de CVEs"
echo " Archivo: $REQUIREMENTS"
echo "============================================"

mkdir -p "$REPORT_DIR"

# Instalar dependencias del proyecto
echo "[*] Instalando paquetes desde $REQUIREMENTS..."
pip install -r "$REQUIREMENTS" --quiet

echo ""
echo "[*] Versiones instaladas:"
pip list --format=columns

# Auditar con pip-audit
echo ""
echo "[*] Ejecutando auditoría de seguridad con pip-audit..."
pip install pip-audit --quiet

pip-audit \
    -r "$REQUIREMENTS" \
    -f json \
    -o "$REPORT_DIR/packages-audit.json" \
    --progress-spinner off 2>&1

PIP_EXIT=$?

# También generar en formato legible
pip-audit \
    -r "$REQUIREMENTS" \
    --progress-spinner off 2>&1 | tee "$REPORT_DIR/packages-audit.txt"

echo ""
echo "============================================"
if [ $PIP_EXIT -eq 0 ]; then
    echo "[+] Sin vulnerabilidades conocidas en dependencias"
else
    echo "[!] Se encontraron vulnerabilidades - revisar packages-audit.json"
    echo "    Considera actualizar los paquetes afectados"
fi
echo "Reportes: $REPORT_DIR/packages-audit.{json,txt}"
echo "============================================"

# No fallar pipeline por vulnerabilidades en deps (modo informativo)
exit 0
