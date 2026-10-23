# Sharding

> SqlToy supports database and table sharding, though with the rise of distributed databases such as Doris and StarRocks, horizontal sharding matters less than it used to. **The usage that keeps paying off is splitting "live" tables from "history" tables by date** (recent data stays hot, older data is archived), plus hashing across several databases. This chapter covers the full strategy configuration, the three declaration styles (annotation / XML / code) and the known boundaries.

## 1. Two sharding dimensions

| Dimension | What it decides | Where it is declared |
| --- | --- | --- |
| **Database** (datasource) | Which datasource executes the SQL | `<sharding-datasource>` / `QueryExecutor.dbSharding(...)` / `@Sharding(db=...)` |
| **Table** | Which physical table replaces the table name in the SQL | `<sharding-table tables="..." />` / `QueryExecutor.tableSharding(...)` / `@Sharding(table=...)` |

Either can be used alone, or both together (one SQL sharded across databases and several tables, each with its own strategy). **Queries** declare sharding in XML or code; **inserts/updates/deletes** declare it on the entity with `@Sharding`.

## 2. Sharding strategies

SqlToy ships two ready-made implementations; you can also write your own.

### 2.1 The strategy interface

```java
public interface ShardingStrategy {
    /** Decides the table for the current SQL; returning null means "use the original table" */
    String getShardingTable(SqlToyContext sqlToyContext, Class entityClass, String baseTableName,
            String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

    /** Decides the database to execute on; an empty model means "use the current default datasource" */
    ShardingDBModel getShardingDB(SqlToyContext sqlToyContext, Class entityClass, String tableOrSql,
            String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

    /** Bean initialisation (initMethod): validates the configuration and starts the availability monitor */
    void initialize();
}
```

`paramsMap` holds the values of the fields declared by the strategy's `fields`; `decisionType` lets a strategy distinguish scenarios (query/update, etc.).

### 2.2 HashShardingStrategy (hash modulo, in core)

| Setter | Notes |
| --- | --- |
| `setDataSourceMap(Map<String,String>)` | `modulo result → datasource name`, keys `"0"`, `"1"`… |
| `setTableMap(Map<String,String>)` | `modulo result → physical table name`, same keys |

The modulo is `Math.floorMod(hashCode, N)` (safe for negative hashes, so values never silently fall back to the base table), where `N` is the number of map entries.

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

> `initialize()` derives the modulus from the map size; **a null sharding value now throws and names the field**, typically because the query parameter alias does not match `@Strategy.fields`, or the sharding column is itself empty.

### 2.3 DefaultShardingStrategy (date-based table sharding + weighted database sharding)

This class lives in the **spring / spring-starter module** (package unchanged: `org.sagacity.sqltoy.plugins.sharding.impl`); core only keeps `HashShardingStrategy`, so a plain-Java setup must add the spring module or implement the strategy itself.

| Setter | Notes |
| --- | --- |
| `setDays("14")` / `setDays("1,15,90")` | **Day thresholds** (ascending), matched one-to-one with the table-name array of `setTableNamesMap` |
| `setTableNamesMap(Map)` | `base table name → "table1,table2,table3"` (comma separated, in the same order as `days`) |
| `setDataSourceWeight(Map<String,Integer>)` | `datasource name → weight`, routed probabilistically (only when there is more than one entry) |
| `setCheckSeconds(int)` | Availability check interval (seconds) |
| `setDateParams("bizDate")` | Name(s) of the business-date parameter(s) used to compute the interval; the first non-null one wins |

**How date-based table matching works** (the part that is easiest to get wrong — align it carefully):

- Compute `intervalDays = |today - businessDate|`;
- Walking `days` in the order written, take the **first** `i` where `intervalDays >= days[i]`;
- On a hit use `tables[i]` (the table array must be aligned with the same order); **when nothing matches** (the interval is smaller than the smallest threshold) it returns null and the **original table** in the SQL is used;
- The original table therefore covers the "most recent tier" — **do not put the base table itself into `tables`**, or every tier shifts and only `tables[0]` can ever be selected.

```java
// Correct: base (live) table covers a 15-day window; anything older goes to the history table
@Bean(name = "realHisTable", initMethod = "initialize")
public DefaultShardingStrategy realHisTable() {
    DefaultShardingStrategy strategy = new DefaultShardingStrategy();
    strategy.setDays("14");
    HashMap<String, String> tableMap = new HashMap<>();
    tableMap.put("SQLTOY_TRANS_LOG_15D", "SQLTOY_TRANS_LOG_HIS");
    strategy.setTableNamesMap(tableMap);
    return strategy;
}

// Three tiers: base = today's table; 1-14 days -> _15; 15-89 days -> _90; 90+ -> _HIS
@Bean(name = "threeTierTable", initMethod = "initialize")
public DefaultShardingStrategy threeTierTable() {
    DefaultShardingStrategy strategy = new DefaultShardingStrategy();
    strategy.setDays("1,15,90");                       // ascending thresholds
    HashMap<String, String> tableMap = new HashMap<>();
    tableMap.put("SQLTOY_TRANS_INFO",                  // base (today)
            "SQLTOY_TRANS_INFO_15,SQLTOY_TRANS_INFO_90,SQLTOY_TRANS_INFO_HIS");
    strategy.setTableNamesMap(tableMap);
    return strategy;
}
```

