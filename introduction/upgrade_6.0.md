# 6.0 升级指南

从 5.6.x 升级到 6.0.9（6.0 线）的变更点与注意事项。变更内容均对照 6.0 源码核实。

## 一、环境要求

| 项 | 要求 |
| --- | --- |
| JDK | **17+**（面向 Spring Boot 3/4）；JDK 8 项目请使用 `5.6.96.jre8`（最终 jre8 版本，支持 quickvo-maven-plugin 插件） |
| 依赖坐标 | 不变：`com.sagframe:sagacity-sqltoy`（及 spring / spring-starter / solon-plugin），仅版本号升级为 6.0.9 |
| 配置参数 | `spring.sqltoy.*` 在 6.0.2 的 58 个参数基础上新增 2 个：`realDialectFirst`（6.0.3 新增）、`ddlLowerOrUpper`（6.0.3 起暴露为 starter 属性），其余参数无增减（后续版本新增参数见下文各版本章节，均为可选项），存量配置无需调整 |

## 二、API 变更（需要改代码）

| 变更点 | 5.6.x | 6.0.x |
| --- | --- | --- |
| 并行查询 | `lightDao.parallQuery(List<ParallQuery>, ...)` | `lightDao.parallelQuery(List<ParallelQuery>, ...)`（模型类同步更名 `ParallQuery` → `ParallelQuery`） |
| 连接反调 | `doConnection(Connection conn, Integer dbType, String dialect)` | `doConnection(Connection conn, DBProfile profile)`——`DBProfile` 提供完整的数据库执行档案 |

`DBProfile`（`org.sagacity.sqltoy.model.DBProfile`）提供：`getDbType()` / `getDialect()` / `getUrl()` / `getProductName()` / `getMajorVersion()`，以及 `isMysqlFamily()` / `isOracleFamily()` / `isOceanBase()` / `isBackslashEscape()` 等便捷判断，详见[其他特性](tools/other_features.md)。

> 其余高频 API（LightDao 其余 71 个方法名、共 109 个声明，Link 链式 API、QueryExecutor/EntityQuery/EntityUpdate、既有配置参数）**均无变化**，升级成本主要集中在上面两处。

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

- **SAP HANA 方言**：方言总数达到 24 种，见[支持的数据库](introduction/db_list.md)；
- 内部模型补强：`ExecuteParams`、`ResultColumnMeta` 等（框架内部使用，不影响既有 API）。

> 更完整的版本演进细节可参阅源码仓库的 `sqltoy-orm-core/changelog.md`。

## 五、6.0.3 更新说明

6.0.3 在 6.0.2 基础上进一步增强，均为**增量能力，无需改动既有代码**：

**SQL 方言体系**

- `<sql>` 元素新增 `dialect` 属性：声明本条 sql 按指定方言形态解析固化，加载时按该方言做函数/保留字转换；执行期当前库方言与声明一致时跳过转换，不一致时惰性转换适配（`mql`/`eql` 不支持），详见[方言自适配与函数扩展](dialect/sqltoy_function.md)；
- 新增 `spring.sqltoy.realDialectFirst` 配置（默认 `false`）：开启后 sqlId 方言变体查找优先按**连接探测的真实方言**（`DBProfile.realDialect`，典型如 OceanBase 按 mysql 方言配置、代理库场景），真实方言变体不存在时回退原配置方言查找链。

**POJO 生成 DDL（详见[POJO生成表结构DDL](primarykey/sqltoy_ddl.md)）**

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

**缓存翻译 rest 模式认证增强（详见[缓存翻译使用](quickstart/translates.md)）**

- `rest-translate` / `rest-checker` / `rest-increment-checker` 新增 `auth-type` 认证模式：`basic`（默认，兼容既有 `username`/`password`）与 `jwt`；
- jwt 获取 token 三种方式三选一（同配按优先级生效）：`token-url` 登录接口表单提交 username/password 获取 token（响应 json 按 `token-path` 提取，支持 `data.token` 点路径）并缓存、`token-secure-key` 本地自签名 jwt（支持 HS256/384/512 共享密钥与 RS256/384/512 的 PKCS#8 私钥，无需登录接口）、`authorization` 直接配置静态长效 token；
- 配套 `token-header`（默认 `Authorization`）、`token-prefix`（默认 `Bearer`，设为 `none` 发裸 token）、`token-expire`（默认 1800 秒，响应含 `expires_in` 时以响应为准）；token 缓存复用、临近过期自动刷新、请求遇 401 自动失效重登（或重新签名）并重试一次。

