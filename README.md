# 🔐 jenkins-devsecops-pipeline

Pipeline DevSecOps completo para demostración académica.  
**Universidad Mariano Gálvez de Guatemala – Sede Cobán**  
Proyecto de Graduación I · Ingeniería en Sistemas

---

## 📋 Estructura del proyecto

```
jenkins-devsecops-pipeline/
├── Jenkinsfile                  ← Pipeline principal (8 stages)
├── Dockerfile                   ← Imagen de la app para DAST
├── requirements.txt             ← Dependencias Python
├── app/
│   └── app.py                   ← Aplicación Flask (target de pruebas)
├── tests/
│   └── test_app.py              ← Pruebas unitarias (pytest)
└── scripts/
    ├── run_sast.sh              ← Script SAST con Bandit
    ├── run_dast.sh              ← Script DAST con OWASP ZAP
    └── run_package_audit.sh     ← Auditoría de dependencias
```

---

## 🔄 Stages del Pipeline

| # | Stage | Herramienta | Puntos |
|---|-------|-------------|--------|
| 1 | Checkout | Git/SCM | Steps |
| 2 | Setup | Python venv | Steps |
| 3 | **Package Management** | pip-audit | 2 pts |
| 4 | Build | Docker | Steps |
| 5 | Unit Tests | pytest + coverage | Steps |
| 6 | **SAST** | Bandit | 3 pts |
| 7 | **DAST** | OWASP ZAP | 2 pts |
| 8 | Security Summary | — | Steps |

---

## ⚙️ Requisitos del servidor Jenkins

- Jenkins 2.x con los plugins:
  - Pipeline
  - Git
  - HTML Publisher
  - JUnit
- Docker instalado en el agente
- Python 3.8+ instalado

### Plugins recomendados
```
Pipeline: Declarative
HTML Publisher Plugin
JUnit Plugin
Docker Pipeline
```

---

## 🚀 Configuración en Jenkins

### 1. Crear nuevo item
- **Tipo:** Pipeline
- **Nombre:** `jenkins-devsecops-pipeline`

### 2. Pipeline desde SCM
```
Definition:  Pipeline script from SCM
SCM:         Git
Repository:  https://github.com/Yoselin-C/jenkins-devsecops-pipeline.git
Branch:      */main
Script Path: Jenkinsfile
```

### 3. Ejecutar
Hacer clic en **Build Now** y observar los 8 stages en la vista Stage View.

---

## 📊 Reportes generados

Todos los reportes se guardan en `reports/` y se publican en Jenkins:

| Reporte | Descripción |
|---------|-------------|
| `sast-report.html` | Vulnerabilidades encontradas por Bandit en el código |
| `sast-report.json` | Mismo reporte en formato JSON |
| `zap/dast-report.html` | Vulnerabilidades dinámicas detectadas por OWASP ZAP |
| `packages-audit.txt` | CVEs encontrados en dependencias (pip-audit) |
| `coverage-html/` | Cobertura de pruebas unitarias |
| `test-results.xml` | Resultados JUnit de los tests |

---

## 🛡️ Componentes de seguridad

### SAST – Bandit
Analiza el **código fuente** sin ejecutarlo en busca de:
- Uso de funciones peligrosas (`eval`, `exec`, `subprocess`)
- Configuraciones inseguras (debug=True, bind a 0.0.0.0)
- Inyecciones y manejo inseguro de datos

### DAST – OWASP ZAP
Analiza la app **en ejecución** escaneando:
- Cabeceras HTTP inseguras
- Endpoints vulnerables a XSS, SQLi
- Configuraciones de seguridad faltantes

### Package Management – pip-audit
Compara las dependencias instaladas contra la base de datos de CVEs:
- Detecta paquetes con vulnerabilidades conocidas
- Sugiere versiones seguras

---

## 👩‍💻 Autor
**Yoselin-C** · GitHub: [@Yoselin-C](https://github.com/Yoselin-C)
