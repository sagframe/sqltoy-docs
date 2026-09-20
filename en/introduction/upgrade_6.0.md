# Upgrade to 6.0.x

Changes and notes for upgrading from 5.6.x to 6.0.2 (the 6.0 line). All changes have been verified against the 6.0 source code.

## 1. Environment Requirements

| Item | Requirement |
| --- | --- |
| JDK | **17+** (targeting Spring Boot 3/4); JDK 8 projects should use `5.6.96.jre8` (the final jre8 version, also works with the quickvo-maven-plugin) |
| Dependency coordinates | Unchanged: `com.sagframe:sagacity-sqltoy` (plus spring / spring-starter / solon-plugin); only the version number is upgraded to 6.0.2 |
| Configuration parameters | All 58 `spring.sqltoy.*` parameters are **unchanged**; no configuration file adjustments are needed |

## 2. API Changes (Code Changes Required)

| Change | 5.6.x | 6.0.x |
| --- | --- | --- |
| Parallel query | `lightDao.parallQuery(List<ParallQuery>, ...)` | `lightDao.parallelQuery(List<ParallelQuery>, ...)` (the model class is renamed accordingly: `ParallQuery` → `ParallelQuery`) |
| Connection callback | `doConnection(Connection conn, Integer dbType, String dialect)` | `doConnection(Connection conn, DBProfile profile)` — `DBProfile` provides the complete database execution profile |

`DBProfile` (`org.sagacity.sqltoy.model.DBProfile`) provides `getDbType()` / `getDialect()` / `getUrl()` / `getProductName()` / `getMajorVersion()`, plus convenience checks such as `isMysqlFamily()` / `isOracleFamily()` / `isOceanBase()` / `isBackslashEscape()`; see [Other Features](../tools/other_features.md) for details.

> The other frequently used APIs (the remaining 72 LightDao methods, the Link chain API, QueryExecutor/EntityQuery/EntityUpdate, and the 58 configuration parameters) are **all unchanged**; the upgrade cost is concentrated in the two items above.

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

## 5. Recommended Upgrade Steps

1. Upgrade the dependency version numbers uniformly to 6.0.2 (starter / spring / solon-plugin use the same version as core);
2. Search globally for `parallQuery` / `ParallQuery` and change them to `parallelQuery` / `ParallelQuery` (an IDE rename is enough);
3. If you have custom `DataSourceCallbackHandler` implementations, adjust the `doConnection` signature to take a `DBProfile` parameter;
4. If you reference the framework internal utility classes listed in the table above, adjust the imports to their new package locations;
5. Startup verification: watch the SQL output in debug mode and run business regression tests (prioritize cache translate, pagination and parallel query).
