# Upgrade to 6.0.x

Changes and notes for upgrading from 5.6.x to 6.0.5 (the 6.0 line). All changes have been verified against the 6.0 source code.

## 1. Environment Requirements

| Item | Requirement |
| --- | --- |
| JDK | **17+** (targeting Spring Boot 3/4); JDK 8 projects should use `5.6.96.jre8` (the final jre8 version, also works with the quickvo-maven-plugin) |
| Dependency coordinates | Unchanged: `com.sagframe:sagacity-sqltoy` (plus spring / spring-starter / solon-plugin); only the version number is upgraded to 6.0.4 |
| Configuration parameters | Two parameters are added on top of the 58 `spring.sqltoy.*` parameters of 6.0.2: `realDialectFirst` (new in 6.0.3) and `ddlLowerOrUpper` (exposed as a starter property since 6.0.3); all other parameters are unchanged, and existing configuration files need no adjustment |

## 2. API Changes (Code Changes Required)

| Change | 5.6.x | 6.0.x |
| --- | --- | --- |
| Parallel query | `lightDao.parallQuery(List<ParallQuery>, ...)` | `lightDao.parallelQuery(List<ParallelQuery>, ...)` (the model class is renamed accordingly: `ParallQuery` → `ParallelQuery`) |
| Connection callback | `doConnection(Connection conn, Integer dbType, String dialect)` | `doConnection(Connection conn, DBProfile profile)` — `DBProfile` provides the complete database execution profile |

`DBProfile` (`org.sagacity.sqltoy.model.DBProfile`) provides `getDbType()` / `getDialect()` / `getUrl()` / `getProductName()` / `getMajorVersion()`, plus convenience checks such as `isMysqlFamily()` / `isOracleFamily()` / `isOceanBase()` / `isBackslashEscape()`; see [Other Features](../tools/other_features.md) for details.

> The other frequently used APIs (the remaining 72 LightDao methods, the Link chain API, QueryExecutor/EntityQuery/EntityUpdate, and the existing configuration parameters) are **all unchanged**; the upgrade cost is concentrated in the two items above.

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

- **SAP HANA dialect**: the total number of dialects reaches 24; see [Supported Databases](db_list.md);
- Internal model enhancements: `ExecuteParams`, `ResultColumnMeta`, etc. (used internally by the framework; no impact on existing APIs).

> For more complete version evolution details, refer to `sqltoy-orm-core/changelog.md` in the source repository.

## 5. What's New in 6.0.3

6.0.3 builds on 6.0.2 with additional capabilities — all incremental, requiring **no changes to existing code**:

**SQL dialect system**

- The `<sql>` element gains a `dialect` attribute: it declares that the sql is parsed and solidified in the specified dialect form — at load time function/reserved-word conversion is done once against that dialect; at execution time, if the current database dialect matches the declaration, conversion is skipped, otherwise lazy conversion adapts it (`mql`/`eql` do not support it). See [Dialect Self-Adaption & Function Extension](../dialect/sqltoy_function.md);
- New `spring.sqltoy.realDialectFirst` configuration (default `false`): when enabled, sqlId dialect variant lookup first follows the **real dialect detected from the connection** (`DBProfile.realDialect` — typical cases: OceanBase configured with the mysql dialect, proxied databases); if the real-dialect variant does not exist, the original configured-dialect lookup chain is used as fallback.

**POJO-to-DDL generation (see [POJO-to-DDL](../primarykey/sqltoy_ddl.md))**

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

**Cache translate REST authentication enhancement (see [Cache Translate](../quickstart/translates.md))**

