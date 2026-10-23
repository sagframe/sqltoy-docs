# 分库分表

> sqltoy 支持分库分表，但随着 Doris、StarRocks 等分布式高性能数据库的普及，水平分库分表的意义在淡化。**真正长期有效的用法是"按日期把实时表和历史表分离"**（近期数据在实时表、历史数据归档到历史表），以及多库按 hash 水平拆分。本章给出完整的策略配置、注解/XML/代码三种声明方式与已知边界。

## 一、两种分片维度

| 维度 | 决定的元素 | 声明位置 |
| --- | --- | --- |
| **分库**（datasource） | 同一条 SQL 落到哪个数据源执行 | `<sharding-datasource>` / `QueryExecutor.dbSharding(...)` / `@Sharding(db=...)` |
| **分表**（table） | SQL 中出现的物理表名替换成哪个表 | `<sharding-table tables="..." />` / `QueryExecutor.tableSharding(...)` / `@Sharding(table=...)` |

两者可单独使用，也可同时使用（一个 SQL 中同时分库 + 多个分表，策略各自独立定义）。**查询**用 XML/代码声明，**增删改**用实体注解 `@Sharding` 声明。

## 二、分片策略

sqltoy 提供两个开箱即用的实现，也可以自行扩展。

### 2.1 策略接口

```java
public interface ShardingStrategy {
    /** 根据条件决定当前 sql 中的表名；返回 null 表示使用原表 */
    String getShardingTable(SqlToyContext sqlToyContext, Class entityClass, String baseTableName,
            String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

    /** 根据条件决定最终执行的库；返回空模型表示使用当前默认数据源 */
    ShardingDBModel getShardingDB(SqlToyContext sqlToyContext, Class entityClass, String tableOrSql,
            String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

    /** bean 初始化（initMethod），用于校验配置、启动探活线程 */
    void initialize();
}
```

`paramsMap` 是策略 `fields` 所声明字段的值映射；`decisionType` 让策略区分场景（查询/更新等）。

### 2.2 HashShardingStrategy（按 hash 取模，core 内置）

| 属性 | 说明 |
| --- | --- |
| `setDataSourceMap(Map<String,String>)` | `取模结果 → 数据源名`，key 为 `"0"`、`"1"`… |
| `setTableMap(Map<String,String>)` | `取模结果 → 物理表名`，key 同上 |

取模用 `Math.floorMod(hashCode, N)`（对负数安全，避免落回基准表），`N` 为映射条目数。

```java
@Bean(name = "hashDataSource", initMethod = "initialize")
public HashShardingStrategy hashDataSource() {
    HashShardingStrategy strategy = new HashShardingStrategy();
    HashMap<String, String> dataSourceMap = new HashMap<>();
    dataSourceMap.put("0", "ds0");
    dataSourceMap.put("1", "ds1");
    strategy.setDataSourceMap(dataSourceMap);
    return strategy;
}
```

> `initialize()` 会按映射条目数确定模数；**分片值为 null 时抛异常并指明字段**，常见诱因是查询条件参数别名与 `@Strategy.fields` 不一致或分片字段本身为空。

### 2.3 DefaultShardingStrategy（按日期分表 + 按权重分库）

该类位于 **spring / spring-starter 模块**（包名不变：`org.sagacity.sqltoy.plugins.sharding.impl`），core 仅保留 `HashShardingStrategy`；纯 Java 环境需引入 spring 模块或自行实现。

| 属性 | 说明 |
| --- | --- |
| `setDays("14")` / `setDays("1,15,90")` | **距今天数阈值**（升序），与 `setTableNamesMap` 的表名数组一一对应 |
| `setTableNamesMap(Map)` | `基准表名 → "表1,表2,表3"`（逗号分隔，按与 `days` 相同的顺序排列） |
| `setDataSourceWeight(Map<String,Integer>)` | `数据源名 → 权重`，按权重概率路由（配置多个时才生效） |
| `setCheckSeconds(int)` | 数据源探活间隔（秒） |
| `setDateParams("bizDate")` | 参与计算间隔的业务日期参数字段名（多个时依次取第一个非空值） |