**跨数据库函数适配完善（详见[方言自适配与函数扩展](dialect/sqltoy_function.md)）**

- 新增源函数识别：`nvl2(a,b,c)`（非 oracle 系转 case when 判空）、单参 `isnull(x)`（mysql 返回 0/1 语义）、`sys_timestamp`（oracle 系透传、mysql 系保留小数秒精度、sqlserver 用 sysdatetime）、`strpos(str,sub)`（pg 系/clickhouse 透传，其余转 instr）、`substr(s,-n)` 负起点、`curdate()`/`CURRENT_DATE` 新函数类（oracle 系转 `TRUNC(CURRENT_DATE)`，db2 用 CURRENT DATE 关键字体，sqlite 取本地时钟）；
- `group_concat`/`listagg`/`string_agg` 支持 `within group (order by ...)` 尾部子句、参数内嵌 order by 与 DISTINCT 前缀识别；
- `datediff(month,...)` 月差口径统一为年月分量差（不再按 oracle MONTHS_BETWEEN 小数口径注册）；`to_char` 转 sqlserver 改以 FORMAT 承担，修复大写格式 token（如 `YYYY-MM-DD HH24:MI:SS`）的错值；sqlite 目标 `now()`/`CURRENT_DATE`/`CURRENT_TIMESTAMP` 统一取本地时钟。

**修复**

- 修复 SubStr 负起点与 mysql 契约偏离的静默错值（pg 系/sqlserver/h2/db2/hana 四处：起点算出小于 1 时统一返回空串）；
- 修复无分钟格式（如 `yyyy-MM-dd HH`）的独立 HH 时间 token 在 pg/oracle 系按 12 小时制解释导致分桶边界错乱的问题。

**配套工具**

- 配套的 quickvo-maven-plugin 升级至 **2.0.2**。

## 七、6.0.5 更新说明

6.0.5 在 6.0.4 基础上进一步增强，同样为**增量能力，无需改动既有代码**：

**新增数据库支持（方言总数 24 → 25，详见[支持的数据库](introduction/db_list.md)）**

- **瀚高 HighGo**：PG12 内核 + oracle 兼容层，SQL 生成层复用 PostgreSQL 系（`HighgoDialect extends PostgreSqlDialect`），差异集中在函数面（无 `uuid()`/`gen_random_uuid()` 但有 `sys_guid()`、`last_day`/`add_months`/`trunc` 原生、无 `listagg` 而 `string_agg` 原生），由函数适配器 HIGHGO 分支承担；同时支持官方驱动 URL `jdbc:highgo://` 与 vanilla pg 驱动（经 `version()` 内核探测区分）。

**跨数据库函数适配完善（详见[方言自适配与函数扩展](dialect/sqltoy_function.md)）**

- 新增 11 个函数类（均默认注册进 default）：`find_in_set`、`uuid`（唯一 id 生成）、`year/month/day` 分量提取、`last_day/eomonth`、`add_months`、`date_add/date_sub/dateadd` 日期区间加减、`left/right`、`lpad/rpad`、`extract/date_part`、`trunc/date_trunc` 日期截断、`mod` 取模；
- 既有函数源拼写扩充：`instr` 补 `locate/posstr`、`length` 补 `character_length/octet_length`、`now` 补 `current_timestamp`、`if` 补 `iif`、`substr` 补 `mid`、`to_date` 补 `str_to_date`；
- 均经多数据库真库探针验证，无法安全转换的形态保持"响亮保留"（原样交目标库报错），避免静默错值。

**主键插入返回值转小写（PostgreSQL 系）**

- 单行插入返回主键值时的主键列名大小写转换（`getReturnPrimaryKeyColumnCase`）由原仅 PostgreSQL/PostgreSQL14 扩展到 **PG 折叠家族**全量：OpenGauss、GaussDB、MogDB、Vastbase、StarDB、Oscar、Kingbase、HighGo 一并转小写。原因：`getGeneratedKeys` 列提示在 PG 折叠内核上大小写敏感（如 opengauss/vastbase/highgo 的 "ID"/"Id" 报 column does not exist、kingbase 混合大小写报错），转小写对全家族安全；mysql 系/tidb/oceanbase/sqlserver/db2/dm/oracle 维持 DEFAULT（驱动忽略提示或折叠一致）。仍可通过 `dialectReturnPrimaryColumnCase` 配置按方言覆盖。

