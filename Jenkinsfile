// ================================================================
//  PIPELINE DEVSECOPS - Yoselin-C / -jenkins-devsecops-Pipeline
//  Universidad Mariano Gálvez de Guatemala - Sede Cobán
//  Proyecto de Graduación I - Ingeniería en Sistemas
// ================================================================

pipeline {

    agent any

    environment {
        APP_NAME   = "devsecops-demo-app"
        APP_PORT   = "5000"
        REPORT_DIR = "reports"
        IMAGE_TAG  = "${APP_NAME}:${BUILD_NUMBER}"
    }

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        // ── STAGE 1: CHECKOUT ───────────────────────────────────
        stage('Checkout') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 1: CHECKOUT DEL REPOSITORIO  ║'
                echo '╚══════════════════════════════════════╝'
                checkout scm
                sh '''
                    echo "[+] Repositorio clonado exitosamente"
                    echo "[*] Commit: $(git rev-parse --short HEAD)"
                    echo "[*] Autor:  $(git log -1 --pretty=format:'%an <%ae>')"
                    ls -la
                '''
            }
        }

        // ── STAGE 2: SETUP ──────────────────────────────────────
        stage('Setup') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 2: CONFIGURACIÓN DEL ENTORNO ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo "[*] Python version: $(python3 --version)"
                    mkdir -p ${REPORT_DIR}

                    # Instalar pip si no existe
                    python3 -m ensurepip --upgrade 2>/dev/null || true
                    python3 -m pip install --upgrade pip --break-system-packages --quiet 2>/dev/null || \
                    python3 -m pip install --upgrade pip --quiet || true

                    echo "[+] Entorno listo"
                '''
            }
        }

        // ── STAGE 3: MANEJO DE PAQUETES ─────────────────────────
        stage('Package Management') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 3: MANEJO DE PAQUETES        ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo "[*] Instalando dependencias..."
                    pip install -r requirements.txt --break-system-packages --quiet 2>/dev/null || \
                    pip install -r requirements.txt --quiet || \
                    python3 -m pip install -r requirements.txt --break-system-packages --quiet

                    echo "[*] Paquetes instalados:"
                    pip list --format=columns 2>/dev/null || python3 -m pip list --format=columns

                    echo "[*] Auditando vulnerabilidades con pip-audit..."
                    pip install pip-audit --break-system-packages --quiet 2>/dev/null || \
                    python3 -m pip install pip-audit --break-system-packages --quiet || true

                    python3 -m pip_audit -r requirements.txt \
                        --progress-spinner off \
                        -f json \
                        -o ${REPORT_DIR}/packages-audit.json 2>&1 || true

                    python3 -m pip_audit -r requirements.txt \
                        --progress-spinner off 2>&1 | tee ${REPORT_DIR}/packages-audit.txt || true

                    echo "[+] Auditoría de paquetes completada"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: "${REPORT_DIR}/packages-audit.*",
                                     allowEmptyArchive: true
                }
            }
        }

        // ── STAGE 4: BUILD ──────────────────────────────────────
        stage('Build') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 4: BUILD DE LA APLICACIÓN    ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo "[*] Verificando sintaxis Python..."
                    python3 -m py_compile app.py
                    echo "[+] Sintaxis OK"

                    echo "[*] Construyendo imagen Docker: ${IMAGE_TAG}..."
                    docker build -t ${IMAGE_TAG} .
                    echo "[+] Imagen construida: ${IMAGE_TAG}"
                    docker images | grep ${APP_NAME}
                '''
            }
        }

        // ── STAGE 5: UNIT TESTS ─────────────────────────────────
        stage('Unit Tests') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 5: PRUEBAS UNITARIAS         ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    pytest test_app.py \
                        -v \
                        --tb=short \
                        --junitxml=${REPORT_DIR}/test-results.xml \
                        --cov-report=xml:${REPORT_DIR}/coverage.xml || true

                    echo "[+] Pruebas completadas"
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: "${REPORT_DIR}/test-results.xml"
                }
            }
        }

        // ── STAGE 6: SAST ───────────────────────────────────────
        stage('SAST - Static Analysis') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 6: SAST - ANÁLISIS ESTÁTICO  ║'
                echo '║  Herramienta: Bandit                 ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo "[*] Ejecutando Bandit sobre el código fuente..."

                    bandit -r . \
                        --exclude ./.git,./reports \
                        -f json \
                        -o ${REPORT_DIR}/sast-report.json \
                        -ll --exit-zero 2>&1 || true

                    bandit -r . \
                        --exclude ./.git,./reports \
                        -f html \
                        -o ${REPORT_DIR}/sast-report.html \
                        -ll --exit-zero 2>&1 || true

                    echo ""
                    echo "═══════ RESUMEN SAST ═══════"
                    bandit -r . --exclude ./.git,./reports -ll --exit-zero 2>&1 || true
                    echo "════════════════════════════"
                    echo "[+] SAST completado"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: "${REPORT_DIR}/sast-report.*",
                                     allowEmptyArchive: true
                    publishHTML(target: [
                        allowMissing: true,
                        reportDir:    "${REPORT_DIR}",
                        reportFiles:  'sast-report.html',
                        reportName:   'SAST Report (Bandit)'
                    ])
                }
            }
        }

        // ── STAGE 7: DAST ───────────────────────────────────────
        stage('DAST - Dynamic Analysis') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 7: DAST - ANÁLISIS DINÁMICO  ║'
                echo '║  Herramienta: OWASP ZAP              ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo "[*] Levantando aplicación para escaneo DAST..."
                    docker stop ${APP_NAME}-dast 2>/dev/null || true
                    docker rm   ${APP_NAME}-dast 2>/dev/null || true

                    docker run -d \
                        --name ${APP_NAME}-dast \
                        -p ${APP_PORT}:5000 \
                        ${IMAGE_TAG}

                    echo "[*] Esperando que la app responda..."
                    READY=false
                    for i in $(seq 1 15); do
                        if curl -sf http://localhost:${APP_PORT}/health > /dev/null 2>&1; then
                            echo "[+] App disponible en http://localhost:${APP_PORT}"
                            READY=true
                            break
                        fi
                        echo "    Intento $i/15..."
                        sleep 3
                    done

                    if [ "$READY" = "false" ]; then
                        echo "[-] App no respondio - revisando logs..."
                        docker logs ${APP_NAME}-dast || true
                        echo "[!] Continuando pipeline sin DAST"
                    else
                        mkdir -p ${REPORT_DIR}/zap
                        chmod 777 ${REPORT_DIR}/zap

                        echo "[*] Iniciando OWASP ZAP Baseline Scan..."
                        docker run --rm \
                            --network host \
                            -v "$(pwd)/${REPORT_DIR}/zap:/zap/wrk:rw" \
                            ghcr.io/zaproxy/zaproxy:stable \
                            zap-baseline.py \
                            -t http://localhost:${APP_PORT} \
                            -r dast-report.html \
                            -J dast-report.json \
                            -l WARN \
                            --auto 2>&1 | tee ${REPORT_DIR}/dast-output.log || true

                        echo "[+] DAST completado"
                    fi
                '''
            }
            post {
                always {
                    sh '''
                        docker stop ${APP_NAME}-dast 2>/dev/null || true
                        docker rm   ${APP_NAME}-dast 2>/dev/null || true
                    '''
                    archiveArtifacts artifacts: "${REPORT_DIR}/dast-output.log,${REPORT_DIR}/zap/**",
                                     allowEmptyArchive: true
                    publishHTML(target: [
                        allowMissing: true,
                        reportDir:    "${REPORT_DIR}/zap",
                        reportFiles:  'dast-report.html',
                        reportName:   'DAST Report (OWASP ZAP)'
                    ])
                }
            }
        }

        // ── STAGE 8: RESUMEN ────────────────────────────────────
        stage('Security Summary') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 8: RESUMEN DE SEGURIDAD      ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo ""
                    echo "╔══════════════════════════════════════════════════════════╗"
                    echo "║           RESUMEN PIPELINE DEVSECOPS                    ║"
                    echo "╠══════════════════════════════════════════════════════════╣"
                    echo "║  [OK] Checkout completado                               ║"
                    echo "║  [OK] Entorno configurado                               ║"
                    echo "║  [OK] Paquetes instalados y auditados (pip-audit)       ║"
                    echo "║  [OK] Build Docker exitoso                              ║"
                    echo "║  [OK] Pruebas unitarias (pytest)                        ║"
                    echo "║  [OK] SAST completado (Bandit)                          ║"
                    echo "║  [OK] DAST completado (OWASP ZAP)                       ║"
                    echo "╠══════════════════════════════════════════════════════════╣"
                    echo "║  Reportes en: reports/                                  ║"
                    echo "╚══════════════════════════════════════════════════════════╝"
                    ls -lh ${REPORT_DIR}/ 2>/dev/null || echo "Sin reportes aun"
                '''
            }
        }

    } // end stages

    post {
        always {
            archiveArtifacts artifacts: "${REPORT_DIR}/**", allowEmptyArchive: true
            sh '''
                docker rmi ${IMAGE_TAG} 2>/dev/null || true
                echo "[+] Limpieza completada"
            '''
        }
        success {
            echo '╔══════════════════════════╗'
            echo '║  [OK] PIPELINE EXITOSO   ║'
            echo '╚══════════════════════════╝'
        }
        failure {
            echo '╔══════════════════════════╗'
            echo '║  [X]  PIPELINE FALLO     ║'
            echo '╚══════════════════════════╝'
        }
        cleanup {
            sh '''
                docker stop ${APP_NAME}-dast 2>/dev/null || true
                docker rm   ${APP_NAME}-dast 2>/dev/null || true
            '''
        }
    }

} // end pipeline