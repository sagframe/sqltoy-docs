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

## 与其他 ORM 的核心区别

SqlToy 的定位是**弥补 JPA 的查询短板、解决 MyBatis 的高频痛点**：既不是"所有 SQL 都要写 XML"的映射框架，也不是"复杂查询乏力"的纯对象框架，而是把两者的长处融合并针对性增强。

| 对比维度 | MyBatis / MyBatis-Plus | Hibernate / JPA | SqlToy |
| --- | --- | --- | --- |
| 定位 | SQL 映射框架，查询强、对象操作偏弱 | 对象操作强，复杂查询偏弱 | **两者融合**：JPA 式对象 CRUD + 超强原生 SQL 查询 |
| 动态 SQL | `<if>/<where>` 标签把 SQL 割裂，无法直接在客户端执行 | 不提供原生 SQL 编写模式 | `#[]` 条件片段：SQL 保持原生结构，**可直接复制到数据库客户端运行调试** |
| update 修改 | 手写 SQL 或先查后改 | 先 load 再改，**两次数据库交互** | **弹性更新**：一次交互完成，null 字段自动跳过 |
| 高并发台账类场景 | 需自行实现锁与多次交互 | 无对应能力 | **updateFetch / updateSaveFetch**：一次交互完成锁查询→校验→修改→返回 |
| 码值→名称显示 | 手写 JOIN 或多次查询 | 关联映射繁琐 | **缓存翻译**：免 join，本地缓存零网络开销 |
| 分页 | 通常是简单包裹 `select count(1) from (原sql)` | 有分页 API，无 count 优化 | **智能 count 改写** + 缓存分页 + `@fast` 快速分页 + 并行分页 |
| 跨数据库 | SQL 绑定特定数据库方言 | 对象操作可跨库，查询能力弱 | 24 种方言 + 函数自动替换 + 方言 sqlId + 多库重放验证 |
| 数据分析 | 手写复杂透视/汇总 SQL | 不支持 | pivot/unpivot、分组汇总、同比环比、树形排序汇总 内置内存算法 |
| 查询结果封装 | ResultMap 手动映射 | 对象映射 | 自动映射 + **主子表层次封装**（一条 join SQL 封装成父子对象） |

> 上表只列关键差异，完整能力见下方功能特性与[功能清单](./introduction/feature.md)；更多"为什么这样设计"的对比示例（sqltoy vs MyBatis 写法对比等）见[必杀集锦](./best/best_practices.md)。

### 关于 jOOQ / Fluent-Mybatis 等"代码拟合 SQL"框架

这类框架的出发点是用 Java 对象化拟合 SQL、数据库改字段时代码直接报错。sqltoy 的看法是：**单表简单查询它们确有优势，但多表复杂查询属于过度包装**。判断的核心标准是：**编写调试 → 项目融入 → 后期维护能否高度一致**：

- **双向转化成本**：SQL 先在客户端调试，再"翻译"成 Java 代码融入项目；需求变更后改 Java，还要再"翻译"回客户端验证——sql 复杂一点、变更频繁一点，这种双向转化的消耗会持续放大。而 sqltoy 的 SQL 保持原生形态，**copy 到客户端就能跑、改完 copy 回来就能用**；
- **表达能力**：SQL 的函数体系与 `/*+ hint */` 优化器提示非常丰富，Java API 拟合能覆盖全吗？多表关联、多层嵌套的复杂统计用 Java 拼装，可读性远低于原生 SQL；
- **收益与成本**："改字段编译报错"的收益有限——见过谁做项目天天改表名、改字段名？而不完全覆盖的拟合 API，最终依然要写字符串兜底。

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