**其他优化与修复**

- 修复串首裸函数永不转换的缺陷（整条 sql 即函数表达式时适配正则 `\W(函数名)\(` 恒不命中，入口加空格哨兵）；
- 补齐 HIGHGO/H2/SQLITE 的 TO_DATE/TO_TIMESTAMP cast 族处理。

## 八、6.0.6 更新说明

6.0.6 在 6.0.5 基础上进一步增强，同样为**增量能力，无需改动既有代码**：

**虚表宏 @virtualTable()（详见[方言自适配与函数扩展](dialect/sqltoy_function.md)）**

- 解决"select 常量行 union 真实查询"类 sql（字典下拉兜底行、报表固定合计行等）跨数据库无法统一编写的问题：oracle/db2/hana 必须挂伪表（`from dual` / `from sysibm.sysdummy1` / `from dummy`），而 mysql/pg/sqlserver 等原生支持无 from 的 select（写 `from dual` 反而语法错）；
- 统一写法：`select '0' id,'全局公共' name @virtualTable() union select id,name from t`，sql 解析期按方言自动展开——oracle 系（oracle/oracle11/dm/oceanbase）→ `from dual`、db2 → `from sysibm.sysdummy1`、hana → `from dummy`、其余方言直接剔除；
- 兼容别名 `@dual()` / `@dummyTable()`，三名等价、大小写不敏感、括号内空白容错；同一条 sql 可出现多次（每个常量 select 各写一个）；
- xml 配置 sql、`@Sql` 注解 sql、代码 sql（`findBySql` 等）同样有效（统一解析管线）；不含宏的 sql 零影响（含 `@` 的普通 sql 如 email 不受影响）；
- 展开发生在解析期并随 SqlToyConfig 固化（与函数/保留字转换同一时机），运行期零开销；`realDialectFirst` 场景宏按解析方言展开，运行期惰性层不再重复展开。

**配套工具**

- 配套的 quickvo-maven-plugin 升级至 **2.0.3**。

## 九、6.0.7 更新说明

6.0.7 在 6.0.6 基础上进一步增强，同样为**增量能力，无需改动既有代码**：

**JSON 库可插拔（JsonProvider SPI）**

- sqltoy 不再硬绑 fastjson2：JSON/JSONB 列映射、缓存翻译的 rest/service 路径、以及 Elasticsearch 全栈（含 jwt 认证）统一改为委托 `org.sagacity.sqltoy.plugins.json.JsonProvider`，内置 fastjson2 / jackson3（`tools.jackson`）/ jackson2（`com.fasterxml`）三个实现；
- 解析顺序为 `spring.sqltoy.jsonProvider` 显式配置 > classpath 自动探测 fastjson2 → jackson3 → jackson2。fastjson2 居首是为了让此前就跑通 JSON 列的存量项目行为完全不变；
- 配置取值支持内置别名 `fastjson2` / `jackson3` / `jackson2`（大小写、连字符、首尾空格不敏感），或自定义实现的全限定类名；
- 探测到的候选须先通过一次冒烟解析才被采纳——库在 classpath 上并不等于可用（例如 jackson3 的 databind 需要 `jackson-annotations` 2.20+，与 jackson2 共存时旧版本会在冲突仲裁中胜出并抛 `NoSuchFieldError: POJO`），不可用时记 WARN 并降级到下一个候选，marker 类不存在时静默跳过；
- 启动期即尝试初始化：显式配置非法或不可用时**直接失败并保留根因**（不静默回落，否则配置形同虚设）；仅缺可用 JSON 库时只记 WARN、不阻断启动——**不用 JSON 列与 ES 特性的项目现在无需引入任何 JSON 库**，触及 JSON 功能时才抛出带明确指引的异常，替代原先的 `NoClassDefFoundError`；
- core 的 jackson2 / jackson3 依赖均为 `provided + optional`，不传递给使用方；
- 详见[配置说明](config/sqltoy_config.md)与 [Elasticsearch](nosql/sqltoy_elasticsearch.md)。

