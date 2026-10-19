# 版本更新日志（6.0 线）

6.0 线从 JDK 17 起（JDK 8 项目请留在 `5.6.96.jre8`）。本页是**索引**：每个版本的完整变更说明、注意事项与升级动作都在[6.0 升级指南](upgrade_6.0.md)对应章节。

| 版本 | 要点 | 详见 |
| --- | --- | --- |
| **6.0.8** | **lambda 条件体系并入核心**（`org.sagacity.sqltoy.lambda`，单表/join 一套构建器，原 sqltoy-plus 能力内建）；**GraalVM AOT 重写**（动态注册资源/扩展类/JSON/驱动类反射，新增 `native-reflection-classes`/`native-reflection-packages`/`native-entity-proxies`，修复 5.6 以来实体 hints 恒为空）；`#[...]` 剔除后清理悬挂 and/or | [十、6.0.8](upgrade_6.0.md) · [Lambda 条件](../query/lambda_query.md) · [GraalVM](../tools/graalvm_native.md) |
| **6.0.7** | JSON 库可插拔（`JsonProvider`：fastjson2/jackson3/jackson2）；新增 `@joinFields()` 字段名列表拼接宏；`#[]` 剔除后清理括号内悬挂 and/or | [九、6.0.7](upgrade_6.0.md) · [标签与表达式](../appendix/tags.md) |
| **6.0.6** | 新增虚表宏 `@virtualTable()`（兼容 `@dual()`/`@dummyTable()`），解决"常量行 union 查询"的跨库写法；quickvo-maven-plugin 2.0.3 | [八、6.0.6](upgrade_6.0.md) · [方言与函数](../dialect/sqltoy_function.md) |
| **6.0.5** | 新增瀚高 HighGo 方言（方言总数 24→25）；新增 11 个跨库函数类；PG 折叠家族（OpenGauss/GaussDB/MogDB/Vastbase/StarDB/Oscar/Kingbase/HighGo）插入返回主键列名统一转小写 | [七、6.0.5](upgrade_6.0.md) |
| **6.0.4** | 缓存翻译 rest 模式认证增强（basic/jwt，支持 token-url 登录、本地自签、静态 token）；函数适配完善（`nvl2`、负起点 `substr`、`curdate` 等）；修复 SubStr 负起点与 HH 时间 token 的静默错值 | [六、6.0.4](upgrade_6.0.md) |
| **6.0.3** | `<sql dialect="xxx">` 元素属性；`spring.sqltoy.realDialectFirst`；POJO 生成 DDL 增强（`@Partition`/`@PartitionDef`/`@MppTable`、Doris/StarRocks/ClickHouse/DB2/HANA/SQLite 专用生成器、`@Foreign` 参照动作）；分库分表并行执行修复 | [五、6.0.3](upgrade_6.0.md) · [POJO 生成 DDL](../primarykey/sqltoy_ddl.md) |
| **6.0.0** | JDK 17+；API 更名 `parallQuery`→`parallelQuery`（`ParallelQuery`）、`doConnection(conn, DBProfile)`；包结构调整（`PageOptimizeUtils`/`ParallelUtils`/`TranslateUtils` 等迁移）；新增 SAP HANA 方言 | [二、API 变更](upgrade_6.0.md) · [三、包结构调整](upgrade_6.0.md) |
| 5.6.96.jre8 | JDK 8 的最终版本（仍支持 quickvo-maven-plugin） | [环境要求](upgrade_6.0.md) |

## 怎么看某个版本改了什么

1. 本页定位版本 → 点"详见"进升级指南对应章节；
2. 需要**逐行细节**（每个 bug 的根因、验证数据库、测试用例）看源码仓库的 `trunk/sqltoy-orm-core/changelog.md`；
3. 需要**是否要改代码**的结论：升级指南第二节（API 变更）、第三节（包结构调整），其余为增量能力。

## 版本选择建议

| 场景 | 建议 |
| --- | --- |
| 新项目 | 直接用最新 6.0.x |
| 存量 5.6.x（JDK 8） | 保持 `5.6.96.jre8`，不要为了升级而升级 JDK |
| 存量 5.6.x（JDK 17） | 按[升级指南](upgrade_6.0.md)一到十一节顺序评估，重点看 6.0.0 的 API/包变更 |
| 使用 sqltoy-plus | 升到 6.0.8，按[升级指南第十节第 2 条](upgrade_6.0.md)迁移到内置 lambda |
| 要构建 native 镜像 | 6.0.8+，且 GraalVM 23+ |

> 历史版本（5.x 及更早）的变更请查阅源码仓库 changelog；本页只维护 6.0 线。
