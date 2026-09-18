# 6.0 升级指南

从 5.6.x 升级到 6.0.1（6.0 线）的变更点与注意事项。变更内容均对照 6.0 源码核实。

## 一、环境要求

| 项 | 要求 |
| --- | --- |
| JDK | **17+**（面向 Spring Boot 3/4）；JDK 8 项目请使用 `5.6.95.jre8`（最终 jre8 版本） |
| 依赖坐标 | 不变：`com.sagframe:sagacity-sqltoy`（及 spring / spring-starter / solon-plugin），仅版本号升级为 6.0.1 |
| 配置参数 | `spring.sqltoy.*` 全部 58 个参数**无增减**，配置文件无需调整 |

## 二、API 变更（需要改代码）

| 变更点 | 5.6.x | 6.0.x |
| --- | --- | --- |
| 并行查询 | `lightDao.parallQuery(List<ParallQuery>, ...)` | `lightDao.parallelQuery(List<ParallelQuery>, ...)`（模型类同步更名 `ParallQuery` → `ParallelQuery`） |
| 连接反调 | `doConnection(Connection conn, Integer dbType, String dialect)` | `doConnection(Connection conn, DBProfile profile)`——`DBProfile` 提供完整的数据库执行档案 |

`DBProfile`（`org.sagacity.sqltoy.model.DBProfile`）提供：`getDbType()` / `getDialect()` / `getUrl()` / `getProductName()` / `getMajorVersion()`，以及 `isMysqlFamily()` / `isOracleFamily()` / `isOceanBase()` / `isBackslashEscape()` 等便捷判断，详见[其他特性](../tools/other_features.md)。

> 其余高频 API（LightDao 其余 72 个方法、Link 链式 API、QueryExecutor/EntityQuery/EntityUpdate、58 个配置参数）**均无变化**，升级成本主要集中在上面两处。

## 三、包结构调整（引用了框架内部类时需调整 import）

| 类 | 5.6.x 位置 | 6.0.x 位置 |
| --- | --- | --- |
| `PageOptimizeUtils` | `dialect.utils` | `dialect` |
| `ParallelUtils` | `utils` | `dialect.executor` |
| `QueryExecutorBuilder` | `utils` | `dialect` |
| `CrossDbAdapter` | `plugins` | `dialect` |
| `MacroIfLogic` | `utils` | `config` |
| `ParamFilterUtils` | `utils` | `config`（更名为 `ParamFilterProcessor`） |
| `TranslateUtils` | `utils` | `translate` |
| `HttpClientUtils` | `utils` | `plugins.nosql` |
| `MongoElasticUtils` | `utils` | `plugins.nosql`（更名为 `MongoElasticOperations`） |
| `SavePKStrategy` | `dialect.model` | `model` |

## 四、新增能力

- **SAP HANA 方言**：方言总数达到 24 种，见[支持的数据库](db_list.md)；
- 内部模型补强：`ExecuteParams`、`ResultColumnMeta` 等（框架内部使用，不影响既有 API）。

> 更完整的版本演进细节可参阅源码仓库的 `sqltoy-orm-core/changelog.md`。

## 五、升级步骤建议

1. 依赖版本号统一升级为 6.0.1（starter / spring / solon-plugin 与 core 同版本）；
2. 全局搜索 `parallQuery` / `ParallQuery`，改为 `parallelQuery` / `ParallelQuery`（IDE 重命名即可）；
3. 如有自定义 `DataSourceCallbackHandler` 实现，把 `doConnection` 签名调整为 `DBProfile` 参数；
4. 如引用了上表所列框架内部工具类，按新包位置调整 import；
5. 启动验证：观察 debug 模式下 SQL 输出与业务回归（缓存翻译、分页、并行查询优先）。