**字段名列表拼接宏 @joinFields()（详见[补充说明：标签与表达式参考](appendix/tags.md)）**

- 面向页面配置化的报表与接口服务：由配置决定 `select` / `group by` / `order by` 的列。写法 `@joinFields(:fields,default)`，也可在 sql 里直写位置参数形态 `@joinFields(?,default)`——它与 `@value` 处于同一处理位置，命名参数转成 `?` 后两种写法完全等价，被消费的参数会从参数集合中剔除、不影响其余 `?` 的对位；
- `fields` 为 null、空集合或全空白时输出 `default`；`default` 取自 sql 文本（开发者编写，可信）原样输出、不做标识符校验，因此可写 `t.*` 或 `sum(t.amount)`，含逗号或括号时用 `{}`、`''` 或 `""` 包裹；未提供 `default` 则输出空串；
- 入参归一：单个字符串或长度为 1 的数组按逗号切割（页面多选常序列化成 `["a,b,c"]`），长度大于 1 时元素即字段、不做二次切割，因此 `["a,b","c"]` 会因 `"a,b"` 非法而报错，而不是被静默拆成三个字段；空白段跳过以容忍尾逗号；
- 安全：字段名走字符白名单（字母含中文、数字、下划线，最多三段点号限定 `schema.table.column`），显式排除 `$` 与 `#`（与自身的 `#[]` 动态段和 `${}`/`#{}` 参数占位冲突）以及空白、引号、括号、分号、逗号、注释符、反斜杠；非法值直接抛异常并带上具体值，不做静默清洗（经 DAO 层会被包装成 `DataAccessException`，捕获时取根因）；
- 合法字段按方言仅对**保留字**加引用符（mysql 系反引号、oracle/pg 系双引号、sqlserver 方括号），非保留字保持裸标识符，以规避 oracle/pg 上引号引入的大小写敏感；点号限定名逐段处理，`t.order` 的列段同样会被引用；
- **前提**：保留字引用依赖 `spring.sqltoy.reservedWords` 配置，而该配置**无默认值**；未配置时保留字集合为空、`convertWord` 原样返回不加引用符，字段列表含保留字（`order`/`desc`/`level`/`group` 等）会产出裸标识符并被数据库拒绝——PostgreSQL、MySQL 9、SQL Server 2025 三库实测均报语法错误；
- 只受理纯标识符，`sum(col)`、`col as alias` 这类表达式仍用 `@value`（安全自负）；运算符写法（`a % b`、`a || b`）不是函数调用，同样不在受理范围；
- 已在 PostgreSQL、MySQL 9、SQL Server 2025 三个真实数据库上完成端到端验证（普通列、default 回退、group by 聚合、保留字列、注入拦截）。

**`#[]` 剔除后自动清理括号组内悬挂的 and/or**

- 形如 `#[and ( #[t.a=:a] #[or t.b=:b] )]` 的写法，在 `a` 为 null 时既往会展开成 `and ( or t.b=:b )` 的残缺 SQL；现剔除完成后统一清理括号内 trim 后的、以 `and`/`or` 开头或结尾的悬挂连接符，使括号组各成员可独立可选（`and|or` 后紧跟 `\s+` 或 `)` 才命中，`( order by ...)` 这类以 `or` 开头的关键字不受影响），详见[动态 SQL 编写规范](query/dynamic_sql.md)。

## 十、6.0.8 更新说明

6.0.8 是 6.0 线里**变更最重的一个版本**：lambda 条件体系并入核心、GraalVM AOT 重写。**纯 JVM 运行的项目无需改动代码**；使用 sqltoy-plus 的项目按第 2 条迁移；构建 native 镜像的项目需按第 4 条检查构建环境。

**1. lambda 条件体系并入核心（详见[Lambda 条件查询与更新](query/lambda_query.md)）**

