pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    environment {
        APP_NAME     = 'juice-shop'
        IMAGE_TAG    = 'bkimminich/juice-shop:latest' // Imagen oficial de Juice Shop
        APP_PORT     = '3001'
        MAX_CRITICAL = '0'
        MAX_HIGH     = '3'
        REPORT_DIR   = 'security-reports'
    }

    stages {

        stage('Prerequisites') {
            steps {
                echo '🔍 Verificando entorno...'
                sh '''
                    echo "── Docker: $(docker --version)"
                '''
            }
        }

        stage('Checkout & Setup') {
            steps {
                echo '📥 Inicializando espacio de trabajo...'
                checkout scm
                sh "mkdir -p ${REPORT_DIR}"
            }
        }

        stage('Docker Pull & Deploy') {
            steps {
                echo "🐳 Descargando imagen oficial: ${IMAGE_TAG}..."
                sh "docker pull ${IMAGE_TAG}"
                
                echo '🚀 Desplegando contenedor...'
                sh "docker stop ${APP_NAME} || true"
                sh "docker rm ${APP_NAME} || true"
                // Juice Shop expone internamente el puerto 3000
                sh "docker run -d --name ${APP_NAME} -p ${APP_PORT}:3000 ${IMAGE_TAG}"
                
                echo "✅ OWASP Juice Shop corriendo en http://localhost:${APP_PORT}"
            }
        }

        stage('Trivy - SCA & Container Scan') {
            steps {
                echo '🔍 Escaneando imagen Docker y dependencias con Trivy...'
                sh """
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v \$(pwd)/${REPORT_DIR}:/output \\
                        aquasec/trivy:latest image \\
                        --format json \\
                        --output /output/trivy-report.json \\
                        --severity LOW,MEDIUM,HIGH,CRITICAL \\
                        --no-progress \\
                        ${IMAGE_TAG} || true
                """
                script {
                    def trivyFile = "${REPORT_DIR}/trivy-report.json"
                    if (fileExists(trivyFile)) {
                        def trivyJson = readFile(trivyFile)
                        def trivy = new groovy.json.JsonSlurper().parseText(trivyJson)
                        int critical = 0, high = 0, medium = 0, low = 0

                        trivy.Results?.each { result ->
                            result.Vulnerabilities?.each { vuln ->
                                switch(vuln.Severity) {
                                    case 'CRITICAL': critical++; break
                                    case 'HIGH':     high++;     break
                                    case 'MEDIUM':   medium++;   break
                                    case 'LOW':      low++;      break
                                }
                            }
                        }

                        echo """
┌──────────────────────────────────┐
│   TRIVY — VULNERABILIDADES       │
├──────────────────────────────────┤
│  CRITICAL: ${critical.toString().padLeft(4)}                │
│  HIGH:     ${high.toString().padLeft(4)}                │
│  MEDIUM:   ${medium.toString().padLeft(4)}                │
│  LOW:      ${low.toString().padLeft(4)}                │
└──────────────────────────────────┘
                        """.stripIndent()

                        currentBuild.description = "Trivy: ${critical} crit, ${high} high"
                    }
                }
            }
        }

        stage('Security Gate') {
            steps {
                echo '🚦 Evaluando Security Gate...'
                script {
                    def trivyFile = "${REPORT_DIR}/trivy-report.json"
                    int critical = 0, high = 0

                    if (fileExists(trivyFile)) {
                        def trivyJson = readFile(trivyFile)
                        def trivy = new groovy.json.JsonSlurper().parseText(trivyJson)
                        trivy.Results?.each { result ->
                            result.Vulnerabilities?.each { vuln ->
                                if (vuln.Severity == 'CRITICAL') critical++
                                if (vuln.Severity == 'HIGH')     high++
                            }
                        }
                    }

                    echo """
┌──────────────────────────────────────────┐
│   SECURITY GATE                          │
├──────────────────────────────────────────┤
│  CRITICAL encontradas: ${critical.toString().padLeft(4)} (máx: ${MAX_CRITICAL})    │
│  HIGH encontradas:     ${high.toString().padLeft(4)} (máx: ${MAX_HIGH})    │
└──────────────────────────────────────────┘
                    """.stripIndent()

                    if (critical > MAX_CRITICAL.toInteger()) {
                        error("❌ SECURITY GATE FALLÓ: ${critical} CRITICAL (máximo: ${MAX_CRITICAL})")
                    }
                    if (high > MAX_HIGH.toInteger()) {
                        error("❌ SECURITY GATE FALLÓ: ${high} HIGH (máximo: ${MAX_HIGH})")
                    }

                    echo "✅ SECURITY GATE APROBADO"
                }
            }
        }

        stage('DAST - OWASP ZAP') {
            steps {
                echo '🕷️ Ejecutando análisis dinámico con OWASP ZAP...'
                sh """
                    docker run --rm \\
                        --network host \\
                        -v \$(pwd)/${REPORT_DIR}:/zap/wrk \\
                        ghcr.io/zaproxy/zaproxy:stable \\
                        zap-baseline.py \\
                        -t http://localhost:${APP_PORT} \\
                        -r zap-report.html \\
                        -J zap-report.json \\
                        -I || true
                    echo "=== REPORTE ZAP GENERADO ==="
                """
                script {
                    def zapFile = "${REPORT_DIR}/zap-report.json"
                    if (fileExists(zapFile)) {
                        def zapJson = readFile(zapFile)
                        def zap = new groovy.json.JsonSlurper().parseText(zapJson)
                        int high = 0, medium = 0, low = 0

                        zap.site?.each { site ->
                            site.alerts?.each { alert ->
                                switch(alert.riskcode?.toString()) {
                                    case '3': high++;   break
                                    case '2': medium++; break
                                    case '1': low++;    break
                                }
                            }
                        }

                        echo """
┌──────────────────────────────────┐
│   DAST — OWASP ZAP               │
├──────────────────────────────────┤
│  HIGH:   ${high.toString().padLeft(4)}                    │
│  MEDIUM: ${medium.toString().padLeft(4)}                    │
│  LOW:    ${low.toString().padLeft(4)}                    │
└──────────────────────────────────┘
                        """.stripIndent()

                        def prevDesc = currentBuild.description ?: ''
                        currentBuild.description = "${prevDesc} | ZAP: ${high} high"
                    }
                }
            }
        }

    }

    post {
        success {
            echo '''
╔══════════════════════════════════════════╗
║   ✅ PIPELINE COMPLETADO                  ║
║   Juice Shop desplegado y verificado.    ║
╚══════════════════════════════════════════╝
            '''
        }
        failure {
            echo '''
╔══════════════════════════════════════════╗
║   ❌ PIPELINE FALLÓ                      ║
║   Revisar el stage en rojo o las vulns.  ║
╚══════════════════════════════════════════╝
            '''
        }
        always {
            echo '📋 Archivando reportes de seguridad...'
            archiveArtifacts artifacts: "${REPORT_DIR}/**/*",
                             allowEmptyArchive: true
        }
    }
}