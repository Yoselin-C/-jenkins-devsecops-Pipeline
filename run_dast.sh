#!/bin/bash
# ============================================================
# DAST - Dynamic Application Security Testing
# Herramienta: OWASP ZAP (Zed Attack Proxy)
# ============================================================

TARGET_URL=${1:-"http://localhost:5000"}
REPORT_DIR=${2:-"reports"}
REPORT_FILE="$REPORT_DIR/dast-report.html"

echo "============================================"
echo " DAST - OWASP ZAP Baseline Scan"
echo " Target: $TARGET_URL"
echo "============================================"

mkdir -p "$REPORT_DIR"

# Verificar si la app está respondiendo
echo "[*] Verificando disponibilidad del target..."
for i in {1..10}; do
    if curl -s --max-time 3 "$TARGET_URL/health" > /dev/null 2>&1; then
        echo "[+] Target disponible en $TARGET_URL"
        break
    fi
    echo "    Intento $i/10 - esperando..."
    sleep 3
done

# Ejecutar ZAP Baseline Scan
echo "[*] Iniciando escaneo DAST con OWASP ZAP..."

docker run --rm \
    --network host \
    -v "$(pwd)/$REPORT_DIR:/zap/wrk:rw" \
    ghcr.io/zaproxy/zaproxy:stable \
    zap-baseline.py \
    -t "$TARGET_URL" \
    -r "dast-report.html" \
    -J "dast-report.json" \
    -l WARN \
    --auto 2>&1 | tee "$REPORT_DIR/dast-output.log"

ZAP_EXIT=$?

echo ""
echo "============================================"
if [ -f "$REPORT_DIR/dast-report.html" ]; then
    echo "[+] Reporte DAST generado: $REPORT_FILE"
else
    echo "[!] Reporte no generado - revisar dast-output.log"
fi

# ZAP baseline: exit 0 = sin alertas, 1 = alertas WARN, 2 = alertas FAIL
if [ $ZAP_EXIT -eq 0 ]; then
    echo "[+] DAST completado: sin alertas críticas"
elif [ $ZAP_EXIT -eq 1 ]; then
    echo "[!] DAST completado: alertas de advertencia encontradas (revisar reporte)"
    exit 0  # No falla el pipeline por warnings
else
    echo "[-] DAST completado: alertas críticas encontradas"
    exit 1
fi
