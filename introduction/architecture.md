# 技术架构

sqltoy 是一个**以动态 SQL 为核心、面向企业级复杂场景**的 Java ORM 框架。它既可以与 Spring/Spring Boot/Solon 集成，也支持纯 Java 环境使用。理解其内部结构，有助于在复杂场景下灵活扩展。

## 一、整体设计

sqltoy 的核心思路：

- **SQL 与代码分离**：SQL 写在 `*.sql.xml` 中（支持 debug 模式热加载），通过 `sqlId` 调用，也可直接传 SQL。
- **对象与表映射**：POJO/VO 通过注解（`@SqlToyEntity`/`@Entity`/`@Id`/`@Column`）与数据库表建立映射，由 `EntityManager` 统一管理。
- **方言隔离**：所有数据库差异收敛到 `dialect` 包，通过 `DialectFactory` 自动识别数据库类型并路由到对应实现，业务 SQL 保持跨库一致。
- **内存算法增强**：分页优化、行列转换、汇总、同比环比、树形排序、缓存翻译等，大量在应用内存中以算法完成，既减轻数据库压力又实现跨库一致。

## 二、核心包结构

框架核心位于 `org.sagacity.sqltoy` 包下（模块 `sagacity-sqltoy`）：

| 包 / 类 | 职责 |
| --- | --- |
| `SqlToyContext` | **整个框架的根上下文**，承载全部配置（数据源、方言、SQL 资源、缓存翻译、主键策略、拦截器等） |
| `SqlToyConstants` | 框架常量，可通过 `sqltoy-default.properties` 加载，亦可经 `SqlToyContext` 的 dialectConfig 覆盖 |
| `dao` | 对外 DAO 接口，统一以 `LightDao` 为操作入口（约 110 个方法）及 `impl` 实现（`DefaultLightDaoImpl`/`LightDaoImpl`）；`SqlToyDao`/`SqlToyLazyDao` 为早期历史接口，新项目请一律使用 `LightDao` |
| `support.SqlToyDaoSupport` | 所有数据库交互操作的**基类实现**（框架真正的"干活"类） |
| `service.SqlToyCRUDService` | 通用 CRUD Service，简单增删改查无需自己写 Service |
| `link` | **链式 API**：`Query`/`Save`/`Update`/`Delete`/`Load`/`Store`/`Unique`/`Execute`/`Batch`/`Elastic`/`Mongo`/`TreeTable`/`TableApi`，均继承 `BaseLink` |
| `model` | 数据模型：`Page`、`QueryExecutor`、`EntityQuery`/`EntityUpdate`、`ParallQuery`、`QueryResult`、`StoreResult`、`TreeTableModel`、`Summary`、`ColsChainRatio`/`RowsChainRatio`、`CacheArg`、`TableMeta`/`ColumnMeta`、`LockMode`/`SaveMode`/`MaskType` 等 |
| `config` | SQL/实体加载与解析：`EntityManager`、`EntityScanner`、`SqlScriptLoader`（解析 `*.sql.xml`）、`SqlXMLConfigParse`、`SqlFileModifyWatcher`（debug 热加载）；`config.annotation`（各类注解）、`config.model`（解析后的配置模型） |
| `dialect` | 数据库方言：`Dialect` 接口 + `DialectFactory`；`impl` 下 23 种方言实现；`executor`（含并行查询执行器）、`utils`（含 `PageOptimizeUtils` 分页/count 优化引擎） |
| `plugins` | 扩展点：`calculator`（汇总/同环比/树排序/列转行等内存算法）、`datasource`（动态数据源选择）、`ddl`（POJO→DDL）、`function`（16 个跨库函数适配）、`id`（主键策略）、`interceptors`（多租户过滤）、`nosql`（ES）、`overtime`（慢 SQL）、`secure`（加解密/脱敏）、`sharding`（分库分表）；根级还有 `SqlInterceptor`、`TypeHandler`、`CrossDbAdapter`、`IUnifyFieldsHandler` |
| `translate` | 缓存翻译子系统：`TranslateManager`、`TranslateFactory`、`TranslateConfigParse`（解析 `sqltoy-translate.xml`）、`CacheUpdateWatcher`、`DynamicCacheFetch`；`cache`（ehcache/caffeine/FIFO 动态缓存实现） |
| `callback` | 22 个 SPI 回调接口：`RowCallbackHandler`、`StreamResultHandler`、`TransactionHandler`、`UpdateRowHandler`、`EntityUpdateCallback`、`DecryptHandler` 等 |
| `integration` | 框架无关 SPI：`AppContext`、`ConnectionFactory`、`DistributeIdGenerator`、`MongoQuery` |
| `utils` | 约 32 个工具类：`SqlUtil`、`BeanUtil`、`CollectionUtil`、`DateUtil`、`ParallelUtils`、`ResultUtils`、`TranslateUtils`、`DBTransUtils`、几何类型工具等 |

## 三、集成模块

除核心模块外，sqltoy 提供多种框架集成：

| 模块 | artifactId | 说明 |
| --- | --- | --- |
| 核心 | `sagacity-sqltoy` | ORM 核心，可纯 Java 使用 |
| 传统 Spring | `sagacity-sqltoy-spring` | Spring 事务感知的 DAO 实现、`SpringAppContext`/`SpringConnectionFactory` |
| Spring Boot | `sagacity-sqltoy-spring-starter` | 自动配置（`spring.sqltoy.*`）、任务线程池、GraalVM AOT 原生支持 |
| Solon | `sagacity-sqltoy-solon-plugin` | Solon 框架适配（`sqltoy.*` 配置前缀、`@Db` 注入） |

## 四、一次查询的运行流程

以 `lightDao.findPage(page, "sqlId", params, VO.class)` 为例：

1. `LightDao` 接口 → `SqlToyDaoSupport` 基类实现；
2. 从 `SqlToyContext` 取出该 `sqlId` 对应的 `SqlToyConfig`（已由 `SqlScriptLoader` 预解析）；
3. 经 `filters` 规整参数、`#[]` 动态片段裁剪，生成最终 SQL 与参数数组；
4. `DialectFactory` 识别数据库方言，生成分页 SQL 与优化后的 count SQL（`PageOptimizeUtils`）；
5. 若配置了 `sharding`/`tenant` 拦截器、`translate` 缓存翻译、`secure` 脱敏，则依次加工；
6. 执行查询，结果集经内存算法（summary/pivot/chain-ratio/tree-sort 等）二次计算；
7. 封装为 `Page` 返回。

> 想深入源码，建议从 `SqlToyDaoSupport`（操作实现）、`LightDao`（API 入口）、`DialectFactory`（方言路由）、`SqlToyContext`（配置中枢）、`TranslateManager`（缓存翻译）、`PageOptimizeUtils`（分页优化）这几个类入手。
