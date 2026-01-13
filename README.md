# customer-revenue-cohort-analysis
Proyecto de análisis de ventas de extremo a extremo utilizando SQLite y SQL, que incluye comprobaciones de calidad de datos, métricas de ingresos y análisis de cohortes en datos transaccionales sintéticos.

Customer Revenue & Cohort Analysis (SQLite + SQL)

Descripción general
Proyecto de análisis de ventas de extremo a extremo utilizando SQLite y SQL, enfocado en:
validación de calidad de datos, deduplicación, métricas de ingresos, y análisis de cohortes de clientes.

El proyecto trabaja con datos transaccionales sintéticos, permitiendo reproducibilidad completa sin datos sensibles.

Objetivos del proyecto:

Construir un pipeline analítico reproducible usando SQL.

Detectar problemas comunes de calidad de datos (duplicados, inconsistencias, retornos inválidos).

Generar métricas de ingresos por cliente y por mes.

Analizar el comportamiento de clientes mediante cohortes basadas en su primer mes de compra.

Exportar resultados finales en archivos CSV listos para análisis o visualización.


Estructura del repositorio
Customer-Revenue-Cohort-Analysis/
├── data_raw/              # Datos de entrada (CSV sintéticos)
│   ├── customers.csv
│   ├── orders.csv
│   ├── order_items.csv
│   └── returns.csv
├── sql/                   # Scripts SQL
│   ├── 01_create_tables.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_revenue_metrics.sql
│   └── 04_cohort_analysis.sql
├── outputs/               # Resultados finales en CSV
│   ├── data_quality_issues.csv
│   ├── revenue_by_customer.csv
│   ├── revenue_monthly_by_customer.csv
│   ├── cohort_monthly_revenue.csv
│   └── cohort_retention_proxy.csv
├── database/              # Base SQLite (no versionada)
├── README.md
└── .gitignore

Flujo del pipeline
CSV (data_raw)
   ↓
SQLite (tablas base)
   ↓
SQL (CTEs + vistas analíticas)
   ↓
CSV finales (outputs)

Nota: no se generan archivos intermedios data_clean. La limpieza y validación se realizan directamente en SQL mediante CTEs y vistas.


Descripción de los scripts SQL

01_create_tables.sql
Crea las tablas base en SQLite:
customers
orders
order_items
returns

02_data_quality_checks.sql
Detecta y registra problemas de calidad de datos, incluyendo:
Duplicados exactos en order_items.
Claves duplicadas (order_id, product_id).
Inconsistencias en unit_price.
Retornos mayores a la cantidad vendida.
Output:
outputs/data_quality_issues.csv

03_revenue_metrics.sql
Genera métricas de ingresos:
Ingresos brutos, retornados y netos por cliente.
Tasa de devoluciones.
Ingresos mensuales por cliente.
Outputs:
outputs/revenue_by_customer.csv
outputs/revenue_monthly_by_customer.csv

04_cohort_analysis.sql
Realiza análisis de cohortes:
Cohorte definida como el primer mes de compra (paid).
Ingresos netos por cohorte y mes.
Ingresos acumulados por cohorte.
Proxy de retención mensual de clientes.
Outputs:
outputs/cohort_monthly_revenue.csv
outputs/cohort_retention_proxy.csv

Cómo ejecutar el proyecto
- Crear la base de datos y tablas
sqlite3 database/analytics < sql/01_create_tables.sql
- Importar los CSV
sqlite3 database/analytics
.mode csv
.separator ","
.import --skip 1 data_raw/customers.csv customers
.import --skip 1 data_raw/orders.csv orders
.import --skip 1 data_raw/order_items.csv order_items
.import --skip 1 data_raw/returns.csv returns
- Ejecutar análisis
sqlite3 database/analytics < sql/02_data_quality_checks.sql
sqlite3 database/analytics < sql/03_revenue_metrics.sql
sqlite3 database/analytics < sql/04_cohort_analysis.sql
- Exportar resultados
sqlite3 database/analytics << 'SQL'
.headers on
.mode csv

.output outputs/data_quality_issues.csv
SELECT * FROM dq_issues;

.output outputs/revenue_by_customer.csv
SELECT * FROM revenue_by_customer;

.output outputs/revenue_monthly_by_customer.csv
SELECT * FROM revenue_monthly_by_customer;

.output outputs/cohort_monthly_revenue.csv
SELECT * FROM cohort_monthly_revenue;

.output outputs/cohort_retention_proxy.csv
SELECT * FROM cohort_retention_proxy;

.output stdout
SQL


Decisiones técnicas
Se utilizó SQLite por simplicidad y portabilidad.
Se priorizó SQL puro con CTEs y funciones ventana.
La deduplicación se maneja de forma explícita para no ocultar problemas de datos.
Los datos son sintéticos para garantizar reproducibilidad.

Autor
Guillermo
Proyecto desarrollado como parte de un plan estructurado de formación en Data Analytics / Data Engineering Junior.
