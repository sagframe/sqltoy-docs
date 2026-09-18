# Supported Databases

SqlToy ships with **24 built-in database dialects** and auto-detects the database type via `DialectFactory`, adapting pagination and functions automatically. Any database providing a JDBC driver can be queried by SqlToy.

## Mainstream Relational Databases

MySQL, Oracle, PostgreSQL, SQL Server, DB2, SAP HANA, H2, SQLite, TiDB, OceanBase, PolarDB

## Chinese / Domestic Databases

DM (Dameng), Kingbase, Oscar, HighGo, MogDB, Vastbase, StarDB, GaussDB, OpenGauss

## Distributed OLAP Databases

ClickHouse, Doris, StarRocks, Greenplum, Impala (Kudu), TDengine

## NoSQL

Elasticsearch, MongoDB

## Others

Any SQL/JDBC-capable database can be queried. For databases without a dedicated dialect (especially PostgreSQL derivatives), configure `dialect` / `dialectMap` to map them onto an existing dialect — see [SQL Showcase](../query/sql_showcase.md) (Chinese).

> For cross-database adaptation (function replacement, dialect-specific sqlId, multi-DB verification), see the [Cross-DB & Dialect](../dialect/sqltoy_function.md) chapter (Chinese).
