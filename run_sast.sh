#!/bin/bash
# ============================================================
# SAST - Static Application Security Testing
# Herramienta: Bandit (análisis de código Python)
# ============================================================

SRC_DIR=${1:-"app"}
REPORT_DIR=${2:-"reports"}

echo "============================================"
echo " SAST - Bandit Security Scan"
echo " Analizando: $SRC_DIR"
echo "============================================"

mkdir -p "$REPORT_DIR"

# Verificar instalación de bandit
if ! command -v bandit &> /dev/null; then
    echo "[*] Instalando Bandit..."
    pip install bandit --quiet
fi

echo "[*] Ejecutando análisis estático..."

# Bandit con nivel de severidad MEDIUM o superior
bandit -r "$SRC_DIR" \
    -f json \
    -o "$REPORT_DIR/sast-report.json" \
    -ll \
    --exit-zero 2>&1

bandit -r "$SRC_DIR" \
    -f html \
    -o "$REPORT_DIR/sast-report.html" \
    -ll \
    --exit-zero 2>&1

# Reporte en consola para Jenkins
echo ""
echo "[*] Resumen de hallazgos SAST:"
bandit -r "$SRC_DIR" -ll --exit-zero 2>&1

echo ""
echo "============================================"
echo "[+] Reporte SAST generado en $REPORT_DIR/"
echo "    - sast-report.json"
echo "    - sast-report.html"
echo "============================================"
