# Supported Databases

SqlToy ships with **25 built-in database dialects** (SAP HANA added in 6.0; HighGo added in 6.0.5) and auto-detects the database type via `DialectFactory`, adapting pagination and functions automatically. Any database providing a JDBC driver can be queried by SqlToy.

## Mainstream Relational Databases

MySQL, Oracle, PostgreSQL, SQL Server, DB2, SAP HANA, H2, SQLite, TiDB, OceanBase, PolarDB

## Chinese / Domestic Databases

DM (Dameng), Kingbase, Oscar, HighGo, MogDB, Vastbase, StarDB, GaussDB, OpenGauss

## Distributed OLAP Databases

ClickHouse, Doris, StarRocks, Greenplum, Impala (Kudu)

## Time-Series Databases

TDengine (IoT time-series; supports **query + object insert** — see [TDengine Support](en/dialect/sqltoy_tdengine.md))

## NoSQL

Elasticsearch, MongoDB

## Others

Any SQL/JDBC-capable database can be queried. For databases without a dedicated dialect (especially PostgreSQL derivatives), configure `dialect` / `dialectMap` to map them onto an existing dialect — see [SQL Showcase](en/query/sql_showcase.md) (Chinese).

> For cross-database adaptation (function replacement, dialect-specific sqlId, multi-DB verification), see the [Cross-DB & Dialect](en/dialect/sqltoy_function.md) chapter (Chinese).
