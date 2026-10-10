# 6.0 升级指南

从 5.6.x 升级到 6.0.4（6.0 线）的变更点与注意事项。变更内容均对照 6.0 源码核实。

## 一、环境要求

| 项 | 要求 |
| --- | --- |
| JDK | **17+**（面向 Spring Boot 3/4）；JDK 8 项目请使用 `5.6.96.jre8`（最终 jre8 版本，支持 quickvo-maven-plugin 插件） |
| 依赖坐标 | 不变：`com.sagframe:sagacity-sqltoy`（及 spring / spring-starter / solon-plugin），仅版本号升级为 6.0.4 |
| 配置参数 | `spring.sqltoy.*` 在 6.0.2 的 58 个参数基础上新增 2 个：`realDialectFirst`（6.0.3 新增）、`ddlLowerOrUpper`（6.0.3 起暴露为 starter 属性），其余参数无增减，存量配置无需调整 |

## 二、API 变更（需要改代码）

| 变更点 | 5.6.x | 6.0.x |
| --- | --- | --- |
| 并行查询 | `lightDao.parallQuery(List<ParallQuery>, ...)` | `lightDao.parallelQuery(List<ParallelQuery>, ...)`（模型类同步更名 `ParallQuery` → `ParallelQuery`） |
| 连接反调 | `doConnection(Connection conn, Integer dbType, String dialect)` | `doConnection(Connection conn, DBProfile profile)`——`DBProfile` 提供完整的数据库执行档案 |

`DBProfile`（`org.sagacity.sqltoy.model.DBProfile`）提供：`getDbType()` / `getDialect()` / `getUrl()` / `getProductName()` / `getMajorVersion()`，以及 `isMysqlFamily()` / `isOracleFamily()` / `isOceanBase()` / `isBackslashEscape()` 等便捷判断，详见[其他特性](../tools/other_features.md)。

> 其余高频 API（LightDao 其余 72 个方法、Link 链式 API、QueryExecutor/EntityQuery/EntityUpdate、既有配置参数）**均无变化**，升级成本主要集中在上面两处。

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

## 五、6.0.3 更新说明

6.0.3 在 6.0.2 基础上进一步增强，均为**增量能力，无需改动既有代码**：

**SQL 方言体系**

- `<sql>` 元素新增 `dialect` 属性：声明本条 sql 按指定方言形态解析固化，加载时按该方言做函数/保留字转换；执行期当前库方言与声明一致时跳过转换，不一致时惰性转换适配（`mql`/`eql` 不支持），详见[方言自适配与函数扩展](../dialect/sqltoy_function.md)；
- 新增 `spring.sqltoy.realDialectFirst` 配置（默认 `false`）：开启后 sqlId 方言变体查找优先按**连接探测的真实方言**（`DBProfile.realDialect`，典型如 OceanBase 按 mysql 方言配置、代理库场景），真实方言变体不存在时回退原配置方言查找链。

**POJO 生成 DDL（详见[POJO生成表结构DDL](../primarykey/sqltoy_ddl.md)）**

- 新增 `@Partition` / `@PartitionDef` / `@MppTable` 实体注解：描述表分区策略与 MPP 分析库（ClickHouse/Doris/StarRocks）表引擎元数据，配合 quickvo 依据数据库分区/表定义自动产生；
- 建表语句自动渲染 `PARTITION BY` 分区子句（RANGE/LIST/HASH/RANGE COLUMNS/LIST COLUMNS 及分区明细）；
- 新增 Doris、StarRocks、ClickHouse、DB2、HANA、SQLite 专用 DDL 生成器（此前 Doris/StarRocks 复用 MySQL 生成器，其余落入默认生成器）；
- `@Foreign` 外键的 `deleteRestict`/`updateRestict` 支持完整参照动作（`ReferentialAction`：CASCADE/RESTRICT/SET_NULL/NO_ACTION/SET_DEFAULT），并按数据库兼容性自动裁剪；
- JSON 列类型按数据库降级承载（HANA→NCLOB、SQL Server→NVARCHAR(MAX)、DB2/Oracle11→CLOB）。

**修复与优化**

