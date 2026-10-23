# 换库迁移适配指引

本章面向**数据库换库迁移**场景（从 Oracle、MySQL 等迁移到达梦、金仓、瀚高、神通、MogDB、Vastbase、GaussDB、OpenGauss 等国产数据库），把 sqltoy 的跨数据库适配能力整理为「评估 → 配置 → 改造 → 验证 → 性能 → 切换」六步可执行清单；每步的原理与完整参数说明见对应章节链接。选型论证与整体介绍见源码仓库 `docs/multi-db-adaptation.md`（README「文档与资源」表有入口）。

## 一、评估先行：摸清适配面

1. **SQL 来源分类**：对象操作（save/update/delete/load/updateFetch 等）的分页、锁、merge、主键回填由框架按方言生成，**无需改造**；真正需要评估的是自定义 sql（xml 配置、`@Sql` 注解、代码 sql 三种形态，见[动态 SQL 编写规范](query/dynamic_sql.md)）；
2. **确认目标库覆盖**：方言清单见[支持的数据库](introduction/db_list.md)；未单独列出方言的国产库（尤其 PostgreSQL 系衍生库）先以 `dialect` / `dialectMap` 别名到最接近的方言上线：

```properties
spring.sqltoy.dialectMap.kingbase=mysql
```

3. **主键策略评估**：`identity`/`sequence` 在各库存在方言与大小写差异，换库迁移建议改用程序化主键（22 位/26 位/雪花/UUID）从源头消除，见[主键策略](primarykey/sqltoy_primarykey.md)；存量 sequence 表可继续使用，框架按方言处理回填。

## 二、配置层：开启跨库适配能力

```properties
# 跨库函数自动适配（内置 28 个函数）
spring.sqltoy.functionConverts=default
# 项目中使用到的保留字，对象操作与跨库 SQL 自动适配
spring.sqltoy.reservedWords=maxvalue,minvalue
# 代理库/配置方言与真实方言不一致场景（如 OceanBase 按 mysql 配置），变体查找跟随真实方言
spring.sqltoy.realDialectFirst=true
```

- 函数适配覆盖 `nvl/ifnull/coalesce`、`to_char/date_format`、`decode`、`group_concat/listagg/string_agg`、`sysdate/now/current_timestamp`、`trunc/date_trunc`、`uuid`、`date_add` 等常见差异；不能安全转换的形态**响亮保留**（原样交目标库报错），绝不静默改写，见[方言自适配与函数扩展](dialect/sqltoy_function.md)；
- `<sql dialect="...">` 按指定方言固化解析、`realDialectFirst` 真实方言优先匹配变体，同见该章 2.1、2.2 节。

## 三、SQL 改造层：按差异类型分类处理

| 差异类型 | 典型表现 | 处理方式 |
| --- | --- | --- |
| 函数差异 | `nvl`、`decode`、`to_char`、`sysdate`、`group_concat` | `functionConverts=default` 自动适配，无需人工 |
| 伪表 | oracle 系必须 `from dual`，pg/mysql/sqlserver 写了反而报错 | 6.0.6 起用 `@virtualTable()` 宏，解析期按方言展开或剔除 |
| 结构性差异 | oracle `connect by` 与递归 CTE、库专属 hint 等 | 方言变体 `sqlId_dialect` / `dialect_sqlId`，框架按当前库自动选取 |
| 主键返回大小写 | PG 折叠家族 `getGeneratedKeys` 列提示大小写敏感 | 框架默认对 PG 折叠家族转小写；可以 `dialectReturnPrimaryColumnCase` 按方言覆盖 |
| 建表 DDL | 各库类型、分区语法差异 | POJO 注解 + quickvo 按库生成 DDL，见[POJO 生成表结构 DDL](primarykey/sqltoy_ddl.md) |

伪表宏写法（展开规则详见[方言自适配与函数扩展](dialect/sqltoy_function.md) 第 3 节）：

```sql
select '0' id,'全局公共' name @virtualTable()
union
select id,name from sys_tenant_info
```

结构性差异写法：为 sqlId 挂方言变体，业务代码只调基础 sqlId，查找顺序 `dialect_sqlId → sqlId_dialect → sqlId`：

```xml
<!-- 基础版（递归 CTE）：pg / mysql8+ / 达梦 / 金仓等执行本条 -->
<sql id="dept_sub_tree">…递归 CTE…</sql>
<!-- oracle 环境自动命中本条：connect by 层次查询 -->
<sql id="dept_sub_tree_oracle">…connect by…</sql>
```

## 四、验证层：上线前把所有目标库跑一遍

```properties
spring.sqltoy.redoDataSources[0]=dmdb
spring.sqltoy.redoDataSources[1]=kingbasedb
```

配置后任意查询在测试阶段**同时在上述数据源重放执行一次**，不兼容写法当场暴露，而不是等客户现场换库时才报错，见[多种数据库适配验证](dialect/multi_db_verify.md)。与之配套的两层框架保障：

- 各方言的分页/锁/merge/sequence 经真库探针逐项验证，并以反射穷举断言锁定覆盖完整性（新增数据库类型漏登记适配时测试直接失败）；
- 函数转换的"响亮保留"原则保证验证期报错即适配面清单，不存在静默错值。

## 五、性能层：迁移后性能不降反升

- **分页**：`findPage` 默认启用智能 count 优化（剔除 order by、裁剪 select 列）；频繁翻页场景加 `<page-optimize parallel="true" alive-max="100" alive-seconds="120"/>` 缓存 count 并并行执行；大表 join 分页用 `@fast()` 先分页后关联，见[分页优化](query/pagination.md)；
- **缓存翻译**：码值转名称在内存完成，消灭字典表 JOIN，支持增量更新与 FIFO 超大规模主数据缓存，见[缓存翻译使用](quickstart/translates.md)；
- **高并发台账**：`updateFetch` / `updateSaveFetch` 一次数据库交互完成锁查询→校验→修改→返回，见[对象化 CRUD](crud/sqltoy_crud.md)；
- **慢 SQL 治理**：慢 SQL 自动识别处理，见[慢 SQL 处理](enterprise/slow_sql.md)；SQL 签名（`/*-id-*/`）便于数据库日志秒级定位。

## 六、切换与长期运维

- 并行期结合[多数据源与事务](config/dynamic_datasource.md)按数据源灰度切换；
- 新国产库出现时先以 `dialectMap` 别名接入，官方方言支持后移除别名即获原生适配；
- 将 `redoDataSources` 保留在回归环境，作为跨库适配的长期门禁。

## 七、相关章节

- [支持的数据库](introduction/db_list.md) · [方言自适配与函数扩展](dialect/sqltoy_function.md) · [多种数据库适配验证](dialect/multi_db_verify.md)
- [分页优化](query/pagination.md) · [缓存翻译使用](quickstart/translates.md) · [主键策略](primarykey/sqltoy_primarykey.md) · [POJO 生成表结构 DDL](primarykey/sqltoy_ddl.md)
