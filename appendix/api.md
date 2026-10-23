# API 速查

`LightDao` 是 sqltoy 的统一操作入口：**72 个方法名、109 个声明（含重载）**，覆盖对象操作、查询、执行、缓存翻译、扩展元数据与链式入口。本页按用途分组给出方法名与对应章节，便于"知道要做什么、找到方法名、再跳到详细页"。

> - 以 `LightDao` 接口为准（`org.sagacity.sqltoy.dao.LightDao`）；`SqlToyDao`/`SqlToyLazyDao` 为早期历史接口，新项目统一用 `LightDao`。
> - 所有方法都有基于 `QueryExecutor`/`EntityQuery` 的底层实现，理解两者即可灵活组合，见[常规查询 API](query/sqltoy_query.md)。
> - 完整的参数签名与 Javadoc 见 [javadoc.io](https://javadoc.io/doc/com.sagframe/sagacity-sqltoy)。

## 一、链式入口（13）

链式 API 适合需要"多参数 + 指定数据源 + 批量 + 锁模式"的场景，每个入口返回对应构建器，最终以 `one()/many()/find()/update()` 等终结。

| 方法 | 返回 | 用途 | 详见 |
| --- | --- | --- | --- |
| `query()` | `Query` | 链式查询 | [Link 链式操作](query/link_api.md) |
| `save()` | `Save` | 链式保存（含 `saveMode`、`batchSize`） | [Link 链式操作](query/link_api.md) |
| `update()` | `Update` | 链式更新（含 `forceUpdateProps`） | [Link 链式操作](query/link_api.md) |
| `delete()` | `Delete` | 链式删除 | [Link 链式操作](query/link_api.md) |
| `load()` | `Load` | 链式加载（含 `lock`、级联） | [Link 链式操作](query/link_api.md) |
| `unique()` | `Unique` | 唯一性校验并取记录 | [Link 链式操作](query/link_api.md) |
| `execute()` | `Execute` | 执行任意 SQL/DML | [Link 链式操作](query/link_api.md) |
| `batch()` | `Batch` | 批量执行 | [Link 链式操作](query/link_api.md) |
| `store()` | `Store` | 存储过程（含多结果集） | [存储过程调用](query/store_procedure.md) |
| `treeTable()` | `TreeTable` | 树形表操作 | [树形表节点路径构造](crud/tree_table.md) |
| `tableApi()` | `TableApi` | 表/列元数据、truncate/drop | [表元数据操作](tools/table_api.md) |
| `elastic()` | `Elastic` | Elasticsearch（sql/json 双模式） | [Elasticsearch 支持](nosql/sqltoy_elasticsearch.md) |
| `mongo()` | `Mongo` | MongoDB 查询/聚合 | [MongoDB 支持](nosql/sqltoy_mongo.md) |

## 二、Lambda 条件（3）

| 方法 | 用途 | 详见 |
| --- | --- | --- |
| `lambdaQuery(Class)` | 返回绑定当前 dao 的 `LambdaQuery`，终端 `find/getOne/findPage/findTop/findRandom/count/exists` | [Lambda 条件查询与更新](query/lambda_query.md) |
| `lambdaUpdate(Class)` | 返回 `LambdaUpdate`，`set/setExpr` + 条件后 `update()` | [Lambda 条件查询与更新](query/lambda_query.md) |
| `lambdaDelete(Class)` | 返回 `LambdaDelete`，条件后 `delete()` | [Lambda 条件查询与更新](query/lambda_query.md) |

## 三、保存与插入（5）

| 方法 | 说明 |
| --- | --- |
| `save(entity)` | 保存单条，返回主键（有主键策略时回填） |
| `saveAll(List)` | 批量保存，返回影响行数 |
| `saveAllIgnoreExist(List)` | 批量保存，已存在则跳过（对应 `insert ignore`/`on conflict do nothing` 语义） |
| `saveOrUpdate(entity, forceUpdateProps...)` | 存在则改、不存在则插（merge 语义） |
| `saveOrUpdateAll(List, forceUpdateProps...)` | 批量 merge |

## 四、修改（8）

| 方法 | 说明 | 详见 |
| --- | --- | --- |
| `update(entity, forceUpdateProps...)` | 弹性更新：非 null 字段参与，`forceUpdateProps` 指定强制更新字段 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `updateDeeply(entity)` | 深度更新：全部字段参与（含 null） | [对象化 CRUD](crud/sqltoy_crud.md) |
| `updateAll(List, forceUpdateProps...)` / `updateAllDeeply(List)` | 批量弹性/深度更新 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `updateByQuery(Class, EntityUpdate)` | 按单表条件更新，支持 `set 字段=字段+?` 自更新 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `updateSaveFetch(...)` | 锁查询、不存在则插入、存在则修改，并返回结果（多组唯一键重载；台账类高并发场景首选） | [对象化 CRUD](crud/sqltoy_crud.md) |
| `updateFetch(QueryExecutor, UpdateRowHandler)` | 锁查询→校验→修改→返回，一次交互（记录必然存在、条件自由编写的场景） | [对象化 CRUD](crud/sqltoy_crud.md) |
| `updateCascade(entity, ...)` | 级联修改（含子表强制更新字段 Map） | [对象化 CRUD](crud/sqltoy_crud.md) |

## 五、删除（5）

| 方法 | 说明 |
| --- | --- |
| `delete(entity)` / `deleteAll(List)` | 按对象主键删除 |
| `deleteByIds(Class, Object... ids)` | 按主键集合删除 |
| `deleteByQuery(Class, EntityQuery)` | 按单表条件删除 |
| `truncate(Class)` | 清空表 |

## 六、加载（8）

| 方法 | 说明 | 详见 |
| --- | --- | --- |
| `load(entity)` / `load(entity, LockMode)` | 按主键加载，可加锁 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `loadById(Class, id)` / `loadByIds(Class, Object... ids)` | 按主键（集合）加载 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `loadAll(List)` / `loadAll(List, LockMode)` | 批量加载（底层 in 优化） | [对象化 CRUD](crud/sqltoy_crud.md) |
| `loadCascade(entity, LockMode, Class... cascadeTypes)` / `loadAllCascade(List, Class...)` | 级联加载（可选加载哪些子表） | [对象化 CRUD](crud/sqltoy_crud.md) |
| `loadEntity(Class, EntityQuery[, resultType])` | 单表条件加载 | [常规查询 API](query/sqltoy_query.md) |
| `loadByQuery(QueryExecutor)` | 按 `QueryExecutor` 加载 | [常规查询 API](query/sqltoy_query.md) |

## 七、查询（15）

| 方法 | 说明 | 详见 |
| --- | --- | --- |
| `findOne(sqlOrSqlId, params, resultType)` | 单条 | [常规查询 API](query/sqltoy_query.md) |
| `find(sqlOrSqlId, params[, resultType])` | 列表（多种参数形态重载） | [常规查询 API](query/sqltoy_query.md) |
| `findByQuery(QueryExecutor)` | `QueryExecutor` 统一入口 | [常规查询 API](query/sqltoy_query.md) |
| `findPage(page, sqlOrSqlId, params[, resultType])` | 分页 | [分页优化](query/pagination.md) |
| `findPageByQuery(page, QueryExecutor)` | 分页统一入口 | [分页优化](query/pagination.md) |
| `findTop(sqlOrSqlId, params, topSize[, resultType])` | 前 N 条 / 前 N% | [常规查询 API](query/sqltoy_query.md) |
| `findTopByQuery(QueryExecutor, topSize)` | 同上，`QueryExecutor` 形态 | [常规查询 API](query/sqltoy_query.md) |
| `findRandom(sqlOrSqlId, params, randomCount[, resultType])` | 随机 N 条 / 比例 | [常规查询 API](query/sqltoy_query.md) |
| `findRandomByQuery(QueryExecutor, randomCount)` | 同上，`QueryExecutor` 形态 | [常规查询 API](query/sqltoy_query.md) |
| `findEntity(Class, EntityQuery[, resultType])` | 单表实体查询 | [常规查询 API](query/sqltoy_query.md) |
| `findPageEntity(page, Class, EntityQuery[, resultType])` | 单表实体分页 | [常规查询 API](query/sqltoy_query.md) |
| `getValue(sqlOrSqlId, params[, resultType])` | 取单值 | [常规查询 API](query/sqltoy_query.md) |
| `getCount(sqlOrSqlId, Map)` / `getCount(Class, EntityQuery)` | 取记录数 | [常规查询 API](query/sqltoy_query.md) |
| `isUnique(entity, paramsNamed...)` | 唯一性校验 | [常规查询 API](query/sqltoy_query.md) |
| `fetchStream(QueryExecutor, StreamResultHandler)` | 流式回调，超大数据量 | [常规查询 API](query/sqltoy_query.md) |

## 八、执行与其他（见下表）

| 方法 | 说明 | 详见 |
| --- | --- | --- |
| `executeSql(sqlOrSqlId[, params])` | 执行变更类 SQL（4 个参数形态重载） | [Link 链式操作](query/link_api.md) |
| `batchUpdate(sqlOrSqlId, dataSet[, autoCommit])` | 批量执行 | [Link 链式操作](query/link_api.md) |
| `insertReturnPrimaryKey(sqlOrSqlId, entity, pkField)` | 插入并返回主键 | [Link 链式操作](query/link_api.md) |
| `executeStore(storeSqlOrKey, inParamValues)` / `executeMoreResultStore(...)` | 存储过程（含多结果集） | [存储过程调用](query/store_procedure.md) |
| `parallelQuery(List<ParallelQuery>, paramsMap[, ParallelConfig])` | 并行查询 | [并行查询](query/parallel_query.md) |
| `wrapTreeTableRoute(TreeTableModel)` | 构造树节点路径/层级/叶子标记 | [树形表节点路径构造](crud/tree_table.md) |
| `generateBizId(signature, increment)` / `generateBizId(entity)` / `generateBizId(table, signature, params, ...)` | 生成业务主键 | [主键策略](primarykey/sqltoy_primarykey.md) |
| `convertType(source, resultType, ignoreProperties...)` | DTO↔POJO、List、Page 转换 | [工具类](tools/utils.md) |
| `getTranslateCache(cacheName, cacheType[, resultType])` / `translate(...)` / `cacheMatchKeys(...)` / `existCache(...)` / `getCacheNames()` | 缓存翻译相关 API（下拉框取值、反调翻译、反向匹配 key） | [缓存翻译使用](quickstart/translates.md) |
| `getSqlToyConfig(sqlKey, SqlType)` / `getEntityMeta(Class)` | 取 SQL 配置 / 实体元数据（报表、低代码平台集成常用） | [扩展集成](tools/integration.md) |
| `getSqlToyContext()` / `getDataSource()` / `flush()` | 上下文、数据源、刷新 | [技术架构](introduction/architecture.md) |

---

## 九、扩展点（SPI）速查

除 DAO 方法外，sqltoy 通过以下接口开放扩展能力；实现后按[配置参数](config/sqltoy_config.md)中对应属性挂载。

### 9.1 配置式扩展点（15 个）

| 配置项 | 接口 | 用途 |
| --- | --- | --- |
| `unifyFieldsHandler` | `IUnifyFieldsHandler` | 公共字段统一赋值（创建人/时间、租户等） |
| `typeHandler` | `TypeHandler` | 自定义列类型映射（JSON/vector/geometry 已内置） |
| `sqlInterceptors` | `SqlInterceptor` | SQL 集中加工（租户过滤、改写 schema） |
| `sqlFormater` | `SqlFormater` | SQL 日志格式化（默认依赖 druid） |
| `translateCacheManager` | `TranslateCacheManager` | 缓存翻译容器（ehcache/caffeine 之外的实现） |
| `dynamicCacheFetch` | `DynamicCacheFetch` | FIFO 动态缓存的批量捞取（常基于 redis） |
| `dynamicFecthCacheManager` | `DynamicFetchCacheManager` | 动态缓存管理器 |
| `dataSourceSelector` | `DataSourceSelector` | 动态数据源路由 |
| `connectionFactory` | `ConnectionFactory` | 连接获取/释放（纯 Java 场景） |
| `fieldsSecureProvider` | `FieldsSecureProvider` | 字段加解密算法 |
| `desensitizeProvider` | `DesensitizeProvider` | 脱敏算法 |
| `customFilterHandler` | `FilterHandler` | 自定义参数过滤器（`<custom-handler>`） |
| `overTimeSqlHandler` | `OverTimeSqlHandler` | 慢 SQL 收集与上报 |
| `dialectDDLGenerator` | `DialectDDLGenerator` | 自定义建表 DDL 生成 |
| `firstBizCodeTrace` | `FirstBizCodeTrace` | 记录 SQL 的业务调用来源 |

### 9.2 回调与集成接口

| 包 | 接口 | 用途 |
| --- | --- | --- |
| `callback` | `StreamResultHandler` | 流式查询逐行回调（`fetchStream`） |
| `callback` | `UpdateRowHandler` / `UpdateRowCallback` | `updateFetch` 对锁记录的处理 |
| `callback` | `EntityUpdateCallback` | `updateSaveFetch` 的实体更新回调 |
| `callback` | `DataSourceCallbackHandler` | 直接操作 `Connection`（`doConnection(conn, DBProfile)`） |
| `callback` | `TransactionHandler` | 自定义事务内逻辑 |
| `callback` | `LockSqlHandler` / `UniqueSqlHandler` / `GenerateSqlHandler` | 方言级 SQL 生成接管（加锁、唯一性取 top、自定义 sql） |
| `callback` | `GenerateSavePKStrategy` | 自定义主键回填策略 |
| `callback` | `TreeIdAndPidGet` | 树形集合排序取 id/pid |
| `callback` | `DbAdapterHandler` | 跨库适配回调 |
| `callback` | `DecryptHandler` / `CacheFilter` | 查询解密、缓存 key 过滤（租户/状态维度） |
| `callback` | `RowCallbackHandler` / `PreparedStatementResultHandler` / `CallableStatementResultHandler` / `InsertRowCallbackHandler` / `XMLCallbackHandler` | 行/语句/存储过程/批量插入/XML 解析级回调（极少使用，留给极端场景） |
| `integration` | `AppContext` / `ConnectionFactory` / `DistributeIdGenerator` / `MongoQuery` | 框架无关 SPI，Spring/Solon/纯 Java 各自实现 |

> 自定义实现类在 **native 镜像**下需要注册反射，6.0.8 起上表 15 个配置式扩展点会按配置自动注册，见 [GraalVM Native Image 指引](tools/graalvm_native.md)。
