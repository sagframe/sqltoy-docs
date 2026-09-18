# 支持的数据库

sqltoy 内置 24 种数据库方言（`dialect`，6.0 新增 SAP HANA），并通过 `DialectFactory` 自动识别数据库类型、适配分页与函数。只要数据库提供 JDBC 驱动，sqltoy 即可对其进行查询。

## 主流关系型数据库

MySQL、Oracle、PostgreSQL、SQL Server、DB2、SAP HANA、H2、SQLite、TiDB、OceanBase、PolarDB

## 国产 / 信创数据库

达梦（DM）、人大金仓（Kingbase）、神通（Oscar）、瀚高（HighGo）、MogDB、Vastbase、StarDB、GaussDB、OpenGauss

## 分布式 OLAP 数据库

ClickHouse、Doris、StarRocks、Greenplum、Impala（Kudu）、TDengine

## NoSQL

Elasticsearch、MongoDB

## 其他

所有基于 SQL 和 JDBC 的各类数据库均可进行查询。对于未单独列出方言的数据库（尤其 PostgreSQL 系的衍生库），可通过配置 `dialect` / `dialectMap` 指定按某种方言处理，详见[常见 SQL 案例](../query/sql_showcase.md)。

> 跨数据库适配（函数自动替换、方言 sqlId、多库适配验证）见[跨库与方言](../dialect/sqltoy_function.md)章节。
