# sqltoy 功能清单

sqltoy 以最佳的动态 sql 编写模式为起点，融合 JPA 对象化操作与最强原生 sql 查询能力。以下按类别列出完整功能清单，每项均可跳转到对应章节查看详情。

## 一、对象操作（JPA 风格）

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| 对象化 CRUD | save / saveAll / update / delete / load 等完整接口（LightDao 约 110 个方法），POJO 由 quickvo 生成并带映射注解 | [对象化 CRUD](../crud/sqltoy_crud.md) |
| 弹性更新 | 一次数据库交互完成修改（区别于 hibernate 先 load 再改），null 字段不参与更新，保障高并发下数据准确 | [对象化 CRUD](../crud/sqltoy_crud.md) |
| updateFetch | 锁查询 → 逻辑校验 → 修改 → 返回最新结果，一次交互完成；秒杀、库存台账、资金台账场景 | [对象化 CRUD](../crud/sqltoy_crud.md) |
| updateSaveFetch | 锁查询、记录不存在则插入、存在则修改，并返回修改后结果 | [对象化 CRUD](../crud/sqltoy_crud.md) |
| updateByQuery | 基于单表条件批量更新，支持 `set 字段=字段+?` 依据字段值计算的自更新模式 | [对象化 CRUD](../crud/sqltoy_crud.md) |
| 级联操作 | `@OneToOne`/`@OneToMany` 级联保存、加载（支持过滤/排序）、修改、删除，批量级联底层 in 查询优化 | [对象化 CRUD](../crud/sqltoy_crud.md) |
| 查询层次封装 | 一条 join SQL 按注解自动把主子表结果封装为父子对象（1..n 层级） | [常规查询 API](../query/sqltoy_query.md) |
| 树形表路由 | `wrapTreeTableRoute` 构造节点路径/层级/叶子标记，非递归查询整棵子树 | [树形表路由](../crud/tree_table.md) |
| 主键策略 | 22 位/26 位有序数字、雪花、UUIDv7、ULID、sequence/identity、redis 规则业务单据号，支持自定义扩展 | [主键策略](../primarykey/sqltoy_primarykey.md) |
| 数据版本控制 | `@DataVersion` 乐观锁，防止并发修改覆盖 | [数据版本控制](../enterprise/data_version.md) |
| 公共字段赋值 | 创建人/修改人/创建时间/修改时间/租户统一补漏赋值（可暂停/恢复） | [公共字段处理](../quickstart/helloworld_improve.md) |

## 二、SQL 查询

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| 动态 SQL | `#[]` 条件片段 + `@if/@loop/@include` 宏 + filters 参数规整；带动态片段的 SQL 可直接在数据库客户端执行调试 | [动态 SQL](../query/dynamic_sql.md) |
| filters 过滤器 | eq/between/to-date/to-number/split/primary（首要参数）/cache-arg（缓存反向匹配替代 like）等 20+ 种 | [动态 SQL](../query/dynamic_sql.md) |
| 多形态查询 API | findOne / find / findPage / findTop / findRandom / getValue / getCount / isUnique / loadByQuery / findEntity（单表 EntityQuery 快捷查询） | [常规查询 API](../query/sqltoy_query.md) |
| 缓存翻译 | 码值→名称免 join；API 直取缓存供下拉框等组件；反向匹配 key；支持条件翻译、多值拆分、租户隔离、i18n；超大规模数据按需动态加载只保留常用数据 | [缓存翻译使用](../quickstart/translates.md) |
| 分页 | 自动 count 优化 + page-optimize 缓存分页 + `@fast` 快速分页（先分页后关联）+ 并行分页 + 自定义 count-sql | [分页优化](../query/pagination.md) |
| 层次化查询 | findByQuery + hiberarchy 按注解自动分层封装 | [常规查询 API](../query/sqltoy_query.md) |
| 并行查询 | parallelQuery 同时执行多个无依赖 SQL（可混合分页），提升页面整体响应 | [并行查询](../query/parallel_query.md) |
| 存储过程 | executeStore / executeMoreResultStore，支持 out 参数与多结果集 | [存储过程](../query/store_procedure.md) |
| 流式查询 | fetchStream 超大数据量逐行回调，不撑爆内存 | [常规查询 API](../query/sqltoy_query.md) |
| SQL 执行 | executeSql / batchUpdate（可并行）/ insertReturnPrimaryKey / truncate | [Link 链式操作](../query/link_api.md) |