- 分库分表并行执行：`ShardingResult` 新增 `cause` 字段保留原始异常，全局回滚抛出的异常携带根因堆栈；`@Sharding.maxConcurrents` 语义修正（0 表示不限制、1 表示串行）；
- `executeSql`/`batchUpdateByJdbc` 手动提交场景失败时强制回滚，`autoCommit` 恢复移入 finally，避免异常连接带着被改写的提交方式归还连接池；
- 查询结果映射：`number-format` 格式化后的带千分位逗号数值（如 `8,888.0000`）再映射到数值属性时自动剥离分组逗号；
- sqlserver 分页 WITH 部分剥离置前、union 派生表包装拼接顺序修复。

## 六、6.0.4 更新说明

6.0.4 在 6.0.3 基础上进一步增强，同样为**增量能力，无需改动既有代码**：

**缓存翻译 rest 模式认证增强（详见[缓存翻译使用](../quickstart/translates.md)）**

- `rest-translate` / `rest-checker` / `rest-increment-checker` 新增 `auth-type` 认证模式：`basic`（默认，兼容既有 `username`/`password`）与 `jwt`；
- jwt 获取 token 三种方式三选一（同配按优先级生效）：`token-url` 登录接口表单提交 username/password 获取 token（响应 json 按 `token-path` 提取，支持 `data.token` 点路径）并缓存、`token-secure-key` 本地自签名 jwt（支持 HS256/384/512 共享密钥与 RS256/384/512 的 PKCS#8 私钥，无需登录接口）、`authorization` 直接配置静态长效 token；
- 配套 `token-header`（默认 `Authorization`）、`token-prefix`（默认 `Bearer`，设为 `none` 发裸 token）、`token-expire`（默认 1800 秒，响应含 `expires_in` 时以响应为准）；token 缓存复用、临近过期自动刷新、请求遇 401 自动失效重登（或重新签名）并重试一次。

**跨数据库函数适配完善（详见[方言自适配与函数扩展](../dialect/sqltoy_function.md)）**

- 新增源函数识别：`nvl2(a,b,c)`（非 oracle 系转 case when 判空）、单参 `isnull(x)`（mysql 返回 0/1 语义）、`sys_timestamp`（oracle 系透传、mysql 系保留小数秒精度、sqlserver 用 sysdatetime）、`strpos(str,sub)`（pg 系/clickhouse 透传，其余转 instr）、`substr(s,-n)` 负起点、`curdate()`/`CURRENT_DATE` 新函数类（oracle 系转 `TRUNC(CURRENT_DATE)`，db2 用 CURRENT DATE 关键字体，sqlite 取本地时钟）；
- `group_concat`/`listagg`/`string_agg` 支持 `within group (order by ...)` 尾部子句、参数内嵌 order by 与 DISTINCT 前缀识别；
- `datediff(month,...)` 月差口径统一为年月分量差（不再按 oracle MONTHS_BETWEEN 小数口径注册）；`to_char` 转 sqlserver 改以 FORMAT 承担，修复大写格式 token（如 `YYYY-MM-DD HH24:MI:SS`）的错值；sqlite 目标 `now()`/`CURRENT_DATE`/`CURRENT_TIMESTAMP` 统一取本地时钟。

**修复**

- 修复 SubStr 负起点与 mysql 契约偏离的静默错值（pg 系/sqlserver/h2/db2/hana 四处：起点算出小于 1 时统一返回空串）；
- 修复无分钟格式（如 `yyyy-MM-dd HH`）的独立 HH 时间 token 在 pg/oracle 系按 12 小时制解释导致分桶边界错乱的问题。

**配套工具**

- 配套的 quickvo-maven-plugin 升级至 **2.0.2**。

## 七、升级步骤建议

1. 依赖版本号统一升级为 6.0.4（starter / spring / solon-plugin 与 core 同版本）；
2. 全局搜索 `parallQuery` / `ParallQuery`，改为 `parallelQuery` / `ParallelQuery`（IDE 重命名即可）；
3. 如有自定义 `DataSourceCallbackHandler` 实现，把 `doConnection` 签名调整为 `DBProfile` 参数；
4. 如引用了上表所列框架内部工具类，按新包位置调整 import；
5. 启动验证：观察 debug 模式下 SQL 输出与业务回归（缓存翻译、分页、并行查询优先）。