**按日期分表的匹配规则**（本节最容易踩坑，务必对齐）：

- 计算 `intervalDays = |今天 - 业务日期|`；
- 按 `days` 的书写顺序，取**第一个** `intervalDays >= days[i]` 的 `i`；
- 命中则用 `tables[i]`（表名数组按同一顺序对齐）；**全部不中**（即间隔小于最小阈值）→ 返回 null，使用 SQL 中写的**原表**；
- 因此"原表"承担的是"最近一档"，`tables` 里**不要再放原表本身**，否则各档位会整体错位（顺序命中导致永远只取 `tables[0]`）。

```java
// 正确示例：基准表(实时表) 15 天窗口，超过 14 天走历史表
@Bean(name = "realHisTable", initMethod = "initialize")
public DefaultShardingStrategy realHisTable() {
    DefaultShardingStrategy strategy = new DefaultShardingStrategy();
    strategy.setDays("14");
    HashMap<String, String> tableMap = new HashMap<>();
    tableMap.put("SQLTOY_TRANS_LOG_15D", "SQLTOY_TRANS_LOG_HIS");
    strategy.setTableNamesMap(tableMap);
    return strategy;
}

// 三档示例：原表=当天表；1~14 天 → _15 表；15~89 天 → _90 表；90 天以上 → _HIS
@Bean(name = "threeTierTable", initMethod = "initialize")
public DefaultShardingStrategy threeTierTable() {
    DefaultShardingStrategy strategy = new DefaultShardingStrategy();
    strategy.setDays("1,15,90");                       // 阈值升序
    HashMap<String, String> tableMap = new HashMap<>();
    tableMap.put("SQLTOY_TRANS_INFO",                  // 原表(当天)
            "SQLTOY_TRANS_INFO_15,SQLTOY_TRANS_INFO_90,SQLTOY_TRANS_INFO_HIS");
    strategy.setTableNamesMap(tableMap);
    return strategy;
}
```

**按权重分库 + 自动探活**：配置 `setDataSourceWeight` 后，`initialize()` 会启动 `IdleConnectionMonitor`（守护线程）：

- 启动延迟 60 秒后开始，按 `checkSeconds` 周期检查每个数据源的连通性；
- 某库连不上时**把它当前权重临时置 0 并打 error 日志**，后续请求不再按概率路由到它；恢复后权重复原；
- 只有一个数据源时不做概率选择，直接使用它。

```java
@Bean(name = "weightDataSource", initMethod = "initialize")
public DefaultShardingStrategy weightDataSource() {
    DefaultShardingStrategy strategy = new DefaultShardingStrategy();
    HashMap<String, Integer> weight = new HashMap<>();
    weight.put("ds1", 70);   // 70% 概率落到 ds1
    weight.put("ds2", 30);
    strategy.setDataSourceWeight(weight);
    strategy.setCheckSeconds(120);   // 每 2 分钟探活一次
    return strategy;
}
```

> 权重是"按请求概率路由"，不具备跨库事务一致性；写多读少的强一致场景请评估是否真的需要按权重分库。

## 三、声明方式一：实体注解（增删改）

在 POJO 上加 `@Sharding`，之后 `lightDao.save/update/delete/load` 会自动路由：

```java
@Data
@Accessors(chain = true)
@Entity(tableName = "SQLTOY_TRANS_INFO", pk_constraint = "PRIMARY")
@Sharding(db = @Strategy(name = "hashDataSource", fields = { "tenantId" }),
          table = @Strategy(name = "realHisTable", fields = { "bizDate" }))
public class SqlToyTransInfo implements Serializable {
    @Id
    @Column(name = "ID", type = java.sql.Types.VARCHAR, length = 50, nullable = false)
    private String id;

    @Column(name = "TENANT_ID", type = java.sql.Types.VARCHAR, length = 50, nullable = false)
    private String tenantId;

    @Column(name = "BIZ_DATE", type = java.sql.Types.DATE, nullable = false)
    private LocalDate bizDate;
}
```