## 三、数据分析（内存算法，跨库一致）

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| 行转列 / 列转行 | pivot / unpivot，支持动态列，几行配置完成 | [复杂查询与数据分析](../query/sqltoy_complex_query.md) |
| 分组汇总 | summary 任意层级小计/总计/求平均 | [复杂查询与数据分析](../query/sqltoy_complex_query.md) |
| 同比环比 | cols-chain-relative（列环比）/ rows-chain-relative（行环比），自动百分比输出 | [复杂查询与数据分析](../query/sqltoy_complex_query.md) |
| 树形排序汇总 | tree-sort 树形排序 + 逐层向上汇总 | [复杂查询与数据分析](../query/sqltoy_complex_query.md) |
| 分组拼接 | link 标签代替 group_concat / listagg / WM_CONCAT，跨库一致 | [复杂查询与数据分析](../query/sqltoy_complex_query.md) |
| 结果格式化 | 日期/数字格式化，支持中文大写金额（capital-rmb）等财务场景 | [动态 SQL 规范](../query/dynamic_sql.md) |

## 四、跨数据库

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| 24 种方言 | MySQL、Oracle、PostgreSQL、SQL Server、DB2、SAP HANA、达梦、金仓、OceanBase、TiDB、ClickHouse、Doris、StarRocks、TDengine 等 | [支持的数据库](db_list.md) |
| 函数自动替换 | `functionConverts=default` 开启，nvl/concat/to_char/datediff 等 16+ 函数按数据库自动适配，支持自定义扩展 | [方言与函数](../dialect/sqltoy_function.md) |
| 多方言 sqlId | `sqlId_dialect` / `dialect_sqlId` 命名，框架按当前库自动匹配专属 SQL | [方言与函数](../dialect/sqltoy_function.md) |
| 多库适配验证 | redoDataSources 让任意查询在其他库重放执行，产品化跨库测试利器 | [多库适配验证](../dialect/multi_db_verify.md) |
| 保留字兼容 | reservedWords 声明后对象操作与跨库 SQL 自动适配 | [方言与函数](../dialect/sqltoy_function.md) |

## 五、企业级特性

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| 分库分表 | 注解 + xml 双模式声明策略，按条件自动路由库/表 | [分库分表](../enterprise/sqltoy_sharding.md) |
| 多租户 | `@Tenant` + TenantFilterInterceptor 统一过滤与赋值 | [多租户支持](../enterprise/sqltoy_multitenant.md) |
| 数据权限 | 统一权限参数注入 + 越权访问校验 | [数据权限](../enterprise/sqltoy_permission.md) |
| 数据安全 | RSA 字段加解密存储与查询解密；手机号/姓名/卡号等脱敏（支持离散脱敏） | [脱敏与加解密](../enterprise/sqltoy_security.md) |
| SQL 拦截 | SqlInterceptor 集中加工 SQL（如改写 schema、注入过滤条件） | [SQL 拦截](../enterprise/sql_interceptor.md) |
| 慢 SQL | 超时阈值打印 + 慢 SQL 收集处理器（可扩展上报监控） | [慢 SQL 处理](../enterprise/slow_sql.md) |

## 六、NoSQL

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| Elasticsearch | eql 支持 sql 模式与原生 json 模式查询，分页/Top，可挂缓存翻译与脱敏 | [Elasticsearch](../nosql/sqltoy_elasticsearch.md) |
| MongoDB | mql 查询与聚合管道，fields 别名映射 + 缓存翻译 + 脱敏 | [MongoDB](../nosql/sqltoy_mongo.md) |

## 七、工程化与集成

| 特性 | 说明 | 详见 |
| --- | --- | --- |
| quickvo 代码生成 | 连接数据库按表生成带注解 POJO/VO（独立工具 + maven 插件），支持 lombok、swagger | [quickvo](../prepare/quickvo.md) / [插件](../prepare/quickvo_plugin.md) |
| 自动 DDL | autoDDL + packagesToScan 由 POJO 直接创建表结构 | [POJO 生成 DDL](../primarykey/sqltoy_ddl.md) |
| debug 模式 | 打印执行 SQL/参数/耗时，sql 文件变更自动检测热加载 | [配置参数](../config/sqltoy_config.md) |
| GraalVM AOT | spring-starter 内置 AOT 支持，Native Image 开箱即用 | [其他特性](../tools/other_features.md) |
| 对象转换 | convertType / MapperUtils 实现 DTO 与 POJO 快速互转（支持 @SqlToyFieldAlias 别名） | [工具类](../tools/utils.md) |
| 表元数据 | TableApi 获取表/列信息、truncate/drop | [TableApi](../tools/table_api.md) |
| 多框架集成 | Spring Boot starter / 传统 Spring / Solon / 纯 Java 四种接入方式 | [配置](../config/sqltoy_config.md) |
| 类型扩展 | TypeHandler 处理 JSON 等非标准类型，geometry 空间类型（JTS）支持 | [TypeHandler](../enterprise/sqltoy_typeHandler.md) / [其他特性](../tools/other_features.md) |
