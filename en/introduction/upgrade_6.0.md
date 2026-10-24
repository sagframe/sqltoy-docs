# Upgrade to 6.0.x

Changes and notes for upgrading from 5.6.x to 6.0.9 (the 6.0 line). All changes have been verified against the 6.0 source code.

## 1. Environment Requirements

| Item | Requirement |
| --- | --- |
| JDK | **17+** (targeting Spring Boot 3/4); JDK 8 projects should use `5.6.96.jre8` (the final jre8 version, also works with the quickvo-maven-plugin) |
| Dependency coordinates | Unchanged: `com.sagframe:sagacity-sqltoy` (plus spring / spring-starter / solon-plugin); only the version number is upgraded to 6.0.9 |
| Configuration parameters | Two parameters are added on top of the 58 `spring.sqltoy.*` parameters of 6.0.2: `realDialectFirst` (new in 6.0.3) and `ddlLowerOrUpper` (exposed as a starter property since 6.0.3); all other parameters are unchanged (parameters added in later versions are covered in their respective sections below and are all optional), and existing configuration files need no adjustment |

## 2. API Changes (Code Changes Required)

| Change | 5.6.x | 6.0.x |
| --- | --- | --- |
| Parallel query | `lightDao.parallQuery(List<ParallQuery>, ...)` | `lightDao.parallelQuery(List<ParallelQuery>, ...)` (the model class is renamed accordingly: `ParallQuery` → `ParallelQuery`) |
| Connection callback | `doConnection(Connection conn, Integer dbType, String dialect)` | `doConnection(Connection conn, DBProfile profile)` — `DBProfile` provides the complete database execution profile |

`DBProfile` (`org.sagacity.sqltoy.model.DBProfile`) provides `getDbType()` / `getDialect()` / `getUrl()` / `getProductName()` / `getMajorVersion()`, plus convenience checks such as `isMysqlFamily()` / `isOracleFamily()` / `isOceanBase()` / `isBackslashEscape()`; see [Other Features](en/tools/other_features.md) for details.

> The other frequently used APIs (the remaining 71 LightDao method names — 109 declarations in total — the Link chain API, QueryExecutor/EntityQuery/EntityUpdate, and the existing configuration parameters) are **all unchanged**; the upgrade cost is concentrated in the two items above.

## 3. Package Structure Changes (Adjust imports If You Reference Framework Internal Classes)

| Class | 5.6.x Location | 6.0.x Location |
| --- | --- | --- |
| `PageOptimizeUtils` | `dialect.utils` | `dialect` |
| `ParallelUtils` | `utils` | `dialect.executor` |
| `QueryExecutorBuilder` | `utils` | `dialect` |
| `CrossDbAdapter` | `plugins` | `dialect` |
| `MacroIfLogic` | `utils` | `config` |
| `ParamFilterUtils` | `utils` | `config` (renamed to `ParamFilterProcessor`) |
| `TranslateUtils` | `utils` | `translate` |
| `HttpClientUtils` | `utils` | `plugins.nosql` |
| `MongoElasticUtils` | `utils` | `plugins.nosql` (renamed to `MongoElasticOperations`) |
| `SavePKStrategy` | `dialect.model` | `model` |

## 4. New Capabilities

- **SAP HANA dialect**: the total number of dialects reaches 24; see [Supported Databases](en/introduction/db_list.md);
- Internal model enhancements: `ExecuteParams`, `ResultColumnMeta`, etc. (used internally by the framework; no impact on existing APIs).

> For more complete version evolution details, refer to `sqltoy-orm-core/changelog.md` in the source repository.

## 5. What's New in 6.0.3

6.0.3 builds on 6.0.2 with additional capabilities — all incremental, requiring **no changes to existing code**:

**SQL dialect system**

- The `<sql>` element gains a `dialect` attribute: it declares that the sql is parsed and solidified in the specified dialect form — at load time function/reserved-word conversion is done once against that dialect; at execution time, if the current database dialect matches the declaration, conversion is skipped, otherwise lazy conversion adapts it (`mql`/`eql` do not support it). See [Dialect Self-Adaption & Function Extension](en/dialect/sqltoy_function.md);
- New `spring.sqltoy.realDialectFirst` configuration (default `false`): when enabled, sqlId dialect variant lookup first follows the **real dialect detected from the connection** (`DBProfile.realDialect` — typical cases: OceanBase configured with the mysql dialect, proxied databases); if the real-dialect variant does not exist, the original configured-dialect lookup chain is used as fallback.

