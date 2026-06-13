pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    environment {
        APP_NAME     = 'jenkins-todo-app'
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
                    echo "── Node:   $(node --version)"
                    echo "── npm:    $(npm --version)"
                    echo "── Docker: $(docker --version)"
                    echo "── Python: $(python3 --version)"
                '''
            }
        }

        stage('Checkout') {
            steps {
                echo '📥 Descargando código desde GitHub...'
                checkout scm
                sh "mkdir -p ${REPORT_DIR}"
            }
        }

        stage('Build') {
            steps {
                echo '🔧 Instalando dependencias...'
                sh 'npm install'
            }
        }

        stage('SCA - Dependencias') {
            steps {
                echo '📦 Analizando vulnerabilidades en dependencias...'
                sh """
                    npm audit --json 2>/dev/null > ${REPORT_DIR}/sca-report.json || true
                """
                script {
                    def auditJson = readFile("${REPORT_DIR}/sca-report.json")
                    def audit    = new groovy.json.JsonSlurper().parseText(auditJson)
                    def vulns    = audit.metadata?.vulnerabilities ?: [:]
                    def critical = vulns.critical ?: 0
                    def high     = vulns.high ?: 0
                    def moderate = vulns.moderate ?: 0
                    def low      = vulns.low ?: 0
                    def total    = vulns.total ?: 0

                    echo """
┌─────────────────────────────────┐
│   SCA — VULNERABILIDADES        │
├─────────────────────────────────┤
│  CRITICAL:  ${critical.toString().padLeft(4)}               │
│  HIGH:      ${high.toString().padLeft(4)}               │
│  MODERATE:  ${moderate.toString().padLeft(4)}               │
│  LOW:       ${low.toString().padLeft(4)}               │
│  TOTAL:     ${total.toString().padLeft(4)}               │
└─────────────────────────────────┘
                    """.stripIndent()

                    currentBuild.description = "SCA: ${critical} critical, ${high} high"
                }
            }
        }

        stage('Test') {
            steps {
                echo '🧪 Ejecutando pruebas automatizadas...'
                sh 'npm test'
            }
        }

        stage('SAST - Semgrep') {
            steps {
                echo '🔒 Analizando vulnerabilidades en el código fuente...'
                sh """
                    pip install semgrep --quiet --break-system-packages || true
                    export PATH=\$HOME/.local/bin:\$PATH
                    \$HOME/.local/bin/semgrep --config=p/nodejs-security \\
                            --json \\
                            --output=${REPORT_DIR}/semgrep-report.json \\
                            src/ || true
                    cat ${REPORT_DIR}/semgrep-report.json || echo "Sin reporte generado"
                """
                script {
                    def semgrepFile = "${REPORT_DIR}/semgrep-report.json"
                    if (fileExists(semgrepFile)) {
                        def semgrepJson = readFile(semgrepFile)
                        def semgrep  = new groovy.json.JsonSlurper().parseText(semgrepJson)
                        def findings = semgrep.results?.size() ?: 0

                        echo """
┌─────────────────────────────────┐
│   SAST — SEMGREP                │
├─────────────────────────────────┤
│  Hallazgos: ${findings.toString().padLeft(4)}               │
└─────────────────────────────────┘
                        """.stripIndent()

                        def prevDesc = currentBuild.description ?: ''
                        currentBuild.description = "${prevDesc} | SAST: ${findings} findings"
                    }
                }
            }
        }

        stage('Docker Build & Deploy') {
            steps {
                echo '🐳 Construyendo imagen Docker...'
                sh "docker build -t ${APP_NAME}:latest ."
                echo '🚀 Desplegando contenedor...'
                sh "docker stop ${APP_NAME} || true"
                sh "docker rm ${APP_NAME} || true"
                sh "docker run -d --name ${APP_NAME} -p ${APP_PORT}:3000 ${APP_NAME}:latest"
                echo "✅ App corriendo en http://localhost:${APP_PORT}/todos"
            }
        }

        stage('Trivy - Imagen Docker') {
            steps {
                echo '🔍 Escaneando imagen Docker con Trivy...'
                sh """
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        -v \$(pwd)/${REPORT_DIR}:/output \\
                        aquasec/trivy:latest image \\
                        --format json \\
                        --output /output/trivy-report.json \\
                        --severity LOW,MEDIUM,HIGH,CRITICAL \\
                        --no-progress \\
                        ${APP_NAME}:latest || true
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
│   TRIVY — IMAGEN DOCKER          │
├──────────────────────────────────┤
│  CRITICAL: ${critical.toString().padLeft(4)}                │
│  HIGH:     ${high.toString().padLeft(4)}                │
│  MEDIUM:   ${medium.toString().padLeft(4)}                │
│  LOW:      ${low.toString().padLeft(4)}                │
└──────────────────────────────────┘
                        """.stripIndent()

                        def prevDesc = currentBuild.description ?: ''
                        currentBuild.description = "${prevDesc} | Trivy: ${critical} crit, ${high} high"
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
║  ✅ PIPELINE COMPLETADO                  ║
║  App desplegada y seguridad verificada.  ║
╚══════════════════════════════════════════╝
            '''
        }
        failure {
            echo '''
╔══════════════════════════════════════════╗
║  ❌ PIPELINE FALLÓ                       ║
║  Revisar el stage en rojo.               ║
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