- 新增包 `org.sagacity.sqltoy.lambda`：`LambdaQuery` / `LambdaUpdate` / `LambdaDelete` + `JoinCol` / `ExcludeCols` / `LambdaFn` / `OuterRef` 等，以实体属性方法引用（`User::getStatus`）表达条件；
- `LightDao` 新增三个 default 工厂 `lambdaQuery/lambdaUpdate/lambdaDelete(Class)`，执行全部由构建器终端完成（`find/getOne/findPage/count/exists/update/delete`），也可 `LambdaQuery.create(entityClass).bind(lightDao)` 先构建后执行；
- **单表只是 join 的退化形态**：不调用 join 步骤即走单表通道（条件转 `EntityQuery`/`EntityUpdate`，复用 `findEntity`/`findPageEntity`/`getCount`/`deleteByQuery`/`updateByQuery` 链路，分片/缓存翻译/加解密脱敏/租户过滤全部继承）；调用 `leftJoin/rightJoin/innerJoin` + `on` 即切换 join 通道（生成完整 SQL 走 `find`/`findPage`/`getCount`，支持 `select/selectAll(ExcludeCols...)/JoinCol.of|avg|count|sum|min|max|distinct().as()`、CTE/`@fast` 下推/UNION）；
- 行为差异（**需要留意**）：`getOne()` 严格语义——0 条返回 null、多于 1 条抛 `DataAccessException`（不再静默取第一条）；按条件 `update/delete` 无任何 where 时默认抛异常，需显式 `matchAll()` 放行；
- 条件参数名由 sqltoy-plus 的 `type.valuePairs.MPG1` 形式改为全构建器唯一且跨嵌套共享序号的 `:p1…:pN`——**断言 SQL 文本的单元测试需同步**；`having`/`inSql` 的外部参数请避开 `p` + 纯数字形式；
- 值过滤由 sqltoy-plus 的全局静态策略改为**构建器实例级** `valueFilter(...)`（默认滤 null，须在添加条件之前设置）；
- `LambdaUpdate.setExpr(字段, 表达式[, value])` 支持基于字段当前值的表达式更新（如 `setExpr(User::getLoginCount, "loginCount + 1")`），复用 `updateByQuery` 既有的"字段=表达式"形态。

**2. 自 sqltoy-plus 迁移清单**

| 迁移点 | 动作 |
| --- | --- |
| 依赖 | 移除 `sqltoy-plus` 依赖（能力已内置 core），不再需要 `@EnableSqlToyPlus` 与映射策略 Bean |
| import | `com.sagframe.sagacity.sqltoy.plus.*` → `org.sagacity.sqltoy.lambda.*` |
| 类名 | `LambdaQueryWrapper`/`LambdaUpdateWrapper` → `LambdaQuery`/`LambdaUpdate`；`LambdaColumn` → `JoinCol`；`SFunction` → `LambdaFn`；`FiledNature` → `record FieldNature(entityClass, fieldName)` |
| DAO | `SqlToyPlusDao.findList/findOne/findPage/count/exists/delete/update(wrapper)` → 构建器终端；`SqlToyHelperDao` 已删除 |
| 入口 | `Wrappers.lambdaQuery(cls)` → `LambdaQuery.create(cls)` 或 `lightDao.lambdaQuery(cls)`；`lambdaQueryChain/lambdaUpdateChain` → `lightDao.lambdaQuery/lambdaUpdate` |
| 多表 | `Wrappers.lambdaMultiWrapper(toClass).select(...).from(...)` → `lightDao.lambdaQuery(toClass)[.select(JoinCol...)].from(...).leftJoin(...).on(...)`；`lambdaUpdateMultiWrapper/lambdaDeleteMultiWrapper` → `lightDao.lambdaUpdate/lambdaDelete` + join 步骤 |
| 参数名 | `type.valuePairs.MPG1` → `:p1…` |
| 字符串 wrapper | `QueryWrapper` 等不再提供：单表字符串条件用 `EntityQuery`，复杂动态用 SQL 模式 |

> 更完整的字段级对照见 [Lambda 条件查询与更新 · 九、自 sqltoy-plus 迁移对照](query/lambda_query.md)。

**3. 多表 join 更新与删除**

join 更新/删除并入 `lambdaUpdate()/lambdaDelete()`（与查询同款"不调 join 即单表"判定）：join 更新生成 `UPDATE 主表 别名 JOIN ... SET 别名.字段=:p WHERE ...`、join 删除生成 `DELETE 别名[,...] FROM 主表 别名 JOIN ... WHERE ...`（`deleteTables` 缺省主表），均经 `executeSql` 执行。关系型库采用可移植的 EXISTS-over-derived 改写，已在 mysql/postgresql/sqlserver/oracle/db2 等真库验证；clickhouse/doris/starrocks 等无事务性行级 DML 能力的库不支持。**整对象并入更新不支持 join 通道**（用 `lightDao.update(entity)`）。

