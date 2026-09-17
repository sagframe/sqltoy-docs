# 常见问题解答（FAQ）

## 一、分库分表为什么不支持多库多表的查询和分页？

实现并不难，复杂的是多库多表查询后的分页归并。sqltoy 不做这个实现**不是做不了，而是没有必要**——出现这种需求本质是设计问题。目前一般做法是通过 MPP 数据库来解决，如 ClickHouse、StarRocks，这些 sqltoy 都支持。

详见[分库分表](../enterprise/sqltoy_sharding.md)。

## 二、sqltoy-orm 性能如何？

sqltoy 的出发点之一就是解决性能问题：

- **主键策略**：支持非中心式的程序自动产生模式（22 位、26 位有序纳秒、雪花算法等）。早期用过数据库锁模式，教训惨烈。
- **update 操作**：改变 hibernate"先 load 再 update"的模式，变成**一步数据库交互**（弹性更新）。
- 所有 SQL 查询都基于 `PreparedStatement`，减少数据库对 SQL 的预编译过程。
- 批量、级联加载都基于批量查询，用程序在后台组织数据，避免多次数据库交互（参见 `loadAllCascade` 底层实现）。
- 分页除快速分页、分页优化外，对 count 查询的优化达到极致，不是简单的 `select count(1) from (你的sql) as t`。

系统核心瓶颈大多在 IO（尤其数据库 IO），sqltoy 在数据库交互上做了大量优化。框架自身对 SQL 语句的组织处理消耗极微，通常在 **1 毫秒以内**。

## 三、数据库保留字如何处理？

在 `sqltoyContext` 中指定 `reservedWords` 属性，定义当前系统用到的保留字。

- **基于对象的操作**：sqltoy 自动完成保留字兼容。
- **自定义 SQL**：需按当前数据库对特定字段自行处理，如 SQL Server 中保留字要加 `[]`：

```sql
select [maxvalue],name from table
```

跨数据库时，sqltoy 会根据定义的 `reservedWords` 对自定义 SQL 中的保留字进行适配。例如上述 SQL 在 MySQL 项目下会自动变成：

```sql
select `maxvalue`,name from table
```

> 注意：是把 `[maxvalue]` 转成 `` `maxvalue` ``，而不是直接把 `maxvalue` 转成 `` `maxvalue` ``。

## 四、多数据源怎么弄？

sqltoy 可以配置默认数据源：

```properties
spring.sqltoy.defaultDataSource=primaryDB
```

多种实现方式：

1. **dynamic-datasource**（支持事务）：范例 https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-dynamic-datasource
2. **定义多个 `LightDao`**，给不同的 lightDao 注入不同的 dataSource，在 service 中按 bean 名称引入。
3. **查询级切换**：`findByQuery`/`findPageByQuery` 等的 `QueryExecutor` 中可直接 `.dataSource(xxx)`；链式 API 也支持 `.dataSource(...)`（见 [Link 链式操作](../query/link_api.md)）。
4. 涉及**多数据库事务**时，可结合 JTA 实现，参照 https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-sharding

## 五、可以跟其他 ORM 一起组合使用吗？

可以。你可以独立使用 sqltoy，也可以结合 JPA + sqltoy 的查询，根据实际情况灵活组合。

## 六、多字段 in 如何处理？

直接用元组 in 写法，参数传数组/集合即可：

```sql
#[and (t.TECH_GROUP,t.PROD_GROUP) in (:techGroups,:prodGroups)]
```

当 in 条件参数数组超过 1000（如 Oracle 限制）时，框架（5.1.32 / 4.19.25 起）会**自动切分**，无需手工处理。也可用 `@secure-loop` 拼接复杂条件，见[补充说明：标签与表达式参考](../appendix/tags.md)。

## 七、sqltoy 是否能在非 Spring 和 Solon 环境下使用？

支持。sqltoy 核心模块 `sagacity-sqltoy` 可纯 Java 使用，自行构建 `SqlToyContext` + 数据源 + `DefaultLightDaoImpl` 即可，事务用 `DBTransUtils`。详见[纯 Java 项目如何使用](../config/pure_java.md)。