**Weighted routing plus automatic probing**: once `setDataSourceWeight` is configured, `initialize()` starts an `IdleConnectionMonitor` daemon thread:

- It starts 60 seconds after initialisation and checks every datasource's connectivity each `checkSeconds`;
- When a database is unreachable its **weight is temporarily set to 0 with an error log**, so subsequent requests do not route there probabilistically; the weight is restored once it recovers;
- With a single datasource no probabilistic choice happens — it is used directly.

```java
@Bean(name = "weightDataSource", initMethod = "initialize")
public DefaultShardingStrategy weightDataSource() {
    DefaultShardingStrategy strategy = new DefaultShardingStrategy();
    HashMap<String, Integer> weight = new HashMap<>();
    weight.put("ds1", 70);   // 70% of requests land on ds1
    weight.put("ds2", 30);
    strategy.setDataSourceWeight(weight);
    strategy.setCheckSeconds(120);   // probe every 2 minutes
    return strategy;
}
```

> Weighting is per-request probabilistic routing and gives no cross-database transactional consistency; for write-heavy, strongly consistent workloads, question whether weighted sharding is really needed.

## 3. Declaration style 1: entity annotation (insert/update/delete)

Annotate the POJO with `@Sharding`, after which `lightDao.save/update/delete/load` route automatically:

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

For table sharding only, drop `db`:

```java
@Sharding(table = @Strategy(name = "realHisTable", fields = { "bizDate" }))
```

> Full attribute reference for `@Sharding` (including `maxConcurrents`, `maxWaitSeconds`, `is_global_rollback`) is in the [Annotations Cheat Sheet · @Sharding](en/appendix/annotations.md).

## 4. Declaration style 2: XML (queries)

```xml
<sql id="sys_queryTransInfo">
    <!-- modulo on tenant id decides the datasource -->
    <sharding-datasource strategy="hashDataSource" params="tenantId" />
    <!-- the business date decides which table to query -->
    <sharding-table tables="SQLTOY_TRANS_INFO" strategy="realHisTable" params="bizDate" />
    <value><![CDATA[
        select * from SQLTOY_TRANS_INFO
        where tenant_id=:tenantId and biz_date<=:bizDate
    ]]></value>
</sql>
```

- `params` names the parameter(s) supplying the values, matching the strategy's `@Strategy.fields`;
- `tables` lists the physical tables this strategy may substitute for (matching the table in the original SQL).

## 5. Declaration style 3: code (QueryExecutor / EntityQuery)

```java
lightDao.findByQuery(new QueryExecutor("""
        select * from SQLTOY_TRANS_INFO where tenant_id=:tenantId and biz_date<=:bizDate
        """)
        .values(MapKit.keys("tenantId", "bizDate").values("S001", LocalDate.now().minusDays(2)))
        .dbSharding("hashDataSource", "tenantId")
        .tableSharding("realHisTable", new String[] { "SQLTOY_TRANS_INFO" }, "bizDate"));
```

`EntityQuery` offers `dbSharding`/`tableSharding` too, for the single-table paths (`findEntity`/`updateByQuery`/`deleteByQuery`, etc.).

## 6. Parallel execution, global rollback and exceptions

- `@Sharding.maxConcurrents` (default 10) controls how many shards run in parallel: **0 means unlimited, 1 means serial** (6.0.3 fixed the case where 1 had no effect);
- `maxWaitSeconds` bounds the parallel wait;
- With `is_global_rollback` (default true) any failing shard rolls everything back;
- Since 6.0.3 `ShardingResult` carries a `cause` field preserving the failing shard's original exception, and the `DataAccessException` thrown by a global rollback includes the root-cause stack trace.

## 7. Known boundaries

- **Cross-database joins and pagination are not supported**: merging paginated results across databases and tables is disproportionately expensive and points at a design problem; use an MPP database such as ClickHouse/StarRocks instead (both supported by sqltoy) — see the [FAQ](en/faq/faq.md);
- **Transactions after database sharding**: cross-database writes need JTA or a distributed-transaction framework; see [Multi-Datasource & Transactions](en/config/dynamic_datasource.md);
- **`@DataVersion`/cache translate on sharded tables**: table substitution happens at the SQL layer, so entity-level enhancements still apply; but after **database** sharding a single SQL only runs on one database, so aggregate statistics must be assembled by hand;
- **Strategy beans must implement `initialize()` and declare `initMethod="initialize"`**: the weighted probing of `DefaultShardingStrategy` and the modulus of `HashShardingStrategy` are set up there. Under native images, declare the **concrete return type** on the `@Bean` (an interface declaration leaves the init method unresolvable) — see the [GraalVM Native Image Guide](en/tools/graalvm_native.md).

## 8. Related

- Datasource configuration and transactions: [Multi-Datasource & Transactions](en/config/dynamic_datasource.md)
- Annotation attributes: [Annotations Cheat Sheet](en/appendix/annotations.md)
- Demo project: [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase) (`DataSourceConfig` contains complete hash and date sharding setups)
