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

- [快速开始](./quickstart/helloworld.md)
- [开发文档](https://sagframe.github.io/sqltoy-docs)

```java
Object list = lightDao.find("select * from sqltoy_order_info", new HashMap());
```

## 支持的数据库

* 常规的mysql、oracle、db2、postgresql、 sqlserver、dm、kingbase、sqlite、h2、 oceanBase、polardb、gaussdb、tidb、oscar(神通)、瀚高、mogdb、vastbase、stardb
* 支持分布式olap数据库: clickhouse、StarRocks、greenplum、impala(kudu)
* 支持elasticsearch、mongodb
* 所有基于sql和jdbc 各类数据库查询