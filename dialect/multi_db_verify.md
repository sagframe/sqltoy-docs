# 多种数据库适配验证

sqltoy 自 2008 年立项起就提倡**产品化**：一套软件产品适配多种数据库（如 CRM 同时适配 Oracle、MySQL、DB2、SQL Server、PostgreSQL、达梦、高斯等），便于在不同客户场景下推广。唯有产品化才能形成真正的竞争力。

## 一、如何让 SQL 适配多种数据库

1. **主键策略**：少用与数据库强相关的 `identity`、`sequence`，优先用 sqltoy 的程序化主键（22 位/26 位/雪花/UUID 等，见[主键策略](../primarykey/sqltoy_primarykey.md)）。
2. **增删改**：使用 sqltoy 对象化操作（save/update/delete/load），由框架处理方言差异。
3. **查询**：开启 `spring.sqltoy.functionConverts=default`，实现 SQL 中函数按数据库自动适配替换（见[方言自适配与函数扩展](sqltoy_function.md)）。
4. 必要时用 `sqlId_dialect` / `dialect_sqlId` 为特定数据库提供专属 SQL。

## 二、开启跨数据库适配测试（redoDataSources）

为了在测试功能时**同时验证 SQL 在其他数据库下能否正确运行**，sqltoy 提供了 `redoDataSources` 机制：配置本产品需要适配的其他类型数据库后，任意执行一个查询，框架会**同时在 redoDataSources 数据源上也执行一次**，从而验证 SQL 的跨库适配能力。

**第 1 步：用 `@Configuration` 配置多个数据源**（关注两个针对数据源的 `@Bean` 定义），例如主库 + 一个 PostgreSQL 库 `pgdb`。

**第 2 步：配置需要验证的数据库**

```properties
spring.sqltoy.redoDataSources[0]=pgdb
```

配置后，执行任意查询功能时，sqltoy 会在 `pgdb` 上重放（redo）一次该 SQL。如果 SQL 中存在不兼容的方言写法，重放时即会暴露，便于在开发/测试阶段就发现跨库问题，而不是等到客户现场切换数据库时才报错。

> 提示：`redoDataSources` 仅用于**适配验证**，重放查询不影响主查询结果。生产环境可关闭。

## 三、相关

- 函数替换与方言 sqlId：[方言自适配与函数扩展](sqltoy_function.md)
- 未列出的 PostgreSQL 系数据库适配（dialect/dialectMap）：[常见 SQL 案例](../query/sql_showcase.md)
