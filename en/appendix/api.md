# API Cheat Sheet

`LightDao` is sqltoy's unified entry point: **72 method names, 109 declarations including overloads**, covering object operations, querying, execution, cache translate, extension metadata and chained entry points. This page groups the methods by purpose so you can go from "what I need to do" to "which method" to the detailed page.

> - Authoritative source is the `LightDao` interface (`org.sagacity.sqltoy.dao.LightDao`); `SqlToyDao`/`SqlToyLazyDao` are legacy interfaces — use `LightDao` in new projects.
> - Every method has an underlying implementation built on `QueryExecutor`/`EntityQuery`; understanding those two gives you flexible combinations — see [Query API](en/query/sqltoy_query.md).
> - Full signatures and Javadoc: [javadoc.io](https://javadoc.io/doc/com.sagframe/sagacity-sqltoy).

## 1. Chained entry points (13)

The chain API is for scenarios needing "many parameters + explicit datasource + batch size + lock mode"; each entry returns a builder that ends with `one()/many()/find()/update()` and friends.

| Method | Returns | Purpose | Details |
| --- | --- | --- | --- |
| `query()` | `Query` | Chained query | [Link Chain API](en/query/link_api.md) |
| `save()` | `Save` | Chained save (`saveMode`, `batchSize`) | [Link Chain API](en/query/link_api.md) |
| `update()` | `Update` | Chained update (`forceUpdateProps`) | [Link Chain API](en/query/link_api.md) |
| `delete()` | `Delete` | Chained delete | [Link Chain API](en/query/link_api.md) |
| `load()` | `Load` | Chained load (`lock`, cascades) | [Link Chain API](en/query/link_api.md) |
| `unique()` | `Unique` | Uniqueness check returning the record | [Link Chain API](en/query/link_api.md) |
| `execute()` | `Execute` | Execute arbitrary SQL/DML | [Link Chain API](en/query/link_api.md) |
| `batch()` | `Batch` | Batch execution | [Link Chain API](en/query/link_api.md) |
| `store()` | `Store` | Stored procedures (incl. multiple result sets) | [Stored Procedures](en/query/store_procedure.md) |
| `treeTable()` | `TreeTable` | Tree-table operations | [Tree-Table Route](en/crud/tree_table.md) |
| `tableApi()` | `TableApi` | Table/column metadata, truncate/drop | [TableApi](en/tools/table_api.md) |
| `elastic()` | `Elastic` | Elasticsearch (SQL/JSON modes) | [Elasticsearch](en/nosql/sqltoy_elasticsearch.md) |
| `mongo()` | `Mongo` | MongoDB query/aggregation | [MongoDB](en/nosql/sqltoy_mongo.md) |

## 2. Lambda conditions (3)

| Method | Purpose | Details |
| --- | --- | --- |
| `lambdaQuery(Class)` | Returns a `LambdaQuery` bound to this dao; terminals `find/getOne/findPage/findTop/findRandom/count/exists` | [Lambda Conditions](en/query/lambda_query.md) |
| `lambdaUpdate(Class)` | Returns a `LambdaUpdate`; `set/setExpr` + conditions then `update()` | [Lambda Conditions](en/query/lambda_query.md) |
| `lambdaDelete(Class)` | Returns a `LambdaDelete`; conditions then `delete()` | [Lambda Conditions](en/query/lambda_query.md) |

## 3. Save and insert (5)

| Method | Notes |
| --- | --- |
| `save(entity)` | Saves one row, returning the primary key (backfilled by the key strategy) |
| `saveAll(List)` | Batch save, returns the affected row count |
| `saveAllIgnoreExist(List)` | Batch save, skipping existing rows (`insert ignore` / `on conflict do nothing` semantics) |
| `saveOrUpdate(entity, forceUpdateProps...)` | Update when present, insert when absent (merge semantics) |
| `saveOrUpdateAll(List, forceUpdateProps...)` | Batch merge |

## 4. Update (8)

| Method | Notes | Details |
| --- | --- | --- |
| `update(entity, forceUpdateProps...)` | Elastic update: non-null fields participate; `forceUpdateProps` forces specific fields | [Object CRUD](en/crud/sqltoy_crud.md) |
| `updateDeeply(entity)` | Deep update: every field participates (including nulls) | [Object CRUD](en/crud/sqltoy_crud.md) |
| `updateAll(List, forceUpdateProps...)` / `updateAllDeeply(List)` | Batch elastic/deep update | [Object CRUD](en/crud/sqltoy_crud.md) |
| `updateByQuery(Class, EntityUpdate)` | Single-table conditional update, supporting `set col = col + ?` | [Object CRUD](en/crud/sqltoy_crud.md) |
| `updateSaveFetch(...)` | Lock-query, insert when absent, update when present, returning the result (overloads for several unique keys; first choice for high-concurrency ledger scenarios) | [Object CRUD](en/crud/sqltoy_crud.md) |
| `updateFetch(QueryExecutor, UpdateRowHandler)` | Lock-query → validate → modify → return in one interaction (for scenarios where the record must exist and conditions are freely authored) | [Object CRUD](en/crud/sqltoy_crud.md) |
| `updateCascade(entity, ...)` | Cascade update (with a per-child-table forced-update-field map) | [Object CRUD](en/crud/sqltoy_crud.md) |

## 5. Delete (5)

| Method | Notes |
| --- | --- |
| `delete(entity)` / `deleteAll(List)` | Delete by entity primary key |
| `deleteByIds(Class, Object... ids)` | Delete by a collection of ids |
| `deleteByQuery(Class, EntityQuery)` | Single-table conditional delete |
| `truncate(Class)` | Truncate the table |

## 6. Load (8)

| Method | Notes | Details |
| --- | --- | --- |
| `load(entity)` / `load(entity, LockMode)` | Load by primary key, optionally locked | [Object CRUD](en/crud/sqltoy_crud.md) |
| `loadById(Class, id)` / `loadByIds(Class, Object... ids)` | Load by id / ids | [Object CRUD](en/crud/sqltoy_crud.md) |
| `loadAll(List)` / `loadAll(List, LockMode)` | Batch load (optimized with IN) | [Object CRUD](en/crud/sqltoy_crud.md) |
| `loadCascade(entity, LockMode, Class... cascadeTypes)` / `loadAllCascade(List, Class...)` | Cascade load (choose which child tables) | [Object CRUD](en/crud/sqltoy_crud.md) |
| `loadEntity(Class, EntityQuery[, resultType])` | Single-table conditional load | [Query API](en/query/sqltoy_query.md) |
| `loadByQuery(QueryExecutor)` | Load through a `QueryExecutor` | [Query API](en/query/sqltoy_query.md) |

## 7. Query (15)

| Method | Notes | Details |
| --- | --- | --- |
| `findOne(sqlOrSqlId, params, resultType)` | Single row | [Query API](en/query/sqltoy_query.md) |
| `find(sqlOrSqlId, params[, resultType])` | List (several parameter-shape overloads) | [Query API](en/query/sqltoy_query.md) |
| `findByQuery(QueryExecutor)` | Unified `QueryExecutor` entry | [Query API](en/query/sqltoy_query.md) |
| `findPage(page, sqlOrSqlId, params[, resultType])` | Pagination | [Pagination](en/query/pagination.md) |
| `findPageByQuery(page, QueryExecutor)` | Unified pagination entry | [Pagination](en/query/pagination.md) |
| `findTop(sqlOrSqlId, params, topSize[, resultType])` | First N rows / N% | [Query API](en/query/sqltoy_query.md) |
| `findTopByQuery(QueryExecutor, topSize)` | Same, `QueryExecutor` form | [Query API](en/query/sqltoy_query.md) |
| `findRandom(sqlOrSqlId, params, randomCount[, resultType])` | Random N rows / ratio | [Query API](en/query/sqltoy_query.md) |
| `findRandomByQuery(QueryExecutor, randomCount)` | Same, `QueryExecutor` form | [Query API](en/query/sqltoy_query.md) |
| `findEntity(Class, EntityQuery[, resultType])` | Single-table entity query | [Query API](en/query/sqltoy_query.md) |
| `findPageEntity(page, Class, EntityQuery[, resultType])` | Single-table entity pagination | [Query API](en/query/sqltoy_query.md) |
| `getValue(sqlOrSqlId, params[, resultType])` | Single value | [Query API](en/query/sqltoy_query.md) |
| `getCount(sqlOrSqlId, Map)` / `getCount(Class, EntityQuery)` | Row count | [Query API](en/query/sqltoy_query.md) |
| `isUnique(entity, paramsNamed...)` | Uniqueness check | [Query API](en/query/sqltoy_query.md) |
| `fetchStream(QueryExecutor, StreamResultHandler)` | Streaming callbacks for huge result sets | [Query API](en/query/sqltoy_query.md) |

## 8. Execution and everything else

| Method | Notes | Details |
| --- | --- | --- |
| `executeSql(sqlOrSqlId[, params])` | Execute modifying SQL (four parameter shapes) | [Link Chain API](en/query/link_api.md) |
| `batchUpdate(sqlOrSqlId, dataSet[, autoCommit])` | Batch execution | [Link Chain API](en/query/link_api.md) |
| `insertReturnPrimaryKey(sqlOrSqlId, entity, pkField)` | Insert and return the primary key | [Link Chain API](en/query/link_api.md) |
| `executeStore(storeSqlOrKey, inParamValues)` / `executeMoreResultStore(...)` | Stored procedures (incl. multiple result sets) | [Stored Procedures](en/query/store_procedure.md) |
| `parallelQuery(List<ParallelQuery>, paramsMap[, ParallelConfig])` | Parallel query | [Parallel Query](en/query/parallel_query.md) |
| `wrapTreeTableRoute(TreeTableModel)` | Build tree node route/level/leaf flags | [Tree-Table Route](en/crud/tree_table.md) |
| `generateBizId(signature, increment)` / `generateBizId(entity)` / `generateBizId(table, signature, params, ...)` | Generate business keys | [Primary Key Strategies](en/primarykey/sqltoy_primarykey.md) |
| `convertType(source, resultType, ignoreProperties...)` | DTO↔POJO, List and Page conversion | [Utilities](en/tools/utils.md) |
| `getTranslateCache(cacheName, cacheType[, resultType])` / `translate(...)` / `cacheMatchKeys(...)` / `existCache(...)` / `getCacheNames()` | Cache-translate APIs (dropdown values, callback translation, reverse key matching) | [Cache Translate](en/quickstart/translates.md) |
| `getSqlToyConfig(sqlKey, SqlType)` / `getEntityMeta(Class)` | SQL config / entity metadata (common in report and low-code integration) | [Platform Integration](en/tools/integration.md) |
| `getSqlToyContext()` / `getDataSource()` / `flush()` | Context, datasource, flush | [Technical Architecture](en/introduction/architecture.md) |

---

## 9. Extension points (SPI)

Beyond DAO methods, sqltoy opens up the following interfaces; implement one and attach it through the matching property in [Configuration](en/config/sqltoy_config.md).

### 9.1 Configured extension points (15)

| Property | Interface | Purpose |
| --- | --- | --- |
| `unifyFieldsHandler` | `IUnifyFieldsHandler` | Unified common-field filling (created/updated by and at, tenant, etc.) |
| `typeHandler` | `TypeHandler` | Custom column type mapping (JSON/vector/geometry are built in) |
| `sqlInterceptors` | `SqlInterceptor` | Central SQL processing (tenant filtering, schema rewriting) |
| `sqlFormater` | `SqlFormater` | SQL log formatting (depends on druid by default) |
| `translateCacheManager` | `TranslateCacheManager` | Cache container for translate (beyond ehcache/caffeine) |
| `dynamicCacheFetch` | `DynamicCacheFetch` | Batch fetch for the FIFO dynamic cache (usually redis-backed) |
| `dynamicFecthCacheManager` | `DynamicFetchCacheManager` | Dynamic cache manager |
| `dataSourceSelector` | `DataSourceSelector` | Dynamic datasource routing |
| `connectionFactory` | `ConnectionFactory` | Connection acquire/release (plain Java scenarios) |
| `fieldsSecureProvider` | `FieldsSecureProvider` | Field encryption algorithm |
| `desensitizeProvider` | `DesensitizeProvider` | Masking algorithm |
| `customFilterHandler` | `FilterHandler` | Custom parameter filter (`<custom-handler>`) |
| `overTimeSqlHandler` | `OverTimeSqlHandler` | Slow-SQL collection and reporting |
| `dialectDDLGenerator` | `DialectDDLGenerator` | Custom DDL generation |
| `firstBizCodeTrace` | `FirstBizCodeTrace` | Record the business call site of a SQL |

### 9.2 Callback and integration interfaces

| Package | Interface | Purpose |
| --- | --- | --- |
| `callback` | `StreamResultHandler` | Row-by-row streaming callback (`fetchStream`) |
| `callback` | `UpdateRowHandler` / `UpdateRowCallback` | How `updateFetch` handles the locked rows |
| `callback` | `EntityUpdateCallback` | Entity update callback of `updateSaveFetch` |
| `callback` | `DataSourceCallbackHandler` | Work directly on a `Connection` (`doConnection(conn, DBProfile)`) |
| `callback` | `TransactionHandler` | Custom logic inside a transaction |
| `callback` | `LockSqlHandler` / `UniqueSqlHandler` / `GenerateSqlHandler` | Dialect-level SQL generation takeover (locking, uniqueness top-N, custom SQL) |
| `callback` | `GenerateSavePKStrategy` | Custom primary-key backfill strategy |
| `callback` | `TreeIdAndPidGet` | id/pid extraction for tree sorting |
| `callback` | `DbAdapterHandler` | Cross-database adaptation callback |
| `callback` | `DecryptHandler` / `CacheFilter` | Query-time decryption; cache-key filtering (tenant/status dimensions) |
| `callback` | `RowCallbackHandler` / `PreparedStatementResultHandler` / `CallableStatementResultHandler` / `InsertRowCallbackHandler` / `XMLCallbackHandler` | Row/statement/stored-procedure/batch-insert/XML callbacks (rarely used, reserved for extreme cases) |
| `integration` | `AppContext` / `ConnectionFactory` / `DistributeIdGenerator` / `MongoQuery` | Framework-agnostic SPIs implemented per Spring/Solon/plain Java |

> Custom implementation classes need reflection registration under **native images**; since 6.0.8 the 15 configured extension points above are registered automatically from configuration — see [GraalVM Native Image Guide](en/tools/graalvm_native.md).