**4. GraalVM native / AOT 重写（详见[GraalVM Native Image 指引](tools/graalvm_native.md)）**

- 修复 5.6 以来 **AOT 实体反射 hints 恒为空**的缺陷：AOT 期 Spring 不注册 `BeanPostProcessor`、不预实例化单例，原先从 `getBean` 拿到的 `SqlToyContextProperties` 是未绑定的空实例，导致实体 hints 全丢；现改为经 `Binder` 从 `Environment` 直接绑定 `spring.sqltoy` 配置，按 `packagesToScan`/`annotatedClasses` 用 `EntityScanner` 扫描实体。**native 场景必须配置 `packagesToScan`**；
- 按配置**动态注册**：资源 pattern（`sqlResourcesDir` 多目录/`sqlResources`/`translateConfig`/密钥文件）、15 类扩展点反射（`unifyFieldsHandler`、`typeHandler`、`sqlInterceptors`、`sqlFormater`、`translateCacheManager`、`dataSourceSelector`、`connectionFactory`、`fieldsSecureProvider`、`desensitizeProvider`、`customFilterHandler`、`overTimeSqlHandler`、`dialectDDLGenerator`、`firstBizCodeTrace`、`dynamicCacheFetch`、`dynamicFecthCacheManager`）、经 `FunctionUtils.resolveFunctionClassNames` 解析后的 `functionConverts` 函数类、`lambda` 的 `SerializedLambda`/镜像类序列化，以及 XML 解析反射赋值的 8 个模型类（unpivot/环比/tree-sort 等标签属性，缺失时会**静默丢失**）；
- 按 **classpath 条件注册**（native 镜像构建期冻结，运行期无法再切换）：`cacheType` 对应的 caffeine/ehcache 管理器、mongo/redis 集成类、JSON 三个 provider、PG 系 `PGobject` 的 5 个驱动同构类（postgresql/opengauss/vastbase/gaussdb/kingbase）、mssql `Geometry`/`Vector`、`oracle.jdbc.OracleTypes`；
- 新增配置 `native-reflection-classes` / `native-reflection-packages`（登记非实体 DTO/VO）与 `native-entity-proxies`（构建期预生成 `updateSaveFetch` 代理，需应用自行引入 `net.bytebuddy:byte-buddy`）；
- starter 的 `sqlToyLazyDao`/`sqlToyDao`/`lightDao`/`sqlToyCRUDService` 四个 `@Bean` 返回类型由接口改为**具体实现类**并显式 `@ConditionalOnMissingBean(接口.class)`：Spring AOT 按声明类型预判 bean 类型，接口声明会使事务 CGLIB 代理无法在构建期预生成，native 运行期报 "CGLIB runtime enhancement not supported on native image"；应用侧如有"接口返回类型 + `initMethod`"的 `@Bean`，同样应改为具体类型声明；
- **构建环境要求 GraalVM 25+**（实测矩阵：17 与 23 不识别新版 reachability-metadata schema，被 native-maven-plugin 直接拒绝；21 不支持 `typeReached` 条件元数据，条件恒真导致 spring-aop 的 AspectJ 序列化条目被误注册；25.0.4 双框架全矩阵验证）；
- 已知限制：`updateSaveFetch` 的 `EntityUpdateCallback` 路径依赖 byte-buddy 运行期生成实体子类，native 下需配置 `native-entity-proxies` 预生成代理，未列出的实体不可用（insert 分支不受影响）。

**5. 配套验证工程**

新增 [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify)（spring + solon 双栈共用矩阵，PostgreSQL pgvector + postgis）：覆盖 CRUD × json/vector/geometry 三形态、`functionConverts` 方言转换、ehcache/caffeine 双缓存翻译、`updateSaveFetch` 代理路径、lambda 单表/join/setExpr/matchAll 守卫/删除；JVM 双框架 17/17 PASS，配置 `native-entity-proxies` 后 native 冒烟 17 PASS + 0 KNOWN-LIMITATION。

## 十一、6.0.9 更新说明

6.0.9 以跨库实证修补为主，无破坏性变更，升级只需改版本号。

**1. CTE 物化 hint 按目标库保留/剔除**

