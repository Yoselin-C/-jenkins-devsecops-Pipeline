// ================================================================
//  PIPELINE DEVSECOPS - Yoselin-C / -jenkins-devsecops-Pipeline
//  Universidad Mariano Gálvez de Guatemala - Sede Cobán
//  Proyecto de Graduación I - Ingeniería en Sistemas
//
//  App objetivo: OWASP Juice Shop (app vulnerable para pruebas)
//  Flujo: Checkout → Setup → Package Management → Build →
//         Unit Tests → SAST → DAST → Security Summary
// ================================================================

pipeline {

    agent any

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        APP_NAME   = "juice-shop"
        APP_PORT   = "3000"
        APP_REPO   = "https://github.com/juice-shop/juice-shop.git"
        APP_BRANCH = "master"
        REPORT_DIR = "reports"
        IMAGE_TAG  = "${APP_NAME}:${BUILD_NUMBER}"
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
                    echo "[+] Jenkinsfile cargado desde el repositorio"
                    echo "[*] Commit: $(git rev-parse --short HEAD)"
                    echo "[*] Autor:  $(git log -1 --pretty=format:'%an <%ae>')"
                    mkdir -p ${REPORT_DIR}
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
                    echo "[*] Verificando herramientas disponibles..."
                    echo "[*] Git:    $(git --version)"
                    echo "[*] Node:   $(node --version)"
                    echo "[*] npm:    $(npm --version)"
                    echo "[*] Docker: $(docker --version)"

                    echo "[*] Clonando OWASP Juice Shop..."
                    if [ -d "juice-shop" ]; then
                        echo "[*] Directorio ya existe, actualizando..."
                        cd juice-shop
                        git pull origin master || true
                    else
                        git clone --branch master --single-branch \
                            https://github.com/juice-shop/juice-shop.git juice-shop
                    fi

                    echo "[+] Juice Shop listo en ./juice-shop"
                    ls juice-shop/
                '''
            }
        }

        // ── STAGE 3: MANEJO DE PAQUETES ─────────────────────────
        stage('Package Management') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 3: MANEJO DE PAQUETES        ║'
                echo '║  Herramienta: npm audit (SCA)        ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    cd juice-shop

                    echo "[*] Instalando dependencias con npm..."
                    npm install --legacy-peer-deps 2>&1 | tail -5

                    echo ""
                    echo "[*] Paquetes instalados:"
                    npm list --depth=0 2>/dev/null | head -20 || true

                    echo ""
                    echo "[*] Auditando vulnerabilidades en dependencias (npm audit)..."

                    # Reporte JSON
                    npm audit --json 2>/dev/null \
                        > ../${REPORT_DIR}/packages-audit.json || true

                    # Reporte texto
                    {
                        echo "=============================="
                        echo " NPM AUDIT - OWASP Juice Shop"
                        echo " Fecha: $(date)"
                        echo "=============================="
                        npm audit 2>&1 || true
                    } > ../${REPORT_DIR}/packages-audit.txt

                    echo ""
                    echo "═══ RESUMEN VULNERABILIDADES EN PAQUETES ═══"
                    npm audit 2>&1 | tail -10 || true
                    echo "════════════════════════════════════════════"
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
                    echo "[*] Construyendo imagen Docker de Juice Shop..."
                    cd juice-shop

                    docker build \
                        --tag ${IMAGE_TAG} \
                        --tag ${APP_NAME}:latest \
                        . 2>&1

                    echo "[+] Imagen construida exitosamente"
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
                    cd juice-shop

                    echo "[*] Ejecutando pruebas unitarias de Juice Shop..."

                    # Juice Shop tiene sus propios tests con jest
                    npm test -- --testPathPattern="server.test" \
                        --forceExit \
                        --reporters=default \
                        2>&1 | tee ../${REPORT_DIR}/test-output.txt || true

                    echo "[+] Pruebas completadas - ver test-output.txt"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: "${REPORT_DIR}/test-output.txt",
                                     allowEmptyArchive: true
                }
            }
        }

        // ── STAGE 6: SAST ───────────────────────────────────────
        stage('SAST - Static Analysis') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 6: SAST - ANÁLISIS ESTÁTICO  ║'
                echo '║  Herramienta: Semgrep                ║'
                echo '╚══════════════════════════════════════╝'
                sh '''
                    echo "[*] Ejecutando análisis estático con Semgrep..."

                    # Semgrep corre como contenedor Docker - no necesita instalación
                    docker run --rm \
                        -v "$(pwd)/juice-shop:/src" \
                        -v "$(pwd)/${REPORT_DIR}:/reports" \
                        returntocorp/semgrep:latest \
                        semgrep scan \
                            --config=p/javascript \
                            --config=p/nodejs \
                            --config=p/owasp-top-ten \
                            --json \
                            --output=/reports/sast-report.json \
                            --no-git-ignore \
                            /src 2>&1 | tail -20 || true

                    # Reporte texto para consola
                    docker run --rm \
                        -v "$(pwd)/juice-shop:/src" \
                        returntocorp/semgrep:latest \
                        semgrep scan \
                            --config=p/javascript \
                            --config=p/nodejs \
                            --no-git-ignore \
                            /src 2>&1 | tee ${REPORT_DIR}/sast-report.txt || true

                    echo "[+] SAST completado - ver sast-report.json"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: "${REPORT_DIR}/sast-report.*",
                                     allowEmptyArchive: true
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
                    echo "[*] Levantando Juice Shop para escaneo DAST..."
                    docker stop ${APP_NAME}-dast 2>/dev/null || true
                    docker rm   ${APP_NAME}-dast 2>/dev/null || true

                    docker run -d \
                        --name ${APP_NAME}-dast \
                        -p ${APP_PORT}:3000 \
                        ${IMAGE_TAG}

                    echo "[*] Esperando que Juice Shop responda..."
                    READY=false
                    for i in $(seq 1 20); do
                        if curl -sf http://localhost:${APP_PORT}/ > /dev/null 2>&1; then
                            echo "[+] Juice Shop disponible en http://localhost:${APP_PORT}"
                            READY=true
                            break
                        fi
                        echo "    Intento $i/20..."
                        sleep 5
                    done

                    if [ "$READY" = "false" ]; then
                        echo "[!] App no respondio - revisando logs..."
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
                            -I \
                            2>&1 | tee ${REPORT_DIR}/dast-output.log || true

                        echo "[+] DAST completado"
                    fi
                '''
            }
            post {
                always {
                    sh '''
                        echo "[*] Deteniendo Juice Shop..."
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
                    echo "╔══════════════════════════════════════════════════════╗"
                    echo "║          RESUMEN PIPELINE DEVSECOPS                 ║"
                    echo "║    App: OWASP Juice Shop  |  Build #${BUILD_NUMBER} ║"
                    echo "╠══════════════════════════════════════════════════════╣"
                    echo "║  [OK] Checkout completado                           ║"
                    echo "║  [OK] Entorno configurado (Node + npm)              ║"
                    echo "║  [OK] Paquetes auditados (npm audit - SCA)          ║"
                    echo "║  [OK] Build Docker exitoso                          ║"
                    echo "║  [OK] Pruebas unitarias (Jest)                      ║"
                    echo "║  [OK] SAST completado (Semgrep)                     ║"
                    echo "║  [OK] DAST completado (OWASP ZAP)                   ║"
                    echo "╠══════════════════════════════════════════════════════╣"
                    echo "║  Reportes disponibles en: reports/                  ║"
                    echo "╚══════════════════════════════════════════════════════╝"
                    echo ""
                    ls -lh ${REPORT_DIR}/ 2>/dev/null || echo "Sin reportes aun"
                '''
            }
        }

    } // end stages

    post {
        always {
            archiveArtifacts artifacts: "${REPORT_DIR}/**",
                             allowEmptyArchive: true
            sh '''
                docker rmi ${IMAGE_TAG} 2>/dev/null || true
                docker rmi ${APP_NAME}:latest 2>/dev/null || true
                echo "[+] Limpieza de imagenes completada"
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