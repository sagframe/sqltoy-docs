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
- 分页除快速分页、分页优化外，对 count 查询做了针对性优化，不是简单的 `select count(1) from (你的sql) as t`。

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

完整的 dynamic-datasource 配置、`@DS` 切换与 `@DSTransactional` 跨库事务范例，见[多数据源与事务](../config/dynamic_datasource.md)。

sqltoy 可以配置默认数据源：

```properties
spring.sqltoy.defaultDataSource=primaryDB
```

多种实现方式：

1. **dynamic-datasource**（支持事务）：详见[多数据源与事务](../config/dynamic_datasource.md)
2. **定义多个 `LightDao`**，给不同的 lightDao 注入不同的 dataSource，在 service 中按 bean 名称引入。
3. **查询级切换**：`findByQuery`/`findPageByQuery` 等的 `QueryExecutor` 中可直接 `.dataSource(xxx)`；链式 API 也支持 `.dataSource(...)`（见 [Link 链式操作](../query/link_api.md)）。
4. 涉及**多数据库事务**时，可结合 JTA 实现（如 Atomikos/Narayana）。sqltoy 原生的命名多数据源演示见 [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase) 的 `MultiDataSourceTest`。

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

## 八、启动就报 sqlId 重复 / 后加载的 SQL 覆盖前面的？

默认 `breakWhenSqlRepeat=true`：发现重复 `sqlId` **直接抛异常终止启动**，这是刻意设计——同名 sql 在两个文件里各写一份，线上很可能执行到错的那条。

排查：

```properties
# 临时定位用：改为 false，后面的覆盖前面的（仅用于排查，不要带到生产）
spring.sqltoy.breakWhenSqlRepeat=false
```

- 常见原因：模块拆分后两个 `*.sql.xml` 用了同一个 `id`；`@Sql` 注解里的 id 与 xml 冲突；
- **注意**：`sqlId` 是全局命名空间，不带模块前缀；建议命名加业务前缀（如 `crm_staff_findlist`）；
- 若确实需要按数据源区分同名 SQL，用 `<sql dataSource="...">` 或方言变体（`xxx_mysql`），而不是两个同名文件。

详见[动态 SQL 编写规范](../query/dynamic_sql.md)。

## 九、缓存翻译不生效 / 数据改了页面还是旧值？

按下面顺序排查：

1. **缓存没加载**：`translateConfig` 指向的文件没被扫到（默认 `classpath:sqltoy-translate.xml;classpath:translates`），启动日志里能看到加载了几个 cache；
2. **参数没对上**：`<translate columns="POST_TYPE" cache="dictCache">` 的 `columns` 必须是**结果集中的列名**，不是属性名；
3. **码值类型不一致**：`1`（数字）与 `"1"`（字符串）匹配不到，可用 filter 的 `to-string` 统一；
4. **增量更新没开**：默认全量加载后不再变；要跟随库表变化需配 `cache-update-checker`（按时间戳/版本增量）或 `rest-checker`（外部接口）；
5. **FIFO 动态缓冲的预期行为**：`dynamic-cache` 模式只更新**本地已存在**的 key，没加载过的 key 下次动态获取时自然是新值——这不是 bug；
6. **多实例**：本地缓存（ehcache/caffeine）各实例独立，增量检测间隔内不同实例数据可能短暂不一致，对强一致要求高的码表请缩短检测间隔或改用 `rest-checker`。

详见[缓存翻译使用](../quickstart/translates.md)与[超大规模主数据缓存](../translate/sqltoy_FIFO_translate.md)。

## 十、用了 `@fast` 之后 count 和实际数据对不上？

`@fast` 的语义是"**先对内层分页取 pageSize 条，再拿这几条去 join 外表**"，因此它的 count **默认用 @fast 内层 SQL**（简化形态，跳过 join 过滤）。如果 join 后的外表条件会改变结果行数，count 就会与数据不一致。

处理方式（按优先级）：

1. **把过滤条件下推到 @fast 内层**（内层能过滤的不要放到外层 join 条件里）；
2. 用 `<count-sql>` 显式给出 count（`QueryExecutor.countSql(...)` 同理），这是最可控的做法；
3. 确认不是 `union` 场景——`union` 的 count 有专门的 union-all-count 优化（拆分支求和），与 `@fast` 叠加时以 `count-sql` 为准。

详见[分页优化](../query/pagination.md)。

## 十一、分页查不出数据 / 报"超过最大单页数据量"？

两个保护机制，都可配置：

| 参数 | 默认 | 行为 |
| --- | --- | --- |
| `pageFetchSizeLimit` | 100000 | 单页最大记录数；`pageNo` 传 `-1` 做全量提取时会撞上它（`-1` 表示不限制） |
| `overPageToFirst` | 未设置 | 页码超过最大页时是否回到第一页；不设置时按框架内置行为处理，建议显式配置 |

```properties
# 明确需要大页导出时调大（注意内存）
spring.sqltoy.pageFetchSizeLimit=500000
# 页码越界回到首页
spring.sqltoy.overPageToFirst=true
```

> 大结果集导出不建议用分页，用 `fetchStream`（流式回调）或 `findTop` 分批。详见[分页优化](../query/pagination.md)。

## 十二、lambda 的 `getOne()` 为什么抛异常了？

这是 6.0.8 起的**严格语义**：0 条返回 `null`，**多于 1 条抛 `DataAccessException`（异常里带匹配条数）**。目的是避免"条件缺陷被静默掩盖成取第一条"的错值。

处理：

- 条件确实应唯一 → 检查是不是漏了租户/状态等条件；
- 确实可能多条但只需要一条 → 改用 `find()` 取第一条，或加 `orderBy` + `findTop(1)`；
- 同理，**不带任何 where 的 `update()/delete()` 默认抛异常**，需要全表操作时显式 `.matchAll()`。

详见[Lambda 条件查询与更新](../query/lambda_query.md)。

## 十三、native 镜像里 lambda 条件不可用 / 启动报反射缺失？

lambda 依赖 `SerializedLambda` 与序列化镜像来提取属性名，closed-world 的 native 镜像必须显式注册：

- **应用侧**：按"lambda 定义类"注册（spring 用 `META-INF/native-image/**/serialization-config.json` 的 `lambdaCapturingTypes`，或 `registerLambda(定义类, b -> b.withInterfaces(LambdaFn.class))`；solon 用 `registerLambdaSerialization(定义类)`）；
- 不注册 = native 下 lambda 体系全部不可用（JVM 模式不受影响）；
- 另外 **`updateSaveFetch` 在 native 下需要 `native-entity-proxies`** 预生成代理，否则该分支不可用。

完整清单（实体扫描、DTO 反射、扩展类、函数类、JSON/vector/geometry 驱动类）见 [GraalVM Native Image 指引](../tools/graalvm_native.md)。

## 十四、从 sqltoy-plus / MyBatis 迁过来要改什么？

- **sqltoy-plus**：6.0.8 已把 lambda 能力并入核心，移除插件依赖与 `@EnableSqlToyPlus`，按[升级指南第十节第 2 条](../introduction/upgrade_6.0.md)的对照表改包名/类名，并回归 `getOne()` 多匹配、无条件 update/delete 两类行为变化；
- **MyBatis / MyBatis-Plus**：`<if>` → `#[]`、`QueryWrapper` → `EntityQuery` 或 lambda、`ResultMap` → 结果类型/VO 映射、分页插件 → `findPage`。完整对照与落地顺序见[从 MyBatis 迁移](../introduction/migration.md)。