`WITH xx AS [NOT] MATERIALIZED (..)` 仅 PostgreSQL 系（含 openGauss/金仓/Vastbase/GAUSSDB/瀚高）原生支持；其余库（mysql/sqlserver/oracle/db2 等）执行时框架在解析期自动剔除 hint——只失去物化优化、不改查询语义，无需再按方言各写一份 sqlId。lambda 侧 `.with(name, q, Boolean.TRUE/FALSE)` 的渲染门禁与之同源（详见[Lambda 条件查询与更新](query/lambda_query.md)）。

**2. 函数适配真库实证修正**

- `to_char`/`to_date`/`str_to_date` 的裸 `HH` 全库统一为 **24 小时制**口径（小写 `hh` 为 12 小时、`HH24` 恒为 24）——DB2/H2 真库实测原先按 12 小时输出致静默错值；
- `to_date` 目标为 pg 系/HANA/ClickHouse 且格式含时间 token 时自动改写 `to_timestamp`/`toDateTime`，规避时间部分被静默截断（真库实证 pg 的 `to_date` 只返回 date）；
- `trim(from x)`（省略剔除字符形态）在 mysql 9.3 报 1064、oracle 23ai 报 ORA-30000，自动改写为等价的 `trim(x)`/`ltrim`/`rtrim`；
- `substr` 起点 0 统一按"从开头截取"；sqlite 目标下 `mid` 自动转 `substr`（sqlite 原生无 mid）；mysql 的 `left/right(str,0)` 与负数长度按"返回空串"对齐；
- `instr` 支持四参形态 `instr(str,sub,pos,occurrence)`；
- `find_in_set` 比较符扩展为任意位置口径：`=1/=2/>1/<3` 按整数位置表达式改写（原 `>0/=0` 布尔口径族不变）；
- `datediff` 的 oceanbase 并入 oracle 分支（OB oracle 模式租户无 datediff；mysql 模式按约定配 `dialect=mysql`）。

**3. 分页 count 缓存按方言隔离**

`pageOptimize` 的总数缓存键由 sqlId 升级为 `sqlId@dialect`：同一 sql 经 `redoDataSources`/多数据源在不同方言库上执行时，count 结果分别缓存、不再互相串用；`PageOptimizeUtils.remove(sqlId)` 连带清除该 sql 全部方言缓存。配套修复跨库适配自定义 countSql 时直接改写共享 `SqlToyConfig` 实例、污染同 sqlId 后续查询的缺陷。

**4. lambda 条件体系细化**

- 新增 `likeExact/likeExactLeft/likeExactRight`：值中的 `%` 先转义为字面量再按方向补 `%`——用户输入含 `%` 时按普通字符匹配而非被当通配符放大命中范围（`like/likeLeft/likeRight` 语义不变）；
- `setExpr` 表达式引号内含字面量 `?` 时快速失败（更新通道做全量 `?` 文本替换，引号内 `?` 会被误当参数位）；
- 空 groupBy 列与空 having 条件跳过组装（原会生成 `GROUP BY `/`HAVING ` 非法片段）。

**5. 其他**

- SqlScriptLoader 初始化/销毁线程安全加固（标志 volatile 化、方法 synchronized）。

## 十二、升级步骤建议

1. 依赖版本号统一升级为 6.0.9（starter / spring / solon-plugin 与 core 同版本）；
2. 全局搜索 `parallQuery` / `ParallQuery`，改为 `parallelQuery` / `ParallelQuery`（IDE 重命名即可）；
3. 如有自定义 `DataSourceCallbackHandler` 实现，把 `doConnection` 签名调整为 `DBProfile` 参数；
4. 如引用了上表所列框架内部工具类，按新包位置调整 import；
5. **使用 sqltoy-plus 的项目**：按第十节第 2 条清单迁移到 `org.sagacity.sqltoy.lambda`，移除 sqltoy-plus 依赖与 `@EnableSqlToyPlus`，并回归 `getOne()` 多处匹配、无条件 update/delete 两类行为变化；
6. **构建 native 镜像的项目**：确认 GraalVM 25+、配置 `packagesToScan`、按需登记 `native-reflection-classes/packages`，用到 `updateSaveFetch` 的实体加入 `native-entity-proxies`；
7. 启动验证：观察 debug 模式下 SQL 输出与业务回归（缓存翻译、分页、并行查询、lambda 条件优先）；断言 SQL 文本的单元测试需同步 `:p1…` 参数名。
