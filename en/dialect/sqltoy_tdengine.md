# TDengine Time-Series Database Support

**Note**: TDengine is an **IoT time-series database** (append-only write model). SqlToy's support for it is scoped to **"query + object insert"**, which differs from the full CRUD offered for relational databases. The rationale: in multi-datasource scenarios (e.g., MySQL for business data + TDengine for device telemetry), use the unified SqlToy API to query and write time-series data, while reusing SqlToy's dynamic conditions, cache translation, and result-set algorithms.

> The support boundaries below are verified against **TDengine 3.3.6.x + taos-jdbcdriver 3.3.0** (REST connection mode).
>
> As an append-only time-series engine, TDengine has **no `UPDATE ... SET` statement, no row-level locks, no stored procedures, and no auto-increment/sequences**. These are engine-level constraints, not framework defects. Section "IV. Unsupported Operations" gives the alternative for each.

## I. Connection Configuration

TDengine offers two JDBC connection modes:

| Mode | URL form | Driver class | Notes |
| --- | --- | --- | --- |
| REST (recommended) | `jdbc:TAOS-RS://host:6041/db` | `com.taosdata.jdbc.rs.RestfulDriver` | Pure Java, via taosAdapter's HTTP API, no native client library needed |
| Native | `jdbc:TAOS://host:6030/db` | `com.taosdata.jdbc.TSDBDriver` | Requires the taos client library on the app server; higher performance |

Maven dependency:

```xml
<dependency>
    <groupId>com.taosdata.jdbc</groupId>
    <artifactId>taos-jdbcdriver</artifactId>
    <version>3.3.0</version>
</dependency>
```

Datasource configuration (REST example):

```yaml
spring:
  datasource:
    url: jdbc:TAOS-RS://192.168.56.101:6041/testdb
    username: root
    password: taosdata
    driver-class-name: com.taosdata.jdbc.rs.RestfulDriver
```

**Dialect detection**: the TDengine driver reports the product name `TDengine`, which SqlToy **auto-detects** as the `tdengine` dialect (`DBType=150`) — no manual configuration needed. To force it, set `spring.sqltoy.dialect=tdengine`.

## II. Supported Operations

### 2.1 Query (fully supported)

`findBySql` / `findPageBySql` / `findTopBySql` / `getRandomResult` / `getCountBySql` / `load` / `loadAll` all go through the generic path and are verified working:

- Pagination `limit ? offset ?`, `count(1)` / `count(*)`, and random queries `order by rand()` are all natively supported by TDengine 3.x;
- Timestamp columns can be compared directly with strings (implicit conversion), so date-condition parameter binding works out of the box;
- When querying a super table (STable), **tags appear as ordinary columns in the result set** and can be mapped directly to VO fields.

```xml
<sql id="meter_query">
    select ts, current, voltage, location, groupId
    from meters
    <where>
        <isNotEmpty property="location">and location = :location</isNotEmpty>
        <isNotEmpty property="beginTime">and ts &gt;= :beginTime</isNotEmpty>
    </where>
    order by ts desc
</sql>
```

```java
// Paginated query (the framework appends limit ? offset ? and the count query automatically)
QueryResult<MeterVO> page = dao.findPageBySql(
    new QueryExecutor("meter_query")
        .setParam("location", "California")
        .setParam("beginTime", beginTime)
        .setResultType(MeterVO.class),
    pageNo, pageSize);
```

### 2.2 Object Insert

There are two write modes for time-series data; choose by scenario:

**Mode A: `save` / `saveAll` into an existing child table / normal table**

The framework generates a standard single-table column-list insert (`insert into child (ts,current,...) values(?,?)`), suitable when the child table already exists. Notes:

- The entity primary key must be a **timestamp column** using the **ASSIGN** strategy (see "III. Constraints");
- The entity should contain **ordinary columns only** (ts, current, voltage…) and **must not include tag columns** — tags are child-table-level metadata, not row fields; including them in the insert column list causes an error;
- For one-child-table-per-device, combine with the table-sharding strategy in [Sharding](en/enterprise/sqltoy_sharding.md) to route each device to its own child table (the framework groups by table name and batch-writes).

**Mode B (time-series idiomatic): sql xml named parameters for "auto-create child table + tags"**

TDengine's most idiomatic write is `insert into child using stable tags(...) values(...)`, which auto-creates the child table if absent. SqlToy expresses this with sql xml named parameters — **no extra development needed**:

```xml
<sql id="device_insert">
    insert into :tb using meters tags(:location, :groupId)
    values(:ts, :current, :voltage, :phase)
</sql>
```

```java
// Single row: executeSql
dao.executeSql("device_insert",
    MapKit.keys("tb", "location", "groupId", "ts", "current", "voltage", "phase")
          .values("d1001", "California", 1, ts, 10.2f, 219, 0.31f));

// Batch: batchUpdate — each row may carry a different :tb; one PreparedStatement
// writes across many child tables and auto-creates them
List<Map<String, Object>> rows = ...; // each Map has tb/location/groupId/ts/current/...
dao.batchUpdate("device_insert", rows);
```

**How it works (verified)**: `:tb` is converted by SqlToy's named-parameter processing into a `?` placeholder, yielding `insert into ? using meters tags(?,?) values(?,?,?,?)`. The TDengine JDBC driver binds the `?` in the table-name position correctly as an identifier (not a quoted string) on the client side, while the TAGS and VALUES `?` bind normally. With `addBatch`, each row can set a different child-table name, so **a single statement batch-writes and auto-creates multiple child tables**.