只分表时可省略 `db`：

```java
@Sharding(table = @Strategy(name = "realHisTable", fields = { "bizDate" }))
```

> `@Sharding` 的属性完整说明（含 `maxConcurrents`、`maxWaitSeconds`、`is_global_rollback`）见[注解速查 · @Sharding](appendix/annotations.md)。

## 四、声明方式二：XML（查询）

```xml
<sql id="sys_queryTransInfo">
    <!-- 按租户 id 取模决定数据源 -->
    <sharding-datasource strategy="hashDataSource" params="tenantId" />
    <!-- 按日期决定查询哪张表 -->
    <sharding-table tables="SQLTOY_TRANS_INFO" strategy="realHisTable" params="bizDate" />
    <value><![CDATA[
        select * from SQLTOY_TRANS_INFO
        where tenant_id=:tenantId and biz_date<=:bizDate
    ]]></value>
</sql>
```

- `params` 与策略 `@Strategy.fields` 对应，是**取值来源的参数名**；
- `tables` 是该策略可能替换的物理表（与原 SQL 中的表名一致）。

## 五、声明方式三：代码（QueryExecutor / EntityQuery）

```java
lightDao.findByQuery(new QueryExecutor("""
        select * from SQLTOY_TRANS_INFO where tenant_id=:tenantId and biz_date<=:bizDate
        """)
        .values(MapKit.keys("tenantId", "bizDate").values("S001", LocalDate.now().minusDays(2)))
        .dbSharding("hashDataSource", "tenantId")
        .tableSharding("realHisTable", new String[] { "SQLTOY_TRANS_INFO" }, "bizDate"));
```

`EntityQuery` 同样提供 `dbSharding`/`tableSharding`，适用于 `findEntity`/`updateByQuery`/`deleteByQuery` 等单表链路。

## 六、并行执行、全局回滚与异常

- `@Sharding.maxConcurrents`（默认 10）控制多分片并行执行线程数：**0 表示不限制、1 表示串行**（6.0.3 修正了 1 不生效的缺陷）；
- `maxWaitSeconds` 控制并行等待上限；
- 开启 `is_global_rollback`（默认 true）时，任一分片失败即回滚全部；
- 6.0.3 起 `ShardingResult` 新增 `cause` 字段保留失败分片的原始异常，全局回滚抛出的 `DataAccessException` 携带根因堆栈，便于定位。

## 七、已知边界

- **不支持跨库的 join 查询与分页**：多库多表查询后的分页归并成本极高，属于设计问题而非实现问题；这类需求建议用 ClickHouse/StarRocks 等 MPP 数据库（sqltoy 均支持），详见 [FAQ](faq/faq.md)；
- **分库后的事务**：跨库写需要 JTA 或分布式事务框架配合，代码示例见 [多数据源与事务](config/dynamic_datasource.md)；
- **分片表上的 `@DataVersion`/缓存翻译**：分表替换发生在 SQL 层，实体级增强照常生效；但**分库**后单条 SQL 只在其中一个库执行，聚合类统计需要自行汇总；
- **策略 bean 必须实现 `initialize()` 并配 `initMethod="initialize"`**：`DefaultShardingStrategy` 的权重探活、`HashShardingStrategy` 的模数都在该方法里初始化；native 镜像下 `@Bean` 请声明**具体返回类型**（接口声明会导致 initMethod 无法解析），参见 [GraalVM Native Image 指引](tools/graalvm_native.md)。

## 八、相关

- 多数据源配置与事务：[多数据源与事务](config/dynamic_datasource.md)
- 注解属性：[注解速查](appendix/annotations.md)
- 演示项目：[sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase)（`DataSourceConfig` 含 hash 分库与日期分表的完整配置）
