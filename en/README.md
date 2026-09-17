## Introduction

#### SqlToy — a truly intelligent Java ORM framework!

SqlToy starts from the cleanest dynamic-SQL authoring model and pioneers high-value features such as **Cache Translate**, **Pagination Optimize**, **Fast Pagination** and automatic **cross-database function adaptation**, while providing carefully-crafted solutions for nearly every complex scenario found in real-world projects!

> Through open-source sharing we have gathered scenarios and wisdom from a broad community — join us in building a China-born intelligent ORM framework!

> 🌍 **About this English site**: the Chinese documentation is the source of truth. Sidebar entries marked **（中文）** are not translated yet and link to the Chinese pages.

<p align="center">
    <a target="_blank" href="LICENSE"><img src="https://img.shields.io/:license-Apache%202.0-blue.svg"></a>
    <a target="_blank" href="https://github.com/sagframe/sagacity-sqltoy"><img src="https://img.shields.io/github/stars/sagframe/sagacity-sqltoy.svg?style=social"/></a>
    <a target="_blank" href="https://gitee.com/sagacity/sagacity-sqltoy"><img src="https://gitee.com/sagacity/sagacity-sqltoy/badge/star.svg?theme=white" /></a>
    <a target="_blank" href="https://github.com/sagframe/sagacity-sqltoy/releases"><img src="https://img.shields.io/github/v/release/sagframe/sagacity-sqltoy?logo=github"></a>
    <a href="https://mvnrepository.com/artifact/com.sagframe/sagacity-sqltoy">
        <img alt="maven" src="https://img.shields.io/maven-central/v/com.sagframe/sagacity-sqltoy?style=flat-square">
    </a>
</p>

## Key Features

SqlToy provides efficient ORM operations including object CRUD, cascade loading and automatic DDL generation. For data modification it offers elastic (null-skipping) updates and strong transactional capabilities, with sharding, various primary-key strategies and field encryption built in. For querying it supports intuitive SQL authoring, cache-translate optimization and cross-database adaptation, delivering the industry's strongest pagination mechanism (automatic count optimization, cached pagination, fast pagination and parallel pagination). It also covers analytics (pivot/unpivot, YoY & MoM, tree processing), hierarchical data structures, multi-tenancy isolation, data masking and more enterprise-grade features.

- [Quick Start](./quickstart/helloworld.md)
- [Online Docs](https://sagframe.github.io/sqltoy-docs)

```java
Object list = lightDao.find("select * from sqltoy_order_info", new HashMap());
```

## Supported Databases

* Mainstream relational databases: MySQL, Oracle, DB2, PostgreSQL, SQL Server, DM, Kingbase, **SAP HANA**, SQLite, H2, OceanBase, PolarDB, GaussDB, TiDB, Oscar, HighGo, MogDB, Vastbase, StarDB
* Distributed OLAP databases: ClickHouse, Doris, StarRocks, Greenplum, Impala (Kudu), TDengine
* Elasticsearch and MongoDB
* Any SQL/JDBC-capable database for queries
