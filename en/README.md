## Introduction

#### SqlToy — a Java ORM combining JPA-style object CRUD with SQL-first querying

SqlToy starts from an intuitive dynamic-SQL authoring model and provides **Cache Translate**, **Pagination Optimize**, **Fast Pagination** and automatic **cross-database function adaptation**, and compiles to a **GraalVM Native Image** for cloud-native and XinChuang (domestic-stack) deployments with instant startup and minimal memory footprint — with systematic solutions for the complex scenarios found in real-world projects.

> Through open-source sharing we have gathered scenarios and wisdom from a broad community — join us in building a China-born intelligent ORM framework!

<p align="center">
    <a target="_blank" href="../LICENSE"><img src="https://img.shields.io/:license-Apache%202.0-blue.svg"></a>
    <a target="_blank" href="https://github.com/sagframe/sagacity-sqltoy"><img src="https://img.shields.io/github/stars/sagframe/sagacity-sqltoy.svg?style=social"/></a>
    <a target="_blank" href="https://gitee.com/sagacity/sagacity-sqltoy"><img src="https://gitee.com/sagacity/sagacity-sqltoy/badge/star.svg?theme=white" /></a>
    <a target="_blank" href="https://github.com/sagframe/sagacity-sqltoy/releases"><img src="https://img.shields.io/github/v/release/sagframe/sagacity-sqltoy?logo=github"></a>
    <a href="https://mvnrepository.com/artifact/com.sagframe/sagacity-sqltoy">
        <img alt="maven" src="https://img.shields.io/maven-central/v/com.sagframe/sagacity-sqltoy?style=flat-square">
    </a>
</p>

## How SqlToy Differs from Other ORMs

SqlToy aims to **fill JPA's query gaps while solving MyBatis's daily pain points**: it is neither a mapping framework where "every SQL must live in XML", nor a pure object framework with weak complex querying — it merges the strengths of both and enhances each side.

| Dimension | MyBatis / MyBatis-Plus | Hibernate / JPA | SqlToy |
| --- | --- | --- | --- |
| Positioning | SQL mapping framework; strong querying, weaker object operations | Strong object operations, weaker complex querying | **Both merged**: JPA-style object CRUD + powerful native SQL querying |
| Dynamic SQL | `<if>/<where>` tags fragment the SQL; it cannot run directly in a DB client | No native SQL authoring mode | `#[]` condition fragments: SQL keeps its native shape and **runs directly in any database client** |
| update | Hand-written SQL or load-then-modify | Load then modify — **two database interactions** | **Elastic update**: one interaction, null fields skipped automatically |
| High-concurrency ledger scenarios | Build your own locking with multiple interactions | No equivalent | **updateFetch / updateSaveFetch**: one interaction does lock-query → validate → modify → return |
| Code-to-name display | Hand-written JOINs or extra queries | Cumbersome associations | **Cache translate**: join-free, local cache with zero network cost |
| Pagination | Usually a plain `select count(1) from (your sql)` wrapper | Has paging API, no count optimization | **Smart count rewriting** + cached pagination + `@fast` fast pagination + parallel pagination |
| Cross-database | SQL bound to a specific dialect | Object operations port, querying weak | **25 dialects** + function auto-replacement + dialect sqlId + multi-DB replay verification |
| Analytics | Hand-written pivot/summary SQL | Not supported | Built-in in-memory algorithms: pivot/unpivot, group summary, YoY & MoM, tree sort & rollup |
| Result packaging | Manual ResultMap | Object mapping | Auto mapping + **parent-child hierarchy packaging** (one join SQL packed into nested objects) |
| Condition building | `QueryWrapper`/`LambdaQueryWrapper` (multi-table needs an extra plugin) | Criteria API, verbose | Built-in `LambdaQuery/LambdaUpdate/LambdaDelete`: one builder for single-table and joins, plus CTE / UNION / `@fast` pushdown |

> Key differences only — see the feature list below and the [full catalog](en/introduction/feature.md); side-by-side writing examples (SqlToy vs MyBatis) live in [Best Picks](en/best/best_practices.md).

### On jOOQ / Fluent-Mybatis and other "SQL-fluent API" frameworks

These frameworks model SQL with Java objects and fail compilation when a column changes. SqlToy's take: **they shine for single-table simple queries, but multi-table complex querying becomes over-wrapping**. The yardstick is whether **debug-time authoring, project integration and later maintenance stay the same experience**:

- **Two-way conversion cost**: SQL is debugged in a database client, then "translated" into Java; when requirements change you edit Java and translate back to the client to verify — the more complex the SQL and the more frequent the changes, the more this tax compounds. SqlToy SQL keeps its native shape: **copy it to the client to run, paste it back when done**;
- **Expressiveness**: SQL has a huge function library plus `/*+ hint */` optimizer hints — can a Java fluent API cover them all? For multi-table joins and nested analytics, Java-assembled SQL is far less readable than the native form;
- **Benefit vs. cost**: "compile error on column rename" buys little — how often do projects rename tables or columns? And once the fluent API hits a gap, you fall back to raw strings anyway.

## Key Features

SqlToy provides efficient ORM operations including object CRUD, cascade loading and automatic DDL generation. For data modification it offers elastic (null-skipping) updates and strong transactional capabilities, with sharding, various primary-key strategies and field encryption built in. For querying it supports intuitive SQL authoring, cache-translate optimization and cross-database adaptation, delivering a four-layer pagination mechanism (automatic count optimization, cached pagination, fast pagination and parallel pagination). It also covers analytics (pivot/unpivot, YoY & MoM, tree processing), hierarchical data structures, multi-tenancy isolation, data encryption/decryption & masking, and more enterprise-grade features.

| Category | Highlights | Docs |
| --- | --- | --- |
| [Object operations](en/crud/sqltoy_crud.md) | JPA-style CRUD, elastic update, updateFetch / updateSaveFetch, cascades, query hierarchy packaging, tree-table routes | [Object CRUD](en/crud/sqltoy_crud.md) |
| [SQL query](en/query/dynamic_sql.md) | Dynamic SQL (`#[]` + filters), lambda conditions (one builder for single-table and joins), cache translate, four-layer pagination (count optimize / cached / fast / parallel), parallel query, stored procedures, stream query | [Dynamic SQL](en/query/dynamic_sql.md) / [Lambda](en/query/lambda_query.md) / [Pagination](en/query/pagination.md) |
| [Analytics](en/query/sqltoy_complex_query.md) | Pivot / unpivot, group summary, YoY & MoM, tree sort & rollup, group concatenation, formatting | [Analytics](en/query/sqltoy_complex_query.md) |
| [Cross-database](en/introduction/db_list.md) | 25 dialects (incl. SAP HANA, HighGo), function auto-replacement, dialect sqlId, multi-DB verification | [Dialects](en/dialect/sqltoy_function.md) / [DB list](en/introduction/db_list.md) |
| [Enterprise](en/enterprise/sqltoy_sharding.md) | Sharding, multi-tenancy, data permission, masking & encryption, data versioning, SQL interceptors, slow SQL | [Sharding](en/enterprise/sqltoy_sharding.md) / [Security](en/enterprise/sqltoy_security.md) |
| [NoSQL](en/nosql/sqltoy_mongo.md) | Elasticsearch (SQL / JSON modes), MongoDB (query / aggregation + cache translate) | [Mongo](en/nosql/sqltoy_mongo.md) / [ES](en/nosql/sqltoy_elasticsearch.md) |
| [Engineering](en/config/sqltoy_config.md) | quickvo code generation, autoDDL, debug hot-reload, GraalVM AOT, Spring Boot / Spring / Solon / plain Java | [Config](en/config/sqltoy_config.md) / [quickvo](en/prepare/quickvo.md) / [GraalVM](en/tools/graalvm_native.md) |

> Full catalog: [SqlToy Feature List](en/introduction/feature.md)

- [Quick Start](en/quickstart/helloworld.md)
- [Online Docs](https://sagframe.github.io/sqltoy-docs)

Here is what a sqltoy query looks like — the SQL stays native (copy it to a DB client and it just runs), conditions inside `#[]` are auto-trimmed when null, and results map straight into typed objects:

```java
List<OrderInfoVO> orders = lightDao.find("""
        select * from SQLTOY_ORDER_INFO t
        where 1=1
        #[and t.status in (:status)]
        #[and t.create_time >= :beginTime]
        """,
        MapKit.keys("status", "beginTime").values(new Integer[] { 1 }, LocalDateTime.now().minusDays(30)),
        OrderInfoVO.class);
```

## Supported Databases

* Mainstream relational databases: MySQL, Oracle, DB2, PostgreSQL, SQL Server, DM, Kingbase, **SAP HANA**, SQLite, H2, OceanBase, PolarDB, GaussDB, TiDB, Oscar, HighGo, MogDB, Vastbase, StarDB
* Distributed OLAP databases: ClickHouse, Doris, StarRocks, Greenplum, Impala (Kudu)
* Time-series database: TDengine (query + object insert)
* Elasticsearch and MongoDB
* Any SQL/JDBC-capable database for queries