- `rest-translate` / `rest-checker` / `rest-increment-checker` gain the `auth-type` authentication mode: `basic` (default, backward-compatible with the existing `username`/`password`) and `jwt`;
- For jwt, the token is obtained in one of three ways (priority order applies when multiple are configured): `token-url` login endpoint that posts username/password as a form and extracts the token from the JSON response via `token-path` (dot paths like `data.token` supported), then caches it; `token-secure-key` local self-signed jwt (HS256/384/512 shared secrets and RS256/384/512 PKCS#8 private keys, no login endpoint needed); or `authorization` with a directly configured long-lived static token;
- Companion attributes: `token-header` (default `Authorization`), `token-prefix` (default `Bearer`, set to `none` to send the bare token), `token-expire` (default 1800 seconds; when the response contains `expires_in` the response value wins). Tokens are cached and reused, refreshed proactively when close to expiry, and on a 401 the token is invalidated and re-login (or re-signing) plus one retry happens automatically.

**Cross-database function adaptation improvements (see [Dialect Self-Adaption & Function Extension](../dialect/sqltoy_function.md))**

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

**New database support (dialect total 24 → 25; see [Supported Databases](db_list.md))**

- **HighGo**: PG12 kernel + Oracle compatibility layer; the SQL-generation layer reuses the PostgreSQL family (`HighgoDialect extends PostgreSqlDialect`), with differences concentrated on the function side (no `uuid()`/`gen_random_uuid()` but has `sys_guid()`; `last_day`/`add_months`/`trunc` native; no `listagg` but `string_agg` native), carried by the HIGHGO branch of the function adapters; supports both the official driver URL `jdbc:highgo://` and the vanilla pg driver (distinguished via `version()` kernel probing).

**Cross-database function adaptation improvements (see [Dialect Self-Adaption & Function Extension](../dialect/sqltoy_function.md))**

- 11 new function classes (all registered into default): `find_in_set`, `uuid` (unique-id generation), `year/month/day` component extraction, `last_day/eomonth`, `add_months`, `date_add/date_sub/dateadd` interval arithmetic, `left/right`, `lpad/rpad`, `extract/date_part`, `trunc/date_trunc` date truncation, and `mod`;
- Source-spelling expansion for existing functions: `instr` adds `locate/posstr`, `length` adds `character_length/octet_length`, `now` adds `current_timestamp`, `if` adds `iif`, `substr` adds `mid`, `to_date` adds `str_to_date`;
- All verified by real-database probing across multiple databases; forms that cannot be converted safely are kept "loud" (passed through for the target database to error on), avoiding silent wrong values.

**Lowercase primary-key insert return (PostgreSQL family)**

- The case conversion of the primary-key column name when returning the key value on single-row inserts (`getReturnPrimaryKeyColumnCase`) is expanded from PostgreSQL/PostgreSQL14 only to the entire **PG-folding family**: OpenGauss, GaussDB, MogDB, Vastbase, StarDB, Oscar, Kingbase and HighGo are now lowercased as well. Reason: `getGeneratedKeys` column hints are case-sensitive on PG-folding kernels (e.g. opengauss/vastbase/highgo report "column does not exist" for "ID"/"Id", and kingbase errors on mixed case), so lowercasing is safe for the whole family; the mysql family/tidb/oceanbase/sqlserver/db2/dm/oracle keep DEFAULT (the driver ignores the hint or folds consistently). This can still be overridden per dialect via the `dialectReturnPrimaryColumnCase` configuration.

**Other optimizations and fixes**

- Fixed bare functions at the very start of a string never being converted (when the whole sql is a function expression, the adaptation regex `\W(funcName)\(` never matches; a space sentinel is added at the entry);
- Completed TO_DATE/TO_TIMESTAMP cast-family handling for HIGHGO/H2/SQLITE.

## 8. Recommended Upgrade Steps

1. Upgrade the dependency version numbers uniformly to 6.0.4 (starter / spring / solon-plugin use the same version as core);
2. Search globally for `parallQuery` / `ParallQuery` and change them to `parallelQuery` / `ParallelQuery` (an IDE rename is enough);
3. If you have custom `DataSourceCallbackHandler` implementations, adjust the `doConnection` signature to take a `DBProfile` parameter;
4. If you reference the framework internal utility classes listed in the table above, adjust the imports to their new package locations;
5. Startup verification: watch the SQL output in debug mode and run business regression tests (prioritize cache translate, pagination and parallel query).
