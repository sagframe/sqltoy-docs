# Technical Architecture

SqlToy is a Java ORM framework centered on **dynamic SQL** and built for enterprise-scale complexity. It integrates with Spring / Spring Boot / Solon and also runs in plain Java. Understanding its internals helps you extend it confidently in complex scenarios.

## 1. Design Principles

- **SQL separated from code**: SQL lives in `*.sql.xml` files (hot-reloaded in debug mode) and is invoked by `sqlId`; raw SQL in code works too.
- **Object-to-table mapping**: POJO/VO classes carry annotations (`@SqlToyEntity`/`@Entity`/`@Id`/`@Column`) that map them to tables; `EntityManager` manages them centrally.
- **Dialect isolation**: all database differences are contained in the `dialect` package; `DialectFactory` detects the database type and routes to the right implementation, keeping business SQL portable.
- **In-memory algorithms**: pagination optimization, pivot, summary, chain-ratio, tree sorting, cache translation and more run as algorithms in application memory — offloading the database and staying consistent across databases.

## 2. Core Packages

The framework core lives under `org.sagacity.sqltoy` (artifact `sagacity-sqltoy`):

| Package / Class | Responsibility |
| --- | --- |
| `SqlToyContext` | **Root context of the whole framework**, holding all configuration (data sources, dialect, SQL resources, cache translate, id strategies, interceptors, etc.) |
| `SqlToyConstants` | Framework constants, loaded from `sqltoy-default.properties`; overridable via `SqlToyContext` dialectConfig |
| `dao` | Public DAO interfaces: `LightDao` (main entry, ~110 methods), `SqlToyDao`, `SqlToyLazyDao` with `impl` implementations |
| `support.SqlToyDaoSupport` | Base class implementing all database interactions (the real workhorse) |
| `service.SqlToyCRUDService` | Generic CRUD service — simple operations need no hand-written Service |
| `link` | **Chain API**: `Query`/`Save`/`Update`/`Delete`/`Load`/`Store`/`Unique`/`Execute`/`Batch`/`Elastic`/`Mongo`/`TreeTable`/`TableApi`, all extending `BaseLink` |
| `model` | Data models: `Page`, `QueryExecutor`, `EntityQuery`/`EntityUpdate`, `ParallelQuery`, `QueryResult`, `StoreResult`, `TreeTableModel`, `Summary`, `ColsChainRatio`/`RowsChainRatio`, `CacheArg`, `TableMeta`/`ColumnMeta`, `LockMode`/`SaveMode`/`MaskType`, etc. |
| `config` | SQL/entity loading and parsing: `EntityManager`, `EntityScanner`, `SqlScriptLoader` (parses `*.sql.xml`), `SqlXMLConfigParse`, `SqlFileModifyWatcher` (hot reload in debug); `config.annotation` (annotations), `config.model` (parsed config models) |
| `dialect` | Database dialects: `Dialect` interface + `DialectFactory`; 24 implementations under `impl`; `executor` (incl. the parallel-query executor); root-level `PageOptimizeUtils` (pagination/count optimization engine), `QueryExecutorBuilder`, `CrossDbAdapter` |
| `plugins` | Extension points: `calculator` (summary/chain-ratio/tree-sort/unpivot in-memory algorithms), `datasource` (dynamic datasource selection), `ddl` (POJO → DDL), `function` (16 cross-DB function adapters), `id` (primary-key strategies), `interceptors` (tenant filtering), `nosql` (Elasticsearch, `MongoElasticOperations`), `overtime` (slow SQL), `secure` (encryption/masking), `sharding`; plus root-level `SqlInterceptor`, `TypeHandler`, `IUnifyFieldsHandler` |
| `translate` | Cache-translate subsystem: `TranslateManager`, `TranslateFactory`, `TranslateConfigParse` (parses `sqltoy-translate.xml`), `CacheUpdateWatcher`, `DynamicCacheFetch`; `cache` (ehcache / caffeine / FIFO dynamic cache) |
| `callback` | 22 SPI callback interfaces: `RowCallbackHandler`, `StreamResultHandler`, `TransactionHandler`, `UpdateRowHandler`, `EntityUpdateCallback`, `DecryptHandler`, etc. |
| `integration` | Framework-agnostic SPI: `AppContext`, `ConnectionFactory`, `DistributeIdGenerator`, `MongoQuery` |
| `utils` | Utility classes: `SqlUtil`, `BeanUtil`, `CollectionUtil`, `DateUtil`, `ResultUtils`, `DBTransUtils`, geometry helpers, etc. |

## 3. Integration Modules

Besides the core, SqlToy ships several framework integrations:

| Module | artifactId | Description |
| --- | --- | --- |
| Core | `sagacity-sqltoy` | ORM core, usable in plain Java |
| Traditional Spring | `sagacity-sqltoy-spring` | Transaction-aware DAO implementations, `SpringAppContext`/`SpringConnectionFactory` |
| Spring Boot | `sagacity-sqltoy-spring-starter` | Auto-configuration (`spring.sqltoy.*`), task pool, GraalVM AOT native support |
| Solon | `sagacity-sqltoy-solon-plugin` | Solon adaptation (`sqltoy.*` prefix, `@Db` injection) |

## 4. Lifecycle of a Query

Take `lightDao.findPage(page, "sqlId", params, VO.class)` as an example:

1. `LightDao` interface → implemented by the `SqlToyDaoSupport` base class;
2. The `SqlToyConfig` for the `sqlId` is fetched from `SqlToyContext` (pre-parsed by `SqlScriptLoader`);
3. `filters` normalize parameters and `#[]` fragments are trimmed, producing the final SQL and parameter array;
4. `DialectFactory` detects the dialect and builds the page SQL plus the optimized count SQL (`PageOptimizeUtils`);
5. Configured `sharding`/tenant interceptors, `translate` cache translation and `secure` masking are applied in turn;
6. The query executes and the result set goes through in-memory algorithms (summary/pivot/chain-ratio/tree-sort, etc.);
7. Everything is wrapped into a `Page` and returned.

> To dig into the source, start from `SqlToyDaoSupport` (operation implementation), `LightDao` (API entry), `DialectFactory` (dialect routing), `SqlToyContext` (configuration hub), `TranslateManager` (cache translate) and `PageOptimizeUtils` (pagination optimization).
