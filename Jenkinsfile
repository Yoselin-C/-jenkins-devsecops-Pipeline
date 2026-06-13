// ================================================================
//  PIPELINE DEVSECOPS - Yoselin-C / jenkins-devsecops-pipeline
//  Universidad Mariano Gálvez de Guatemala - Sede Cobán
//  Proyecto de Graduación I - Ingeniería en Sistemas
// ================================================================

pipeline {

    agent any

    // ── Variables globales ──────────────────────────────────────
    environment {
        APP_NAME    = "devsecops-demo-app"
        APP_PORT    = "5000"
        REPORT_DIR  = "reports"
        IMAGE_TAG   = "${APP_NAME}:${BUILD_NUMBER}"
        VENV_DIR    = ".venv"
    }

    // ── Opciones del pipeline ───────────────────────────────────
    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    // ── Disparadores ────────────────────────────────────────────
    triggers {
        pollSCM('H/5 * * * *')   // revisar cambios cada 5 minutos
    }

    // ================================================================
    //  STAGES
    // ================================================================
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
                    echo "[*] Branch: $(git rev-parse --abbrev-ref HEAD)"
                    echo "[*] Commit: $(git rev-parse --short HEAD)"
                    echo "[*] Autor:  $(git log -1 --pretty=format:'%an <%ae>')"
                    ls -la
                '''
            }
        }

        // ── STAGE 2: PREPARACIÓN DEL ENTORNO ───────────────────
        stage('Setup') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 2: CONFIGURACIÓN DEL ENTORNO ║'
                echo '╚══════════════════════════════════════╝'

                sh '''
                    echo "[*] Python version: $(python3 --version)"
                    echo "[*] pip version:    $(pip3 --version)"

                    # Crear entorno virtual limpio
                    python3 -m venv ${VENV_DIR}
                    . ${VENV_DIR}/bin/activate

                    pip install --upgrade pip --quiet

                    echo "[+] Entorno virtual listo"
                    mkdir -p ${REPORT_DIR}
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
                    . ${VENV_DIR}/bin/activate

                    echo "[*] Instalando dependencias del proyecto..."
                    pip install -r requirements.txt

                    echo ""
                    echo "[*] Paquetes instalados:"
                    pip list --format=columns

                    echo ""
                    echo "[*] Auditando vulnerabilidades en dependencias (pip-audit)..."
                    pip install pip-audit --quiet

                    pip-audit -r requirements.txt \
                        --progress-spinner off \
                        -f json \
                        -o ${REPORT_DIR}/packages-audit.json || true

                    pip-audit -r requirements.txt \
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
                    . ${VENV_DIR}/bin/activate

                    # Verificar sintaxis Python
                    echo "[*] Verificando sintaxis de la aplicación..."
                    python3 -m py_compile app/app.py
                    echo "[+] Sintaxis OK"

                    # Build imagen Docker
                    echo "[*] Construyendo imagen Docker: ${IMAGE_TAG}..."
                    docker build -t ${IMAGE_TAG} .
                    echo "[+] Imagen construida: ${IMAGE_TAG}"
                    docker images | grep ${APP_NAME}
                '''
            }
        }

        // ── STAGE 5: TESTS UNITARIOS ────────────────────────────
        stage('Unit Tests') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 5: PRUEBAS UNITARIAS         ║'
                echo '╚══════════════════════════════════════╝'

                sh '''
                    . ${VENV_DIR}/bin/activate

                    pytest tests/ \
                        -v \
                        --tb=short \
                        --cov=app \
                        --cov-report=html:${REPORT_DIR}/coverage-html \
                        --cov-report=xml:${REPORT_DIR}/coverage.xml \
                        --junitxml=${REPORT_DIR}/test-results.xml

                    echo "[+] Pruebas completadas"
                '''
            }
            post {
                always {
                    junit "${REPORT_DIR}/test-results.xml"
                    publishHTML(target: [
                        allowMissing: true,
                        reportDir:    "${REPORT_DIR}/coverage-html",
                        reportFiles:  'index.html',
                        reportName:   'Coverage Report'
                    ])
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
                    . ${VENV_DIR}/bin/activate

                    echo "[*] Ejecutando Bandit sobre el código fuente..."

                    # Reporte JSON (para parsear)
                    bandit -r app/ \
                        -f json \
                        -o ${REPORT_DIR}/sast-report.json \
                        -ll \
                        --exit-zero

                    # Reporte HTML (para visualizar)
                    bandit -r app/ \
                        -f html \
                        -o ${REPORT_DIR}/sast-report.html \
                        -ll \
                        --exit-zero

                    # Resumen en consola
                    echo ""
                    echo "═══════ RESUMEN SAST ═══════"
                    bandit -r app/ -ll --exit-zero
                    echo "════════════════════════════"

                    echo "[+] Análisis SAST completado - ver sast-report.html"
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
                    # Levantar la app en Docker para el escaneo
                    echo "[*] Levantando aplicación para escaneo DAST..."

                    # Detener contenedor previo si existe
                    docker stop ${APP_NAME}-dast 2>/dev/null || true
                    docker rm   ${APP_NAME}-dast 2>/dev/null || true

                    # Correr la app
                    docker run -d \
                        --name ${APP_NAME}-dast \
                        -p ${APP_PORT}:5000 \
                        ${IMAGE_TAG}

                    # Esperar que la app esté lista
                    echo "[*] Esperando que la app responda..."
                    READY=false
                    for i in $(seq 1 15); do
                        if curl -sf http://localhost:${APP_PORT}/health > /dev/null 2>&1; then
                            echo "[+] App disponible en http://localhost:${APP_PORT}"
                            READY=true
                            break
                        fi
                        echo "    Intento $i/15..."
                        sleep 2
                    done

                    if [ "$READY" = "false" ]; then
                        echo "[-] La app no respondió - abortando DAST"
                        docker logs ${APP_NAME}-dast
                        exit 1
                    fi

                    # Crear directorio de reportes con permisos para ZAP
                    mkdir -p ${REPORT_DIR}/zap
                    chmod 777 ${REPORT_DIR}/zap

                    # Ejecutar ZAP Baseline Scan
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

                    echo "[+] Escaneo DAST completado"
                '''
            }
            post {
                always {
                    sh '''
                        echo "[*] Deteniendo contenedor de la app..."
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

        // ── STAGE 8: REPORTE FINAL ──────────────────────────────
        stage('Security Summary') {
            steps {
                echo '╔══════════════════════════════════════╗'
                echo '║  STAGE 8: RESUMEN DE SEGURIDAD      ║'
                echo '╚══════════════════════════════════════╝'

                sh '''
                    echo ""
                    echo "╔══════════════════════════════════════════════════════════╗"
                    echo "║           RESUMEN PIPELINE DEVSECOPS                    ║"
                    echo "║      jenkins-devsecops-pipeline - Build #${BUILD_NUMBER} ║"
                    echo "╠══════════════════════════════════════════════════════════╣"
                    echo "║  ✔  Checkout completado                                 ║"
                    echo "║  ✔  Entorno configurado                                 ║"
                    echo "║  ✔  Paquetes instalados y auditados (pip-audit)         ║"
                    echo "║  ✔  Build exitoso (Docker image: ${IMAGE_TAG})          ║"
                    echo "║  ✔  Pruebas unitarias ejecutadas (pytest)               ║"
                    echo "║  ✔  SAST completado (Bandit)                            ║"
                    echo "║  ✔  DAST completado (OWASP ZAP)                         ║"
                    echo "╠══════════════════════════════════════════════════════════╣"
                    echo "║  Reportes disponibles en: ${REPORT_DIR}/                ║"
                    echo "╚══════════════════════════════════════════════════════════╝"
                    echo ""

                    ls -lh ${REPORT_DIR}/ 2>/dev/null || echo "Sin reportes generados"
                '''
            }
        }

    } // end stages

    // ================================================================
    //  POST - Acciones finales
    // ================================================================
    post {

        always {
            echo '[ ] Archivando todos los reportes...'
            archiveArtifacts artifacts: "${REPORT_DIR}/**",
                             allowEmptyArchive: true

            // Limpieza de imagen Docker para no acumular espacio
            sh '''
                docker rmi ${IMAGE_TAG} 2>/dev/null || true
                echo "[+] Limpieza de imagen Docker completada"
            '''
        }

        success {
            echo '╔══════════════════════════╗'
            echo '║  ✔  PIPELINE EXITOSO     ║'
            echo '╚══════════════════════════╝'
        }

        failure {
            echo '╔══════════════════════════╗'
            echo '║  ✘  PIPELINE FALLÓ       ║'
            echo '║  Revisar logs de stages  ║'
            echo '╚══════════════════════════╝'
        }

        unstable {
            echo '[ ] Pipeline inestable - revisar pruebas fallidas'
        }

        cleanup {
            sh '''
                docker stop ${APP_NAME}-dast 2>/dev/null || true
                docker rm   ${APP_NAME}-dast 2>/dev/null || true
            '''
        }
    }

} // end pipeline
