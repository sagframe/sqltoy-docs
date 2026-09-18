## 项目介绍

#### Sqltoy一个真正智慧的Java ORM框架!

Sqltoy以最佳的动态sql编写模式作为起点，并首创了缓存翻译、分页优化、快速分页、sql函数不同数据库自适配等高价值特性，同时对项目实践过程中各类复杂场景提供了极为细致的解决方案！

> 通过开源分享已经凝聚了更广泛用户的场景和智慧,欢迎您的加入共同打造一个中国式智慧的ORM框架!

<p align="center">
    <a target="_blank" href="LICENSE"><img src="https://img.shields.io/:license-Apache%202.0-blue.svg"></a>
    <a target="_blank" href="https://github.com/sagframe/sagacity-sqltoy"><img src="https://img.shields.io/github/stars/sagframe/sagacity-sqltoy.svg?style=social"/></a>
    <a target="_blank" href="https://gitee.com/sagacity/sagacity-sqltoy"><img src="https://gitee.com/sagacity/sagacity-sqltoy/badge/star.svg?theme=white" /></a>
    <a target="_blank" href="https://github.com/sagframe/sagacity-sqltoy/releases"><img src="https://img.shields.io/github/v/release/sagframe/sagacity-sqltoy?logo=github"></a>
    <a href="https://mvnrepository.com/artifact/com.sagframe/sagacity-sqltoy">
        <img alt="maven" src="https://img.shields.io/maven-central/v/com.sagframe/sagacity-sqltoy?style=flat-square">
    </a>
</p>

## 功能特性

sqltoy提供高效的ORM操作，包括对象化CRUD、级联加载、自动DDL生成等。在数据修改方面，提供弹性字段更新、强事务处理能力，支持分库分表、多种主键策略和数据加密。查询方面支持直观的SQL编写、缓存翻译优化、跨数据库自适配，提供业界最强的分页机制（自动count优化、缓存分页、快速分页、并行分页）。此外还支持数据分析（行列转换、同比环比、树形处理）、层次化数据结构、多租户隔离、数据脱敏等企业级特性。

| 类别 | 核心能力 | 文档 |
| --- | --- | --- |
| [对象操作](./crud/sqltoy_crud.md) | JPA 风格 CRUD、弹性更新、updateFetch / updateSaveFetch、级联、查询层次封装、树形表路由 | [CRUD](./crud/sqltoy_crud.md) |
| [SQL 查询](./query/dynamic_sql.md) | 动态 SQL（`#[]` + filters）、缓存翻译、最强分页（count 优化 / 缓存 / 快速 / 并行）、并行查询、存储过程、流式查询 | [动态 SQL](./query/dynamic_sql.md) / [分页](./query/pagination.md) |
| [数据分析](./query/sqltoy_complex_query.md) | 行转列 / 列转行、分组汇总、同比环比、树形排序汇总、分组拼接、日期数字格式化 | [数据分析](./query/sqltoy_complex_query.md) |
| [跨数据库](./dialect/sqltoy_function.md) | 24 种方言（含 SAP HANA）、函数自动替换、多方言 sqlId、多库适配验证 | [方言](./dialect/sqltoy_function.md) / [数据库清单](./introduction/db_list.md) |
| [企业级](./enterprise/sqltoy_multitenant.md) | 分库分表、多租户、数据权限与越权校验、脱敏加解密、数据版本控制、SQL 拦截、慢 SQL 处理 | [分库分表](./enterprise/sqltoy_sharding.md) / [安全](./enterprise/sqltoy_security.md) |
| [NoSQL](./nosql/sqltoy_mongo.md) | Elasticsearch（sql / json 双模式）、MongoDB（查询 / 聚合 + 缓存翻译） | [Mongo](./nosql/sqltoy_mongo.md) / [ES](./nosql/sqltoy_elasticsearch.md) |
| [工程化](./config/sqltoy_config.md) | quickvo 代码生成、autoDDL 自动建表、debug 热加载、GraalVM AOT、Spring Boot / Spring / Solon / 纯 Java | [配置](./config/sqltoy_config.md) / [quickvo](./prepare/quickvo.md) |

> 完整功能清单见 [sqltoy 功能清单](./introduction/feature.md)

- [快速开始](./quickstart/helloworld.md)
- [开发文档](https://sagframe.github.io/sqltoy-docs)

```java
Object list = lightDao.find("select * from sqltoy_order_info", new HashMap());
```

## 支持的数据库

* 常规的mysql、oracle、db2、postgresql、 sqlserver、dm、kingbase、hana、sqlite、h2、 oceanBase、polardb、gaussdb、tidb、oscar(神通)、瀚高、mogdb、vastbase、stardb
* 支持分布式olap数据库: clickhouse、doris、StarRocks、greenplum、impala(kudu)、TDengine
* 支持elasticsearch、mongodb
* 所有基于sql和jdbc 各类数据库查询