## III. Constraints

1. **The timestamp primary key is assigned by the application (ASSIGN strategy)**: TDengine's official INSERT documentation states — "Every inserted row **must contain a timestamp, and the timestamp cannot be `NULL`**" and "The timestamp primary key **must appear** and cannot be omitted". TDengine has no auto-increment columns and no sequences; `getGeneratedKeys` is unsupported (verified: `this operation is NOT supported`). So the primary key must use the **ASSIGN** strategy and be set by the application — never configure `identity` / `sequence`.
   - **About `NOW`**: the official docs state "`NOW` is resolved to the **client time** of the SQL statement, not server time". So `new Timestamp(System.currentTimeMillis())` in the application and writing `NOW` in SQL are **functionally equivalent** (both use the client clock) — there is no such thing as "server-side timestamp auto-generation" (TDengine does not even support `current_timestamp`). However, application assignment is **better**: the application knows the value it set, so `save()` returns the primary key correctly; whereas a `NOW`-generated timestamp is **not returned**, leaving the entity unaware of its own primary key.
   - **Semantic advice**: in IoT scenarios the timestamp should be the **event time** (when the sample was taken), known by the device/application; `NOW` is merely "the client moment when the statement is written", which is wrong under device clock drift or when back-filling historical data.
2. **Guard the child-table name against injection**: in Mode B, `:tb` is inlined into the SQL text by the driver, so **always validate/whitelist the child-table name in the service layer** to prevent SQL injection.
3. **Do not map writes directly to a super table**: `insert into stable ... values(...)` is rejected by the engine (`tbname column should not be null`). Writes must target a child table (Mode B's `using ... tags` auto-creates it).
4. **Use Mode B for batch writes**: `saveAll` writes to a single existing child table only; for multi-device ingestion use Mode B's `batchUpdate` (different `:tb` per row), or route via a sharding strategy.
5. **"Update" = re-INSERT with the same timestamp**: TDengine has no `UPDATE` statement. Official rules — "A table keeps one row for each primary key; the timestamp alone identifies the row" and "rows sharing one timestamp overwrite each other". So the only way to modify a record is to **re-insert with the same timestamp**; in 3.x this is a **column-level merge** (only the columns present in the INSERT are overwritten, the others keep their original values — verified). This is why ORM writes like `update` / `saveOrUpdate` do not apply to TDengine (see next section); to "change a value", re-insert by this mechanism.

## IV. Unsupported Operations & Alternatives

The following operations are unavailable due to TDengine's engine semantics (the framework throws `UnsupportedOperationException`). The reason and alternative for each:

| Operation | Engine reason | Alternative |
| --- | --- | --- |
| `update` / `updateAll` | No `UPDATE ... SET` statement (append-only model) | **Re-INSERT with the same timestamp** to overwrite; in 3.x this is a column-level merge (only columns present in the INSERT are overwritten, others keep their values) |
| `saveOrUpdate` / `saveOrUpdateAll` | No UPSERT semantics | Same as above — re-insert with the same timestamp overwrites |
| `saveAllIgnoreExist` | No `INSERT IGNORE` / `ON CONFLICT` | A duplicate timestamp is itself an overwrite, so "ignore" is unnecessary |
| Row locks (`LockMode` / `for update`) | No row-level locks (`SELECT ... FOR UPDATE` is a syntax error) | **Do not pass a `LockMode`** when querying (6.0.9 would append `for update` and cause a syntax error); time-series reads need no locking |
| `updateFetch` | No UPDATE and no row locks | Not applicable |
| `executeStore` (stored procedure) | No stored procedures | Use TDengine stream computing or application-layer logic |
| `delete` / `deleteAll` (ORM by PK) | ORM delete-by-PK is not enabled | Use the database-level **`KEEP`** retention policy for expiry; or hand-write `DELETE` in sql xml (mainly by time range) |
| `isUnique` | No relational unique-constraint validation semantics | The timestamp primary key is inherently unique; a duplicate timestamp is an overwrite |

## V. Function & Dialect Notes

- TDengine has **no** `coalesce` / `nvl` / `ifnull` / `date_format` functions (verified: `Func not exists`). Cross-database function auto-replacement (`functionConverts=default`) has **no target** for these and leaves them as-is — keep this in mind when writing cross-DB SQL;
- For date formatting use TDengine's `to_char(ts, 'YYYY-MM-DD HH24:MI:SS')` (**Oracle-style format specifiers**, supported since 3.2.1.0); for string-to-timestamp use `to_timestamp`;
- Reserved-word identifiers use backticks (same as the MySQL family), handled automatically by the framework;
- To provide TDengine-specific SQL, use the `sqlId_tdengine` dialect variant (see [Dialect Auto-Adaptation & Function Extension](en/dialect/sqltoy_function.md)).

## VI. Related

- Supported databases overview: [Supported Databases](en/introduction/db_list.md)
- Cross-DB adaptation & multi-DB verification: [Multi-DB Verification](en/dialect/multi_db_verify.md)
- Sharding strategy (one-child-table-per-device routing): [Sharding](en/enterprise/sqltoy_sharding.md)