**POJO-to-DDL generation (see [POJO-to-DDL](en/primarykey/sqltoy_ddl.md))**

- New `@Partition` / `@PartitionDef` / `@MppTable` entity annotations: describe table partitioning strategies and MPP analytical-database (ClickHouse/Doris/StarRocks) table-engine metadata; quickvo generates them automatically from the database partition/table definitions;
- `PARTITION BY` clauses (RANGE/LIST/HASH/RANGE COLUMNS/LIST COLUMNS, with partition details) are now rendered automatically in create-table statements;
- Dedicated DDL generators added for Doris, StarRocks, ClickHouse, DB2, HANA and SQLite (previously Doris/StarRocks reused the MySQL generator and the rest fell through to the default generator);
- `@Foreign`'s `deleteRestict`/`updateRestict` now support the full set of referential actions (`ReferentialAction`: CASCADE/RESTRICT/SET_NULL/NO_ACTION/SET_DEFAULT), trimmed automatically per database compatibility;
- JSON column types degrade gracefully per database (HANA→NCLOB, SQL Server→NVARCHAR(MAX), DB2/Oracle11→CLOB).

**Fixes and optimizations**

- Sharded parallel execution: `ShardingResult` gains a `cause` field preserving the original exception, and the exception thrown on global rollback carries the root-cause stack; `@Sharding.maxConcurrents` semantics fixed (0 = unlimited, 1 = serial);
- `executeSql`/`batchUpdateByJdbc` now force a rollback when a manual commit fails, and `autoCommit` restoration moved into `finally`, preventing connections from being returned to the pool with a rewritten commit mode after an error;
- Result mapping: numeric strings with thousands separators produced by `number-format` (e.g. `8,888.0000`) have the grouping commas stripped automatically when mapped back to numeric properties;
- SqlServer pagination: the WITH section is now stripped and placed first, and the union derived-table wrapping order is fixed.

## 6. What's New in 6.0.4

6.0.4 builds on 6.0.3 with further enhancements — likewise **incremental, requiring no changes to existing code**:

**Cache translate REST authentication enhancement (see [Cache Translate](en/quickstart/translates.md))**

