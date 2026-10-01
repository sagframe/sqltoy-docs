# Upgrade to 6.0.x

Changes and notes for upgrading from 5.6.x to 6.0.3 (the 6.0 line). All changes have been verified against the 6.0 source code.

## 1. Environment Requirements

| Item | Requirement |
| --- | --- |
| JDK | **17+** (targeting Spring Boot 3/4); JDK 8 projects should use `5.6.96.jre8` (the final jre8 version, also works with the quickvo-maven-plugin) |
| Dependency coordinates | Unchanged: `com.sagframe:sagacity-sqltoy` (plus spring / spring-starter / solon-plugin); only the version number is upgraded to 6.0.3 |
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

## 6. Recommended Upgrade Steps

1. Upgrade the dependency version numbers uniformly to 6.0.3 (starter / spring / solon-plugin use the same version as core);
2. Search globally for `parallQuery` / `ParallQuery` and change them to `parallelQuery` / `ParallelQuery` (an IDE rename is enough);
3. If you have custom `DataSourceCallbackHandler` implementations, adjust the `doConnection` signature to take a `DBProfile` parameter;
4. If you reference the framework internal utility classes listed in the table above, adjust the imports to their new package locations;
5. Startup verification: watch the SQL output in debug mode and run business regression tests (prioritize cache translate, pagination and parallel query).
