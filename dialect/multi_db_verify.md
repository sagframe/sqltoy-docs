# 多种数据库适配验证

sqltoy 自 2008 年立项起就提倡**产品化**：一套软件产品适配多种数据库（如 CRM 同时适配 Oracle、MySQL、DB2、SQL Server、PostgreSQL、达梦、高斯等），便于在不同客户场景下推广。唯有产品化才能形成真正的竞争力。

## 一、如何让 SQL 适配多种数据库

1. **主键策略**：少用与数据库强相关的 `identity`、`sequence`，优先用 sqltoy 的程序化主键（22 位/26 位/雪花/UUID 等，见[主键策略](../primarykey/sqltoy_primarykey.md)）。
2. **增删改**：使用 sqltoy 对象化操作（save/update/delete/load），由框架处理方言差异。
3. **查询**：开启 `spring.sqltoy.functionConverts=default`，实现 SQL 中函数按数据库自动适配替换（见[方言自适配与函数扩展](sqltoy_function.md)）。
4. **常量行伪表**："select 常量行 union 真实查询"类写法（字典下拉兜底行、报表固定合计行等）用虚表宏 `@virtualTable()`（6.0.6 新增），解析期按方言自动展开为 `from dual` / `from sysibm.sysdummy1` / `from dummy` 或直接剔除，无需再为不同数据库维护 from dual 写法，详见[方言自适配与函数扩展](sqltoy_function.md)。
5. 必要时用 `sqlId_dialect` / `dialect_sqlId` 为特定数据库提供专属 SQL；6.0.3 起还支持在 `<sql>` 元素上声明 `dialect` 属性按指定方言固化解析，以及开启 `spring.sqltoy.realDialectFirst` 让变体查找优先跟随连接探测的真实方言，详见[方言自适配与函数扩展](sqltoy_function.md)。

## 二、开启跨数据库适配测试（redoDataSources）

为了在测试功能时**同时验证 SQL 在其他数据库下能否正确运行**，sqltoy 提供了 `redoDataSources` 机制：配置本产品需要适配的其他类型数据库后，任意执行一个查询，框架会**同时在 redoDataSources 数据源上也执行一次**，从而验证 SQL 的跨库适配能力。

**第 1 步：用 `@Configuration` 配置多个数据源**（关注两个针对数据源的 `@Bean` 定义），例如主库 + 一个 PostgreSQL 库 `pgdb`。

**第 2 步：配置需要验证的数据库**

```properties
spring.sqltoy.redoDataSources[0]=pgdb
```

配置后，执行任意查询功能时，sqltoy 会在 `pgdb` 上重放（redo）一次该 SQL。如果 SQL 中存在不兼容的方言写法，重放时即会暴露，便于在开发/测试阶段就发现跨库问题，而不是等到客户现场切换数据库时才报错。

> 提示：`redoDataSources` 仅用于**适配验证**，重放查询不影响主查询结果。生产环境可关闭。

## 三、配套工具与验证工程

| 工具 | 用途 |
| --- | --- |
| [sagacity-db-diversity](https://github.com/sagframe/sagacity-db-diversity) | **库表结构差异对比**：分别连接参考库与目标库，导出表/字段/主键/外键/索引/注释到 xml 后离线比对，支持单边连接（开发环境只能跳板机访问）、也支持对比不同时间点的导出；换库迁移前先跑一遍，把结构差异清干净 |
| [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify) | **native 构建验证矩阵**（spring + solon 双栈，PostgreSQL pgvector + postgis），同时覆盖方言函数转换与缓存翻译的双实现 |
| [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase) | 全功能特性演示工程（双 H2 库模拟分片拓扑 + Testcontainers 真 Mongo/ES）；**各数据库实测**见 [sqltoy-quickstart](https://github.com/sagframe/sqltoy-quickstart) 第 9 课：同一批函数转换 SQL 经 docker-compose 在 PostgreSQL/SQL Server/Oracle/MySQL 真库上运行 |

`redoDataSources` 的注意事项：

- 重放的是**查询**，写操作不会重放；因此它在开发/测试阶段用，生产环境建议关闭；
- 每次查询都会额外打一次库，**测试环境的耗时与连接数是翻倍的**，压测时不要开；
- 重放暴露的是"方言写法不兼容"，**不能替代业务结果校验**（同一 SQL 在不同库上语义可能有细微差异，如大小写、排序、null 排序位置）。

## 四、相关

- 函数替换与方言 sqlId：[方言自适配与函数扩展](sqltoy_function.md)
- 未列出的 PostgreSQL 系数据库适配（dialect/dialectMap）：[常见 SQL 案例](../query/sql_showcase.md)
- 换库迁移的完整评估清单：[换库迁移适配指引](../introduction/xinchuang.md)