- `rest-translate` / `rest-checker` / `rest-increment-checker` gain the `auth-type` authentication mode: `basic` (default, backward-compatible with the existing `username`/`password`) and `jwt`;
- For jwt, the token is obtained in one of three ways (priority order applies when multiple are configured): `token-url` login endpoint that posts username/password as a form and extracts the token from the JSON response via `token-path` (dot paths like `data.token` supported), then caches it; `token-secure-key` local self-signed jwt (HS256/384/512 shared secrets and RS256/384/512 PKCS#8 private keys, no login endpoint needed); or `authorization` with a directly configured long-lived static token;
- Companion attributes: `token-header` (default `Authorization`), `token-prefix` (default `Bearer`, set to `none` to send the bare token), `token-expire` (default 1800 seconds; when the response contains `expires_in` the response value wins). Tokens are cached and reused, refreshed proactively when close to expiry, and on a 401 the token is invalidated and re-login (or re-signing) plus one retry happens automatically.

**Cross-database function adaptation improvements (see [Dialect Self-Adaption & Function Extension](en/dialect/sqltoy_function.md))**

- New source-function recognition: `nvl2(a,b,c)` (non-oracle databases convert to a case-when null-check), single-argument `isnull(x)` (mysql returns 0/1 semantics), `sys_timestamp` (passthrough on oracle-family, fractional-second precision kept on mysql-family, sysdatetime on sqlserver), `strpos(str,sub)` (passthrough on pg-family/clickhouse, converted to instr elsewhere), `substr(s,-n)` with a negative start, and the `curdate()`/`CURRENT_DATE` function class (oracle-family converts to `TRUNC(CURRENT_DATE)`, db2 uses the CURRENT DATE keyword form, sqlite uses the local clock);
- `group_concat`/`listagg`/`string_agg` now support the trailing `within group (order by ...)` clause, an order by embedded in the arguments, and DISTINCT prefix recognition;
- `datediff(month,...)` is unified to the year/month component difference (no longer registered with the oracle MONTHS_BETWEEN decimal semantics); `to_char` conversion to sqlserver is now based on FORMAT, fixing wrong output for uppercase format tokens (e.g. `YYYY-MM-DD HH24:MI:SS`); on sqlite targets `now()`/`CURRENT_DATE`/`CURRENT_TIMESTAMP` uniformly use the local clock.

**Fixes**

- Fixed silent wrong results of `SubStr` with a negative start that deviated from the mysql contract (pg-family/sqlserver/h2/db2/hana: when the computed start is less than 1 an empty string is now returned uniformly);
- Fixed standalone HH hour tokens in minute-less formats (e.g. `yyyy-MM-dd HH`) being interpreted as 12-hour clock on pg/oracle-family targets, which skewed hour-bucket boundaries.

**Companion tooling**

- The companion quickvo-maven-plugin is upgraded to **2.0.2**.

## 7. What's New in 6.0.5

6.0.5 builds on 6.0.4 with further enhancements — likewise **incremental, requiring no changes to existing code**:

**New database support (dialect total 24 → 25; see [Supported Databases](en/introduction/db_list.md))**

- **HighGo**: PG12 kernel + Oracle compatibility layer; the SQL-generation layer reuses the PostgreSQL family (`HighgoDialect extends PostgreSqlDialect`), with differences concentrated on the function side (no `uuid()`/`gen_random_uuid()` but has `sys_guid()`; `last_day`/`add_months`/`trunc` native; no `listagg` but `string_agg` native), carried by the HIGHGO branch of the function adapters; supports both the official driver URL `jdbc:highgo://` and the vanilla pg driver (distinguished via `version()` kernel probing).

**Cross-database function adaptation improvements (see [Dialect Self-Adaption & Function Extension](en/dialect/sqltoy_function.md))**

- 11 new function classes (all registered into default): `find_in_set`, `uuid` (unique-id generation), `year/month/day` component extraction, `last_day/eomonth`, `add_months`, `date_add/date_sub/dateadd` interval arithmetic, `left/right`, `lpad/rpad`, `extract/date_part`, `trunc/date_trunc` date truncation, and `mod`;
- Source-spelling expansion for existing functions: `instr` adds `locate/posstr`, `length` adds `character_length/octet_length`, `now` adds `current_timestamp`, `if` adds `iif`, `substr` adds `mid`, `to_date` adds `str_to_date`;
- All verified by real-database probing across multiple databases; forms that cannot be converted safely are kept "loud" (passed through for the target database to error on), avoiding silent wrong values.

**Lowercase primary-key insert return (PostgreSQL family)**

- The case conversion of the primary-key column name when returning the key value on single-row inserts (`getReturnPrimaryKeyColumnCase`) is expanded from PostgreSQL/PostgreSQL14 only to the entire **PG-folding family**: OpenGauss, GaussDB, MogDB, Vastbase, StarDB, Oscar, Kingbase and HighGo are now lowercased as well. Reason: `getGeneratedKeys` column hints are case-sensitive on PG-folding kernels (e.g. opengauss/vastbase/highgo report "column does not exist" for "ID"/"Id", and kingbase errors on mixed case), so lowercasing is safe for the whole family; the mysql family/tidb/oceanbase/sqlserver/db2/dm/oracle keep DEFAULT (the driver ignores the hint or folds consistently). This can still be overridden per dialect via the `dialectReturnPrimaryColumnCase` configuration.

**Other optimizations and fixes**

- Fixed bare functions at the very start of a string never being converted (when the whole sql is a function expression, the adaptation regex `\W(funcName)\(` never matches; a space sentinel is added at the entry);
- Completed TO_DATE/TO_TIMESTAMP cast-family handling for HIGHGO/H2/SQLITE.

## 8. What's New in 6.0.6

6.0.6 builds on 6.0.5 with further enhancements — likewise **incremental, requiring no changes to existing code**:

**Virtual-table macro @virtualTable() (see [Dialect Self-Adaption & Function Extension](en/dialect/sqltoy_function.md))**

- Solves the cross-database dilemma of "select constant-row union real-query" SQL (dictionary dropdown fallback rows, fixed report total rows, etc.): oracle/db2/hana require a pseudo-table (`from dual` / `from sysibm.sysdummy1` / `from dummy`), while mysql/pg/sqlserver etc. natively support FROM-less select (writing `from dual` actually errors there);
- Unified form: `select '0' id,'Global' name @virtualTable() union select id,name from t` — expanded per dialect at SQL parse time: oracle family (oracle/oracle11/dm/oceanbase) → `from dual`, db2 → `from sysibm.sysdummy1`, hana → `from dummy`, stripped elsewhere;
- Compatible aliases `@dual()` / `@dummyTable()` — all three names are equivalent, case-insensitive, tolerant of spaces inside the parentheses; may appear multiple times in one SQL (one per constant select);
- Works in xml-configured SQL, `@Sql` annotation SQL and code SQL (`findBySql` etc.) alike (unified parse pipeline); SQL without the macro is completely unaffected (plain SQL containing `@` such as emails is not touched);
- Expansion happens at parse time and is solidified with SqlToyConfig (same timing as function/reserved-word conversion), zero runtime overhead; with `realDialectFirst` the macro is expanded by the parse dialect — the runtime lazy layer does not re-expand it.

**Companion tooling**

- The companion quickvo-maven-plugin is upgraded to **2.0.3**.

## 9. What's New in 6.0.7

6.0.7 builds on 6.0.6 with further enhancements — likewise **incremental, requiring no changes to existing code**:

**Pluggable JSON library (JsonProvider SPI)**

- sqltoy is no longer hard-bound to fastjson2: JSON/JSONB column mapping, the rest/service paths of cache translation, and the whole Elasticsearch stack (including jwt authentication) now delegate to `org.sagacity.sqltoy.plugins.json.JsonProvider`, with three built-in implementations — fastjson2, jackson3 (`tools.jackson`) and jackson2 (`com.fasterxml`);
- Resolution order: an explicit `spring.sqltoy.jsonProvider` wins, otherwise the classpath is probed in the order fastjson2 → jackson3 → jackson2. fastjson2 comes first so that projects whose JSON columns already worked keep behaving exactly as before;
- The configuration value accepts a built-in alias — `fastjson2` / `jackson3` / `jackson2` (case, hyphens and surrounding whitespace insensitive) — or the fully qualified class name of a custom implementation;
- A probed candidate must pass a smoke parse before it is accepted: being on the classpath is not the same as being usable (for instance jackson3's databind needs `jackson-annotations` 2.20+, and when jackson2 is also present an older annotations version can win the conflict resolution and cause `NoSuchFieldError: POJO`). An unusable candidate is logged as a warning and the next one is tried; a missing marker class is skipped silently;
- Initialization is attempted at startup: an illegal or unusable explicit configuration **fails immediately and preserves the root cause** (it does not silently fall back, which would make the configuration meaningless); when no usable JSON library is present it only logs a warning and does not block startup — **projects that use neither JSON columns nor Elasticsearch now need no JSON library at all**, and a clear guided exception is thrown only when a JSON feature is actually touched, replacing the former `NoClassDefFoundError`;
- The jackson2 / jackson3 dependencies in core are both `provided + optional` and are not transitive;
- See [Configuration](en/config/sqltoy_config.md) and [Elasticsearch](en/nosql/sqltoy_elasticsearch.md).

**Field-list joining macro @joinFields() (see [Tags & Expressions](en/appendix/tags.md))**

- For page-configurable reports and API services where the configuration decides the `select` / `group by` / `order by` columns. Written as `@joinFields(:fields,default)`, or directly in positional form `@joinFields(?,default)` — it is processed at the same stage as `@value`, so once named parameters have become `?` the two forms are exactly equivalent; the consumed parameter is removed from the parameter set, leaving the remaining `?` placeholders aligned;
- When `fields` is null, empty or all-blank, `default` is emitted. `default` comes from the SQL text (author-written, trusted) and is emitted verbatim without identifier validation, so it may be `t.*` or `sum(t.amount)`; wrap it with `{}`, `''` or `""` when it contains commas or parentheses. Without a `default` the result is an empty string;
- Input normalization: a single string or a 1-element array is split on commas (page multi-selects often serialize to `["a,b,c"]`); with more than one element the elements are the fields and no further splitting occurs, so `["a,b","c"]` fails on `"a,b"` instead of being silently split into three fields; blank fragments are skipped to tolerate trailing commas;
- Security: field names go through a character whitelist (letters including Chinese, digits, underscore, at most two dots for `schema.table.column`). `$` and `#` are explicitly excluded (they collide with the `#[]` dynamic segments and the `${}`/`#{}` placeholders), as are whitespace, quotes, brackets, parentheses, semicolons, commas, comment markers and backslashes. An illegal value throws immediately and names the offending value — it is never silently sanitized (the DAO layer wraps it into a `DataAccessException`, so inspect the root cause when catching);
- Legal fields are quoted per dialect **only when reserved words** (backticks for the mysql family, double quotes for oracle/pg, square brackets for sqlserver); non-reserved identifiers stay bare, avoiding the case sensitivity that quoting introduces on oracle/pg. Dotted names are handled segment by segment, so the column part of `t.order` is quoted too;
- **Prerequisite**: reserved-word quoting depends on the `spring.sqltoy.reservedWords` configuration, which has **no default**. Without it the reserved-word set is empty and `convertWord` returns names unchanged, so a field list containing a reserved word (`order`/`desc`/`level`/`group` ...) produces a bare identifier that the database rejects — verified to raise a syntax error on PostgreSQL, MySQL 9 and SQL Server 2025;
- Plain identifiers only: expressions such as `sum(col)` or `col as alias` still belong to `@value` (safety then on you); operator forms (`a % b`, `a || b`) are not function calls and are likewise out of scope;
- Verified end to end against three real databases — PostgreSQL, MySQL 9 and SQL Server 2025 (plain columns, default fallback, group-by aggregation, reserved-word columns, injection rejection).

**Dangling and/or connectors inside brackets are cleaned up after `#[]` removal**

- For a construct like `#[and ( #[t.a=:a] #[or t.b=:b] )]`, when `a` is null the previous behaviour expanded to the broken `and ( or t.b=:b )`; after removal, a trimmed leading/trailing `and`/`or` inside brackets is now cleaned up, so each member of a bracket group is independently optional (`and|or` only matches when followed by `\s+` or `)`, so keywords such as `( order by ...)` that start with `or` are left alone). See [Dynamic SQL Guide](en/query/dynamic_sql.md).

## 10. What's New in 6.0.8

6.0.8 is the **heaviest release in the 6.0 line**: the lambda condition API moved into core and the GraalVM AOT support was rewritten. **Projects running on the JVM need no code changes**; projects using sqltoy-plus should follow item 2; projects building native images should check their build environment against item 4.

**1. The lambda condition API is now part of core (see [Lambda Conditions](en/query/lambda_query.md))**

- New package `org.sagacity.sqltoy.lambda`: `LambdaQuery` / `LambdaUpdate` / `LambdaDelete` plus `JoinCol` / `ExcludeCols` / `LambdaFn` / `OuterRef`, expressing conditions through entity property method references (`User::getStatus`);
- `LightDao` gains three default factories `lambdaQuery/lambdaUpdate/lambdaDelete(Class)`; execution is driven by the builder terminals (`find/getOne/findPage/count/exists/update/delete`), or build first and execute later with `LambdaQuery.create(entityClass).bind(lightDao)`;
- **A single-table query is just the degenerate form of a join**: without a join step the single-table channel converts conditions into `EntityQuery`/`EntityUpdate` and reuses `findEntity`/`findPageEntity`/`getCount`/`deleteByQuery`/`updateByQuery`, so sharding / cache translate / encryption-masking / tenant filtering are all inherited; calling `leftJoin/rightJoin/innerJoin` + `on` switches to the join channel, which assembles full SQL and goes through `find`/`findPage`/`getCount`, supporting `select/selectAll(ExcludeCols...)/JoinCol.of|avg|count|sum|min|max|distinct().as()` as well as CTE / `@fast` pushdown / UNION;
- Behavioural differences to watch: `getOne()` now has **strict semantics** — 0 rows returns null, more than 1 row throws `DataAccessException` (it no longer silently takes the first row); a conditional `update/delete` with no where clause throws by default and requires an explicit `matchAll()`;
- Condition parameters are renamed from sqltoy-plus's `type.valuePairs.MPG1` form to `:p1…:pN`, unique across the whole builder and shared across nesting — **unit tests that assert SQL text must be updated**; external parameters of `having`/`inSql` should avoid the `p` + pure-digit form;
- Value filtering changes from sqltoy-plus's global static strategy to a **builder-instance** `valueFilter(...)` (nulls are filtered by default; set it before adding conditions);
- `LambdaUpdate.setExpr(field, expression[, value])` supports expression updates based on the field's current value (e.g. `setExpr(User::getLoginCount, "loginCount + 1")`), reusing the existing "field = expression" form of `updateByQuery`.

**2. Migration checklist for sqltoy-plus users**

| Migration point | Action |
| --- | --- |
| Dependency | Remove the `sqltoy-plus` dependency (the capability is in core); `@EnableSqlToyPlus` and the mapping-strategy beans are no longer needed |
| Imports | `com.sagframe.sagacity.sqltoy.plus.*` → `org.sagacity.sqltoy.lambda.*` |
| Class names | `LambdaQueryWrapper`/`LambdaUpdateWrapper` → `LambdaQuery`/`LambdaUpdate`; `LambdaColumn` → `JoinCol`; `SFunction` → `LambdaFn`; `FiledNature` → `record FieldNature(entityClass, fieldName)` |
| DAO | `SqlToyPlusDao.findList/findOne/findPage/count/exists/delete/update(wrapper)` → builder terminals; `SqlToyHelperDao` has been deleted |
| Entry points | `Wrappers.lambdaQuery(cls)` → `LambdaQuery.create(cls)` or `lightDao.lambdaQuery(cls)`; `lambdaQueryChain/lambdaUpdateChain` → `lightDao.lambdaQuery/lambdaUpdate` |
| Multi-table | `Wrappers.lambdaMultiWrapper(toClass).select(...).from(...)` → `lightDao.lambdaQuery(toClass)[.select(JoinCol...)].from(...).leftJoin(...).on(...)`; `lambdaUpdateMultiWrapper/lambdaDeleteMultiWrapper` → `lightDao.lambdaUpdate/lambdaDelete` plus join steps |
| Parameter names | `type.valuePairs.MPG1` → `:p1…` |
| String wrappers | `QueryWrapper` and friends are no longer provided: use `EntityQuery` for single-table string conditions and SQL mode for complex dynamic SQL |

> For the full field-by-field table see [Lambda Conditions · 9. Migrating from sqltoy-plus](en/query/lambda_query.md).

**3. Multi-table join update and delete**

Join updates and deletes are folded into `lambdaUpdate()/lambdaDelete()` (the same "no join means single table" rule as for queries): a join update generates `UPDATE main alias JOIN ... SET alias.column=:p WHERE ...`, a join delete generates `DELETE alias[,...] FROM main alias JOIN ... WHERE ...` (`deleteTables` defaults to the main table), and both run through `executeSql`. Relational databases use a portable EXISTS-over-derived rewrite, verified on real mysql/postgresql/sqlserver/oracle/db2 databases; clickhouse/doris/starrocks and other databases without transactional row-level DML do not support it. **Merging a whole entity into an update is not supported on the join channel** — use `lightDao.update(entity)`.

**4. GraalVM native / AOT rewritten (see [GraalVM Native Image Guide](en/tools/graalvm_native.md))**

- Fixed the defect, present since 5.6, that **AOT entity reflection hints were always empty**: during AOT Spring registers no `BeanPostProcessor` and pre-instantiates no singletons, so the `SqlToyContextProperties` obtained from `getBean` was an unbound empty instance and every entity hint was lost. The processor now binds `spring.sqltoy` straight from the `Environment` through `Binder` and scans entities with `EntityScanner` according to `packagesToScan`/`annotatedClasses`. **`packagesToScan` is mandatory in native scenarios**;
- Registers **dynamically from the configuration**: resource patterns (`sqlResourcesDir` with multiple directories / `sqlResources` / `translateConfig` / key files), reflection for 15 extension points (`unifyFieldsHandler`, `typeHandler`, `sqlInterceptors`, `sqlFormater`, `translateCacheManager`, `dataSourceSelector`, `connectionFactory`, `fieldsSecureProvider`, `desensitizeProvider`, `customFilterHandler`, `overTimeSqlHandler`, `dialectDDLGenerator`, `firstBizCodeTrace`, `dynamicCacheFetch`, `dynamicFecthCacheManager`), the `functionConverts` function classes resolved by `FunctionUtils.resolveFunctionClassNames`, lambda's `SerializedLambda`/mirror-class serialization, and the 8 model classes populated reflectively by XML parsing (without them `<unpivot>`/chain-relative/`<tree-sort>` tag attributes are **silently dropped**);
- Registers **conditionally on the classpath** (a native image is frozen at build time, so nothing can be switched at runtime): the caffeine/ehcache manager for `cacheType`, the mongo/redis integration classes, the three JSON providers, the five driver-isomorphic `PGobject` classes for the PG family (postgresql/opengauss/vastbase/gaussdb/kingbase), mssql `Geometry`/`Vector`, and `oracle.jdbc.OracleTypes`;
- New settings `native-reflection-classes` / `native-reflection-packages` (for non-entity DTO/VOs) and `native-entity-proxies` (pre-generates `updateSaveFetch` proxies at build time; the application must add `net.bytebuddy:byte-buddy`);
- The four `@Bean`s `sqlToyLazyDao`/`sqlToyDao`/`lightDao`/`sqlToyCRUDService` in the starter changed their return types from interfaces to **concrete implementation classes**, with an explicit `@ConditionalOnMissingBean(interface.class)`: Spring AOT infers bean types from the declared type, and an interface declaration prevents the transactional CGLIB proxy from being pre-generated at build time, which fails at native runtime with "CGLIB runtime enhancement not supported on native image". Application-side `@Bean`s declared with an interface return type plus `initMethod` should likewise be switched to concrete types;
- **The build environment requires GraalVM 25+** (verified matrix: 17 and 23 do not understand the new reachability-metadata schema — native-maven-plugin rejects them outright; 21 does not support `typeReached` conditional metadata, so spring-aop's AspectJ serialization entries get registered wrongly; 25.0.4 verified with the full matrix on both stacks);
- Known limitation: the `EntityUpdateCallback` path of `updateSaveFetch` relies on byte-buddy generating entity subclasses at runtime; under native it needs `native-entity-proxies` to pre-generate the proxy, and entities not listed there remain unavailable (the insert branch is unaffected).

**5. Companion verification project**

Added [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify) (one matrix shared by the spring and solon stacks, PostgreSQL pgvector + postgis): it covers CRUD × json/vector/geometry in three shapes, `functionConverts` dialect conversion, cache translate on ehcache and caffeine, the `updateSaveFetch` proxy path, and lambda single-table/join/setExpr/matchAll-guard/delete; the JVM matrix is 17/17 PASS on both stacks and, with `native-entity-proxies` configured, the native smoke run is 17 PASS + 0 KNOWN-LIMITATION.

## 11. What's New in 6.0.9

6.0.9 is mostly a batch of cross-database empirically verified fixes with no breaking changes — upgrading only requires the version bump.

**1. CTE materialization hint kept/stripped by target database**

`WITH xx AS [NOT] MATERIALIZED (..)` is only natively supported by the PostgreSQL family (including openGauss, Kingbase, Vastbase, GAUSSDB and HighGo); on other databases (mysql, sqlserver, oracle, db2, ...) the framework strips the hint at parse time — only the materialization optimization is lost, the query semantics are unchanged, so you no longer need one sqlId per dialect. The rendering gate of `.with(name, q, Boolean.TRUE/FALSE)` on the lambda side shares the same source (see [Lambda Queries and Updates](en/query/lambda_query.md)).

**2. Function adaptation fixes verified on real databases**

- The bare `HH` token of `to_char`/`to_date`/`str_to_date` is unified to the **24-hour** convention across databases (lowercase `hh` is 12-hour, `HH24` is always 24) — on DB2 and H2 it previously rendered as 12 hours, silently corrupting values (verified on real databases);
- When `to_date` targets the pg family / HANA / ClickHouse and the format contains time tokens, it is rewritten to `to_timestamp`/`toDateTime` to avoid the time part being silently truncated (pg's `to_date` only returns a date, verified on a real database);
- `trim(from x)` (the form omitting the trim character) raises error 1064 on mysql 9.3 and ORA-30000 on oracle 23ai; it is now rewritten to the equivalent `trim(x)`/`ltrim`/`rtrim`;
- `substr` start position 0 is unified as "from the beginning"; `mid` targeting sqlite is converted to `substr` (sqlite has no native `mid`); mysql's `left/right(str,0)` and negative lengths align on "return an empty string";
- `instr` supports the four-argument form `instr(str,sub,pos,occurrence)`;
- `find_in_set` comparisons extend to any position convention: `=1/=2/>1/<3` are rewritten as integer-position expressions (the existing `>0/=0` boolean family is unchanged);
- `datediff` for oceanbase joins the oracle branch (OB oracle-mode tenants have no datediff; mysql mode uses `dialect=mysql` by convention).

**3. Pagination count cache isolated per dialect**

The pageOptimize total-count cache key is upgraded from sqlId to `sqlId@dialect`: when the same sql runs on different dialect databases via `redoDataSources`/multiple datasources, the count results are cached separately instead of cross-contaminating; `PageOptimizeUtils.remove(sqlId)` also clears all dialect caches of that sql. The accompanying fix prevents the cross-db adapter from rewriting the shared `SqlToyConfig` instance when a custom countSql is present, which polluted subsequent queries of the same sqlId.

**4. Lambda condition refinements**

- Added `likeExact/likeExactLeft/likeExactRight`: `%` inside the value is first escaped as a literal and then padded by direction — user input containing `%` matches as an ordinary character instead of being treated as a wildcard that widens matches (`like/likeLeft/likeRight` semantics unchanged);
- `setExpr` fails fast when a quoted literal `?` appears inside the expression (the update channel replaces `?` textually, so a quoted `?` would be mistaken for a parameter slot);
- Empty groupBy columns and empty having conditions are skipped during assembly (previously illegal `GROUP BY `/`HAVING ` fragments could be produced).

**5. Others**

- SqlScriptLoader initialization/destruction thread-safety hardening (flags made volatile, methods synchronized).

## 12. Recommended Upgrade Steps

1. Upgrade the dependency version numbers uniformly to 6.0.9 (starter / spring / solon-plugin use the same version as core);
2. Search globally for `parallQuery` / `ParallQuery` and change them to `parallelQuery` / `ParallelQuery` (an IDE rename is enough);
3. If you have custom `DataSourceCallbackHandler` implementations, adjust the `doConnection` signature to take a `DBProfile` parameter;
4. If you reference the framework internal utility classes listed in the table above, adjust the imports to their new package locations;
5. **Projects using sqltoy-plus**: migrate to `org.sagacity.sqltoy.lambda` following the checklist in section 10.2, remove the sqltoy-plus dependency and `@EnableSqlToyPlus`, and regression-test the two behaviour changes (`getOne()` with multiple matches, unconditional update/delete);
6. **Projects building native images**: confirm GraalVM 25+, configure `packagesToScan`, register `native-reflection-classes/packages` as needed, and add entities that use `updateSaveFetch` to `native-entity-proxies`; on GitHub Actions set `distribution: graalvm` in `actions/setup-java` (`graalvm-community` was removed by setup-java v4, see the [GraalVM Native Image guide](tools/graalvm_native.md));
7. Startup verification: watch the SQL output in debug mode and run business regression tests (prioritize cache translate, pagination, parallel query and lambda conditions); unit tests that assert SQL text must be updated to the `:p1…` parameter names.
