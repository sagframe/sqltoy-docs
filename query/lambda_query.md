# Lambda 条件查询与更新

> 自 6.0.8 起提供。以**实体属性的方法引用**（如 `StaffInfo::getStatus`）组织查询、更新、删除条件，编译期即可发现属性名拼写错误；单表与多表 join 使用同一套构建器，是否 join 由是否调用 join 步骤自动判定。

## 〇、定位与分工

sqltoy 提供三种组织查询的方式，按场景选择：

| 方式 | 适用场景 | 入口 |
| --- | --- | --- |
| **Lambda 条件**（本文） | 单表/多表 join 的常规条件查询、按条件更新删除，条件以属性引用表达 | `lightDao.lambdaQuery/lambdaUpdate/lambdaDelete` |
| **EntityQuery/EntityUpdate** | 单表字符串条件（where 文本 + 命名参数） | `lightDao.findEntity/updateByQuery` 等 |
| **SQL 模式**（sqlId + `#[...]` 动态段 + `@if` 宏） | 复杂动态 SQL、多分支条件组合、方言差异、配置化报表 | `lightDao.find/findPage` + sqlId，见[动态 SQL 编写规范](query/dynamic_sql.md) |

Lambda 层的动态化以 `IfPresent` 语法糖为推荐惯用法（见[动态化](#二动态化条件)）；**复杂动态场景不要试图在 lambda 层堆条件，直接走 SQL 模式**——动态段、宏、方言变体与热更新是 SQL 模式的既有能力。

Lambda 查询在**单表通道**把条件转换为 `EntityQuery`/`EntityUpdate`，复用实体链路的全部内核能力（分库分表、缓存翻译、加解密脱敏、租户过滤、统一更新字段）；**join 通道**拼装完整 SQL 走原生 SQL 通道，实体级增强不再生效（多表 SQL 本就无法套用单实体增强）。

---

## 一、入口与构建器

```java
LambdaQuery<T>  lightDao.lambdaQuery(Class<T> entityClass);   // 查询（单表或 join）
LambdaUpdate<T> lightDao.lambdaUpdate(Class<T> entityClass);  // 更新（单表或 join）
LambdaDelete<T> lightDao.lambdaDelete(Class<T> entityClass);  // 删除（单表或 join）
```

构建器是单一可变对象，所有方法返回自身，**链式与命令式写法可自由混写**：

```java
LambdaQuery<StaffInfo> query = lightDao.lambdaQuery(StaffInfo.class);
if (status != null) {
    query.eq(StaffInfo::getStatus, status);
}
List<StaffInfo> list = query.orderByDesc(StaffInfo::getEntryTime).find();
```

> **注**：上例的 `if` 仅为演示「构建器是单一可变对象，命令式控制流（if/for 等）可与链式自由混写」这一能力，**并非推荐拿 `if` 手动判空**。日常「参数为 null 就跳过该条件」的正常写法是 `eqIfPresent`，一行搞定、无需手写 `if`（详见后文「动态化条件」）：

```java
List<StaffInfo> list = lightDao.lambdaQuery(StaffInfo.class)
        .eqIfPresent(StaffInfo::getStatus, status)   // status 为 null 时自动跳过该条件
        .orderByDesc(StaffInfo::getEntryTime)
        .find();
```

也可以先构建后执行：`LambdaQuery.create(...)` 创建的构建器未绑定 dao，终端方法不可用，调用 `bind(lightDao)` 绑定后即可执行（适合在 service 层组装条件、跨层传递后统一执行的场景）：

```java
LambdaQuery<StaffInfo> query = LambdaQuery.create(StaffInfo.class).eq(StaffInfo::getStatus, 1);
List<StaffInfo> list = query.bind(lightDao).find();
```

> `LightDao` 上 lambda 相关方法只有三个工厂（`lambdaQuery/lambdaUpdate/lambdaDelete`），**执行全部由构建器终端完成**，dao 层不提供执行重载。

查询终端方法一览：

| 终端 | 语义 |
| --- | --- |
| `find()` | 全部符合条件的记录 |
| `getOne()` | 单条记录：**0 条返回 null，多于 1 条抛 `DataAccessException`**（匹配多条说明条件有缺陷，不静默取第一条） |
| `findPage(Page)` | 分页，`new Page(pageSize, pageNo)` |
| `findTop(n)` / `findTop(0.2)` | 前 n 条 / 前 20%（大于 1 为条数，小于 1 为比例），顺序由 `orderBy` 决定 |
| `findRandom(n)` / `findRandom(0.2)` | 随机 n 条 / 随机比例 |
| `count()` / `exists()` | 记录数 / 是否存在 |

### 指定数据源（多数据源 / 读写分离）

构建器提供 `.dataSource(DataSource)`，显式指定本次操作使用的数据源；不调用时使用 dao 的默认数据源。与 sqltoy 既有惯例一致（`EntityQuery` / `QueryExecutor` / `lightDao.update().dataSource(...)` 同款），**单表与 join 两通道的查询 / count / 更新 / 删除全部终端均生效**：

```java
// 单表查询走只读从库
List<StaffInfo> list = lightDao.lambdaQuery(StaffInfo.class)
        .dataSource(readOnlyDs).eq(StaffInfo::getStatus, 1).find();

// join 更新落到指定库
lightDao.lambdaUpdate(StaffInfo.class).dataSource(ds2)
        .leftJoin(Depart.class).on(StaffInfo::getDeptId, Depart::getId)
        .set(StaffInfo::getStatus, 2).eq(Depart::getDeptName, "研发").update();
```

> 单表通道经 `EntityQuery/EntityUpdate` 透传数据源；join 通道经 sqltoy 既有的 `query()`/`execute()` 链式构建器透传（查询/count 用 `query().dataSource(ds)`、更新/删除用 `execute().dataSource(ds)`，二者本就支持指定数据源）；多删除目标的 join 删除，其事务也使用所指定的数据源。`dataSource` 为 null 时行为与未指定完全一致。

### 分页优化（并行 count + keep-alive 缓存）

`findPage` 可通过 `.pageOptimize(PageOptimize)` 复用 sqltoy 既有的分页优化（不设置时用全局 `SqlToyConfig.pageOptimize`）。两个常用旋钮：**`parallel(true)`** 让 count 与数据查询并行；**`aliveSeconds(n)`** 把 count 结果缓存 n 秒（keep-alive），翻页时命中缓存即跳过 count 查询：

```java
Page<StaffInfo> page = lightDao.lambdaQuery(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1)
        .pageOptimize(new PageOptimize().parallel(true).aliveSeconds(120))
        .findPage(new Page(20, 1));
```

`PageOptimize` 还提供 `aliveMax`（缓存条目上限）、`skipZeroCount`（首页 count 为 0 时跳过数据查询）、`parallelMaxWaitSeconds`（并行等待上限）。单表与 join 两通道均生效（单表经 `EntityQuery` 透传、join 经 `QueryExecutor` 透传）。

---

## 二、单表查询

### 条件方法

每个条件方法都有 `(boolean condition, ...)` 重载，`condition` 为 false 时该条件不参与 SQL：

| 方法 | SQL 形态 |
| --- | --- |
| `eq / ne / gt / ge / lt / le` | `字段 = :p1`、`<>`、`>`、`>=`、`<`、`<=` |
| `between / notBetween` | `字段 BETWEEN :p1 AND :p2` |
| `like / notLike` | `字段 LIKE :p1` / `NOT LIKE :p1`，通配符 `%值%` 由框架补入参数值（包含匹配） |
| `likeLeft / likeRight` | `LIKE :p1`，参数值分别为 `%值`（以值结尾）/ `值%`（以值开头） |
| `likeExact / likeExactLeft / likeExactRight` | 同上三个方向，但值中的 `%` 先转义为字面量再补方向 `%`——用户输入含 `%` 时按普通字符匹配而非被当通配符（如搜 `"50%"` 折扣不会命中 `5xx…` 的任意串） |
| `isNull / isNotNull` | `字段 IS NULL` / `IS NOT NULL` |
| `in(Collection)` / `in(值...)` | `字段 IN (:p1)`，空集合/空数组自动跳过 |
| `notIn(Collection)` / `notIn(值...)` | `字段 NOT IN (:p1)` |
| `inSql(字段, 子查询[, 参数Map])` | `字段 IN (子查询)`，子查询的 sqltoy 命名参数经 Map 提供 |
| `inb(字段A, 字段B, 元组集合)` | 多字段元组 in：单列退化为 `字段 IN (:p1,:p2…)`；多列展开为 OR-of-ANDs `((a=:p1 AND b=:p2) OR (a=:p3 AND b=:p4)…)`，规避行值 IN 在 SQLServer/DB2 等库的方言差异 |

```java
List<StaffInfo> list = lightDao.lambdaQuery(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1)
        .like(StaffInfo::getStaffName, "张")
        // 值中的%按普通字符匹配:搜索"50%"不会把%当通配符命中"5"开头的任意串
        .likeExactRight(StaffInfo::getStaffCode, "50%")
        .between(StaffInfo::getEntryTime, start, end)
        .in(StaffInfo::getOrganId, organIds)
        .orderByDesc(StaffInfo::getEntryTime)
        .find();
```

### exists / notExists 关联子查询

子查询以 lambda 构建，关联外层列用 `OuterRef.of(外层字段)` 表达（类型安全，无需手写表名/别名）：

```java
// 单表通道:存在"状态启用且部门id匹配"的部门记录
lightDao.lambdaQuery(StaffInfo.class)
        .exists(OrganInfo.class, sub -> sub
                .eq(OrganInfo::getStatus, 1)
                .eq(OrganInfo::getOrganId, OuterRef.of(StaffInfo::getOrganId)))  // 关联外层列
        .find();
// ... WHERE ... AND EXISTS (SELECT 1 FROM organ_table sq1 WHERE sq1.STATUS = :p2 AND sq1.ORGAN_ID = staff_table.ORGAN_ID)

// join 通道同样可用,外层列渲染为外层别名(如 s1.ORGAN_ID)
lightDao.lambdaQuery(StaffInfoVO.class).selectAll()
        .from(StaffInfo.class).leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .notExists(BlackList.class, sub -> sub.eq(BlackList::getStaffId, OuterRef.of(StaffInfo::getStaffId)))
        .find();
```

约定与边界：

- `OuterRef` 仅支持 `eq/ne/gt/ge/lt/le` 六个比较方法（between/like/in 接收 OuterRef 会抛异常）；用在子查询之外也抛异常；
- 单表通道外层列渲染为 `表名.列`、join 通道渲染为 `别名.列`——子查询内必须限定，否则与子查询同名列歧义；
- 子查询表别名以 `sq` 前缀生成（sq1、sq2…），与外层单字母别名不碰撞；嵌套 exists 支持多层；
- 子查询参数与外层共享命名参数序号（`:p1、:p2…` 全局唯一）；
- 子查询实体须与子条件字段所属实体一致，否则装配期抛异常。

终端 `exists()`（是否存在符合条件记录）实现为 `findTop(1)` 命中即停，不做全量 count 聚合。

### 逻辑组合与嵌套

```java
// and/or 连接符、嵌套括号、not 取反（一层分组）
lightDao.lambdaQuery(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1)
        .or(n -> n.eq(StaffInfo::getOrganId, "O001").eq(StaffInfo::getStaffName, "张三"))
        .not(n -> n.isNull(StaffInfo::getMobile))
        .find();
// → status = :p1 OR (organ_id = :p2 AND staff_name = :p3) AND NOT (mobile IS NULL)

// 多层分组：nested/and/or/not 的参数 n 是同类型构建器，可继续往下嵌套，层数不限
lightDao.lambdaQuery(StaffInfo.class)
        .nested(outer -> outer
                .nested(inner -> inner.eq(StaffInfo::getOrganId, "O001").or().eq(StaffInfo::getOrganId, "O002"))
                .eq(StaffInfo::getStatus, 1))
        .or().eq(StaffInfo::getStaffId, "S009")
        .find();
// → ((organ_id = :p1 OR organ_id = :p2) AND status = :p3) OR staff_id = :p4

// accept：复用一段条件、并入当前层（不加括号）；nested：独立分组（加括号）
lightDao.lambdaQuery(StaffInfo.class).eq(StaffInfo::getStatus, 1)
        .accept(q -> q.eq(StaffInfo::getOrganId, "O001").eq(StaffInfo::getStaffName, "张三")).find();
// → status = :p1 AND organ_id = :p2 AND staff_name = :p3
lightDao.lambdaQuery(StaffInfo.class).eq(StaffInfo::getStatus, 1)
        .nested(q -> q.eq(StaffInfo::getOrganId, "O001").eq(StaffInfo::getStaffName, "张三")).find();
// → status = :p1 AND (organ_id = :p2 AND staff_name = :p3)

// last 追加原始 sql 片段（有注入风险，谨慎）
lightDao.lambdaQuery(StaffInfo.class).eq(StaffInfo::getStatus, 1).last("limit 10").find();
```

相邻条件自动补 `AND`；`and()/or()` 显式连接符相邻时合并保留最后一个；首尾悬挂连接符自动剔除；每层嵌套整体以括号包裹，**层数不限**（实际受 JVM 栈深度与目标库表达式嵌套上限约束，常见业务 1~3 层即可满足，更复杂的动态分组建议使用 SQL 模式）。**空分组自动丢弃**：当组内条件全被 `condition=false` 或 `IfPresent` 跳过时，整组连同多余连接符一并消失，不会渲染出 `()` 这类非法 SQL——因此动态分组可放心写，参数缺失时该组自然不参与查询。

### 分组、排序与聚合过滤

```java
lightDao.lambdaQuery(StaffInfo.class)
        .groupBy(StaffInfo::getOrganId)
        .having("count(*) > :min", MapKit.map("min", 5))
        .orderByAsc(StaffInfo::getOrganId)
        .orderByDesc(StaffInfo::getEntryTime)   // 多次 orderBy 合并为一个子句
        .find();
```

仅分组/排序而无 where 条件时，自动以 `1 = 1` 补齐 where。

### select 指定字段

```java
lightDao.lambdaQuery(StaffInfo.class)
        .select(StaffInfo::getStaffId, StaffInfo::getStaffName)   // 属性名形式
        .eq(StaffInfo::getStatus, 1)
        .find();
```

### 动态化条件

**推荐惯用法是 `IfPresent` 语法糖**：值为 null（字符串为空白、集合为空）时条件自动跳过：

| 方法 | 跳过条件 |
| --- | --- |
| `eqIfPresent / neIfPresent / gtIfPresent / geIfPresent / ltIfPresent / leIfPresent` | 值为 null |
| `likeIfPresent` | 空白串 |
| `inIfPresent(Collection)` / `inIfPresent(值...)` / `notInIfPresent(Collection)` | 集合/数组为 null 或空 |
| `betweenIfPresent(v1, v2)` / `betweenIfPresent(数组)` | 双 null 跳过；半开区间自动退化：仅下限→`ge`，仅上限→`le` |

```java
// 页面查询条件的典型写法：参数有没有就拼不拼
lightDao.lambdaQuery(StaffInfo.class)
        .eqIfPresent(StaffInfo::getStatus, status)
        .likeIfPresent(StaffInfo::getStaffName, name)
        .inIfPresent(StaffInfo::getOrganId, organIds)
        .betweenIfPresent(StaffInfo::getEntryTime, start, end)
        .find();
```

被跳过的条件在装配期不会解析列名，因此不产生任何副作用。**更复杂的动态组合（多分支、方言差异、配置化）请使用 SQL 模式。**

### 值过滤策略

默认过滤 null 值条件；可在添加条件之前设置实例级策略：

```java
lightDao.lambdaQuery(StaffInfo.class)
        .valueFilter(v -> v != null && !"".equals(v))   // 实例级，非全局静态
        .eq(StaffInfo::getStaffName, name)
        .find();
```

---

## 三、单表更新

```java
lightDao.lambdaUpdate(StaffInfo.class)
        .set(StaffInfo::getStatus, 2)
        .setExpr(StaffInfo::getLoginCount, "loginCount + 1")   // 基于当前值计算
        .eq(StaffInfo::getStaffId, staffId)
        .update();
```

### setExpr 表达式更新

| 形态 | 示例 | 说明 |
| --- | --- | --- |
| 字面量表达式 | `.setExpr(U::getLoginCount, "loginCount + 1")` | 表达式中的字段以**属性名**书写，执行时自动转数据库字段，可引用同表其他字段 |
| `?` 占位绑定值 | `.setExpr(U::getSalary, "salary * ?", rate)` | 单个 `?` 绑定第二个参数 |
| `:name` 命名参数 | `.setExpr(U::getSalary, "salary * :rate", rate)` | 单表通道支持（复用 updateByQuery 的表达式 set 能力） |

表达式内**不支持 `=` 字符**（赋值等号由框架组装），传入即抛异常。

默认值过滤会跳过 `set(col, null)`；需要把字段显式置 null 时用 `setNull`：

```java
lightDao.lambdaUpdate(StaffInfo.class).setNull(StaffInfo::getMobile).eq(StaffInfo::getStaffId, id).update();
```

### 安全边界

- **无任何 where 条件的更新/删除默认抛 `DataAccessException`**，需显式 `.matchAll()` 放行——避免误写全表更新；
- where 为字面量（无命名参数）时内部自动补 `1=:DEFAULT_VALUE` 兜底，规避参数计数校验，使用者无感；
- **整对象更新（按主键）不在 lambda 层提供**，直接使用既有链路：`lightDao.update(entity)` / `lightDao.update(entity, forceUpdateProps)`。

---

## 四、单表删除

```java
lightDao.lambdaDelete(StaffInfo.class)
        .eq(StaffInfo::getStatus, 0)
        .delete();

// 无条件删除须显式放行
lightDao.lambdaDelete(StaffInfo.class).matchAll().delete();
```

删除条件构建器只支持 where 条件（无 select/orderBy），与查询构建器职责分离。

---

## 五、多表 join 查询

在同一个 `LambdaQuery` 上调用 join 步骤即切换为 join 通道，**单表只是 join 的退化形态**：

```java
public class StaffInfoVO {
    private String staffId;
    private String staffName;
    private String organName;    // 来自关联表
    // getter/setter
}

List<StaffInfoVO> rows = lightDao.lambdaQuery(StaffInfoVO.class)
        .selectAll(ExcludeCols.of(StaffInfo::getStatus))          // 主表全部字段，排除 status
        .from(StaffInfo.class)                                    // 结果类型为 VO 时须显式指定主表
        .leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .select(JoinCol.of(OrganInfo::getOrganName).as("organName"))  // 额外列 + 结果别名
        .eqIfPresent(StaffInfo::getStatus, status)
        .orderByAsc(StaffInfo::getStaffId)
        .find();
```

生成 SQL（列按所属实体别名限定，`AS` 别名用于结果对象属性映射）：

```sql
SELECT s1.STAFF_ID AS staffId, s1.STAFF_NAME AS staffName, o2.ORGAN_NAME AS organName
FROM sqltoy_staff_info s1 LEFT JOIN sqltoy_organ_info o2 ON s1.ORGAN_ID = o2.ORGAN_ID
WHERE s1.STATUS = :p1
ORDER BY s1.STAFF_ID ASC
```

### join 步骤

| 方法 | 说明 |
| --- | --- |
| `from(entityClass)` | 指定主表；**可省略**——查询场景缺省以结果类型作为主表（结果类型为 VO 等非实体时必须显式指定） |
| `leftJoin / rightJoin / innerJoin(entityClass)` | 发起连接，返回 on 步骤；首次调用即切换 join 通道 |
| `on(字段A, 字段B)` | 等值关联；同一 join 可传两对字段（自动 AND）；完成后返回查询构建器，可继续叠加 join 或条件 |

表别名按实体类名首字母小写加序号生成（`s1`、`o2`…）。join 后缺 `on()`、条件引用未参与 join 的实体，均在装配期抛异常。

### select 的几种形态

| 形态 | 语义 |
| --- | --- |
| 不写 select | 结果类型参与 join 时查其全部字段（`列 AS 属性名`），否则 `*` |
| `selectAll()` | 显式声明主表全部字段，可与 `select(JoinCol...)` 额外列并存（主表字段在前） |
| `selectAll(Entity.class)` | 将某个**被 join 实体**的全部字段以 `别名.列 AS 属性` 并入 select（与主表重复时自动跳过）；该实体须参与 join，否则装配期抛异常 |
| `selectAll(ExcludeCols.of(A::getX, A::getY))` | 主表全部字段**排除**指定字段；排除字段须属于主表实体；单表通道转 `EntityQuery.unselect` 同样生效 |
| `select(JoinCol...)` | 指定列：`JoinCol.of/count/sum/avg/min/max(字段).as(别名)`，存在即走 join 通道；单表分组聚合同样用它（配合 `from(主表)` + `groupBy` + `having`） |
| `select(JoinCol.raw("..."))` | **原生 SQL 片段列**：类型化 select 表达不了的形态（窗口函数 `ROW_NUMBER() OVER(..)`、数据库特有函数、`CASE WHEN`、算术表达式等）；`JoinCol.raw(片段).as(别名)` 或片段内联 `... AS 别名`，原样拼入 SELECT、触发 join 通道（结果映射到含该别名字段的 VO） |
| `distinct()` | 结果去重：单表通道转 `EntityQuery.distinct()`，join 通道渲染 `SELECT DISTINCT`（DISTINCT 是量词不是函数，故不提供列函数形态） |

`JoinCol.raw(...)` 用于补类型化 select 的盲区（如窗口函数），片段内引用的是**真实数据库列名/表别名**（单表可用非限定列名，多表用自动生成的别名如 `j1`）：

```java
// 窗口函数：按薪资排名，rn 映射到 VO 的 rankNo 字段
List<StaffRankVO> ranks = lightDao.lambdaQuery(StaffRankVO.class)
        .select(JoinCol.of(StaffInfo::getStaffName).as("staffName"),
                JoinCol.raw("ROW_NUMBER() OVER(ORDER BY SALARY DESC)").as("rankNo"))
        .from(StaffInfo.class)
        .find();
// → SELECT s1.STAFF_NAME AS staffName, ROW_NUMBER() OVER(ORDER BY SALARY DESC) AS rankNo FROM sys_staff_info s1
```

> `JoinCol.raw` 与 `last(sql)` 同为**原始 SQL 逃逸口**：框架原样拼接、不做注入筛查，**禁止拼入终端用户输入**；跨库使用时注意片段本身的方言可移植性（如窗口函数各库语法差异）。

### 分组聚合（sum/avg/min/max/count）

聚合列用 `JoinCol` 的函数工厂表达，配合 `groupBy`/`having`；**单表分组聚合不需要 join**——`JoinCol` 会把查询切到 SQL 通道，此时用 `from(主表)` 指定聚合对象：

```java
public class OrganSalaryStatVO {
    private String organId;
    private BigDecimal totalSalary;
    private BigDecimal avgSalary;
    private Long staffCount;
    // getter/setter
}

List<OrganSalaryStatVO> stats = lightDao.lambdaQuery(OrganSalaryStatVO.class)
        .select(JoinCol.of(StaffInfo::getOrganId).as("organId"),
                JoinCol.sum(StaffInfo::getSalary).as("totalSalary"),
                JoinCol.avg(StaffInfo::getSalary).as("avgSalary"),
                JoinCol.count(StaffInfo::getStaffId).as("staffCount"))
        .from(StaffInfo.class)
        .eqIfPresent(StaffInfo::getStatus, status)
        .groupBy(StaffInfo::getOrganId)
        .having("sum(SALARY) > :min", MapKit.map("min", 10000))   // having 为原始sql,命名参数经Map提供
        .find();
```

join 场景的聚合写法相同，只是多一步 `leftJoin(...).on(...)`；`having` 文本为原始 SQL（列写实际列名），分组键为 null 的行同样参与聚合（SQL 标准行为）。聚合结果按聚合列排序用别名排序：

```java
.groupBy(StaffInfo::getOrganId)
.orderByDesc("staffCount")   // 按 select 中 as 定义的别名排序,仅 join 通道有效
```

单表通道没有列别名，调用别名排序会在装配期抛异常；别名须为普通标识符（防注入）。

### 结果映射与 LEFT JOIN

`AS` 别名与结果类型属性同名即映射；结果类型中没有的列自动忽略。LEFT JOIN 下关联表无匹配行时，对应属性为 null。

### join 通道的终端与限制

`find/getOne/findPage/findTop/findRandom/count/exists` 全部可用；**join 通道不继承实体级增强**（分片、缓存翻译、脱敏等），这是多表 SQL 的固有边界。

---

## 六、多表 join 更新与删除

join 更新/删除采用**可移植的 EXISTS-over-derived 改写**（非 MySQL 多表 DML 语法）：把 join 与 where 条件整体放入派生表，外层以主键做 EXISTS 关联限定，因此完整保留 LEFT JOIN 语义，并覆盖 Oracle/PostgreSQL 等本身没有多表 `UPDATE ... JOIN` / `DELETE ... JOIN` 语法的数据库：

```sql
UPDATE 目标表 SET 列 = :p1 WHERE EXISTS (
    SELECT 1 FROM (SELECT 别名.主键 AS LPK1 FROM 主表 别名 LEFT JOIN ... WHERE 条件) sqd
    WHERE sqd.LPK1 = 目标表.主键)

DELETE FROM 目标表 WHERE EXISTS (
    SELECT 1 FROM (SELECT 别名.主键 AS LPK1 FROM 主表 别名 LEFT JOIN ... WHERE 条件) sqd
    WHERE sqd.LPK1 = 目标表.主键)
```

```java
// join 更新
lightDao.lambdaUpdate(StaffInfo.class)
        .leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .set(StaffInfo::getStatus, 2)
        .eq(OrganInfo::getOrganName, "研发部")
        .update();
// UPDATE sqltoy_staff_info SET STATUS = :p1 WHERE EXISTS (
//   SELECT 1 FROM (SELECT s1.STAFF_ID AS LPK1 FROM sqltoy_staff_info s1
//                  LEFT JOIN sqltoy_organ_info o2 ON s1.ORGAN_ID = o2.ORGAN_ID
//                  WHERE o2.ORGAN_NAME = :p2) sqd
//   WHERE sqd.LPK1 = sqltoy_staff_info.STAFF_ID)

// join 删除：deleteTables 指定删除目标（缺省主表）
lightDao.lambdaDelete(StaffInfo.class)
        .leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .deleteTables(StaffInfo.class)
        .eq(OrganInfo::getOrganName, "市场部")
        .delete();
// DELETE FROM sqltoy_staff_info WHERE EXISTS (SELECT 1 FROM (SELECT s1.STAFF_ID AS LPK1 FROM ... ) sqd WHERE sqd.LPK1 = sqltoy_staff_info.STAFF_ID)
```

- join 更新/删除的**主表隐式为构建器实体**，无需 `from()`；
- **目标实体必须有 `@Id` 主键**（复合主键按 `LPK1…LPKn` 逐一关联）：EXISTS 改写靠主键回连目标表，无主键实体在装配期抛 `DataAccessException`；
- 改写被 mysql/postgresql/sqlserver/oracle/db2 等关系型库真库验证（属发版多库门禁范围）；clickhouse/doris/starrocks 等没有事务性行级 DML 能力的库不支持，需改走 SQL 模式；
- join 更新的 `setExpr` 表达式**原样输出**（单表通道"属性名自动转列名"不适用），字段请写实际列名，单个 `?` 仍可绑定值；
- join 通道同样受无条件守卫约束（`matchAll()` 放行）。

---

## 六之二、组合查询：CTE（WITH AS）/ @fast 分页下推 / UNION

lambda 支持把**多个 lambdaQuery 组合**成一条大 SQL：CTE（`WITH ... AS`）、@fast 分页下推派生表、UNION/UNION ALL。组合时各分支**共享参数序号**（先装配内层、外层续号），参数名全局唯一不撞号。

### CTE（WITH AS）

```java
// 内层 CTE 体：一个独立的 join lambdaQuery（不直接执行，只贡献 SQL）
LambdaQuery<CteDept> inner = lightDao.lambdaQuery(CteDept.class).from(CteDept.class)
        .select(JoinCol.of(CteDept::getDeptId).as("deptId"), JoinCol.of(CteDept::getDeptName).as("deptName"))
        .eq(CteDept::getStatus, 1);

// 外层：with 注册 CTE，fromCte 引用它；外层类型化到 VO（字段映射 CTE 输出列）
List<CteDeptVO> rows = lightDao.lambdaQuery(CteDeptVO.class)
        .with("d", inner)
        .fromCte("d")
        .eq(CteDeptVO::getDeptName, "研发部")
        .find();
// → WITH d AS (SELECT c1.DEPT_ID AS deptId, c1.DEPT_NAME AS deptName FROM cte_dept c1 WHERE c1.STATUS = :p1)
//   SELECT c2.DEPTNAME AS deptName, c2.DEPTID AS deptId FROM d c2 WHERE c2.DEPTNAME = :p2
```

- **多 CTE / CTE 引用 CTE**：链式 `.with("a", qa).with("b", qb)`，`qb` 内可 `fromCte("a")` → `WITH a AS (..), b AS (..)`。
- **递归 CTE**：`.withRecursive(name, q, "id", "pid", "name")` → `WITH RECURSIVE name(id, pid, name) AS (..)`；**列清单建议必给**——H2 等库的递归 CTE 强制要求列清单，PG/MySQL/SQLServer 亦标准支持；Oracle/SQLServer 递归不带 `RECURSIVE` 关键字，框架按执行库类型自动适配。递归分支须用 **innerJoin** 关联 CTE 自身（LEFT JOIN 无子节点也产行会致递归不终止），且关联方向为「子.pid = 当前节点.id」向下遍历。
- **PG 物化 hint**：`.with(name, q, Boolean.TRUE/FALSE)` → PostgreSQL 渲染 `AS MATERIALIZED` / `AS NOT MATERIALIZED`；**其他库自动忽略**（按 dbType 处理，不支持的不生效）。
- **WITH 位置约束**：生成的 `WITH` 恒位于语句位置 0——sqltoy 靠文本检测 WITH（`SqlWithAnalysis`/`hasWith`）以在 count/分页时把 WITH 剥离到包裹之外，前导分号会破坏该检测；SQLServer 单条语句以 WITH 开头本就不需要前置分号（分号要求仅针对 WITH 前尚有未结束语句的批处理）。
- 外层列解析走**结果 VO 的 EntityMeta**（CTE 非真实表、无 EntityMeta），故外层须类型化到字段与 CTE 输出列对齐的 VO；不支持 CTE 的老库由开发者自行改写（框架不做降级）。

### @fast 分页下推派生表

`@fast` 语义：**先对 @fast 内层分页取 pageSize 条，再拿这几条去 join 外表**（避免全量 join 再分页）；分页 count 默认用 @fast 内层 SQL（简化形态）。lambda 以派生表形式表达：

```java
LambdaQuery<StaffInfo> inner = lightDao.lambdaQuery(StaffInfo.class).from(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1).orderByDesc(StaffInfo::getEntryDate);   // 内层：过滤+排序（被分页下推）

Page<StaffOrganVO> page = lightDao.lambdaQuery(StaffOrganVO.class)
        .fromFast(inner, "t1")                                   // FROM @fast(内层sql) t1
        .leftJoin(OrganInfo.class).on(StaffOrganVO::getOrganId, OrganInfo::getOrganId)
        .findPage(new Page(10, 1));
// → select t1.*, t2.ORGAN_NAME from @fast(select ... from staff t where t.STATUS=:p1 order by t.ENTRY_DATE desc) t1
//   left join organ t2 on t1.organ_id=t2.ORGAN_ID   （limit/offset 由 sqltoy 下推进 @fast 内层）
```

`@fast` 也可嵌进 CTE 体：`.with("tmp", q)` 且 `q` 内部用 `fromFast(...)` → `WITH tmp AS (SELECT * FROM @fast(..) t1 ...)`。

**更精简的 count**：`.countSql("select count(1) from staff where status=:p1")` 提供比 @fast 内层 count 更精简的手写 count（仅 join/SQL 通道 findPage 生效），对应 sqltoy 的 `count-sql` 配置。

### UNION / UNION ALL

```java
LambdaQuery<NameVO> q1 = lightDao.lambdaQuery(NameVO.class).from(Staff.class)
        .select(JoinCol.of(Staff::getName).as("name")).eq(Staff::getStatus, 1);
LambdaQuery<NameVO> q2 = lightDao.lambdaQuery(NameVO.class).from(Staff.class)
        .select(JoinCol.of(Staff::getName).as("name")).eq(Staff::getStatus, 2);

q1.unionAll(q2).find();          // (q1) UNION ALL (q2)  不去重、更快
q1.union(q2).count();            // (q1) UNION (q2)     去重
q1.unionAll(q2).findPage(page);  // 包裹子查询后分页,count 同理
```

- 两侧须映射**同一结果类型**且 select 列/别名一致；均为 join/SQL 通道（需 `from`/`select`）。
- **全部查询终端都作用于组合后的 SQL**（`find/getOne/findPage/findTop/findRandom/count/exists` 均经 `getSql()` 取组合 SQL，故 UNION/CTE 上都能用）；UNION ALL 的 count 可复用 sqltoy 的 union-all-count 优化（拆分支求和）。

> 组合查询（CTE/@fast/UNION）均为 join/SQL 通道，**不继承实体级增强**（分片/翻译/脱敏/租户）；CTE/@fast/UNION 的原始 SQL 片段与别名由开发者保证方言可移植性。

---

## 七、参数与 SQL 形态约定

- 条件参数统一命名为 `:p1、:p2…`，全构建器唯一（嵌套条件、join 的 set 与 where 共享序号），SQL 日志可读；
- `having`、`inSql` 的外部命名参数请**避免 `p` 加纯数字**的形式，以免与内部参数重名；
- 嵌套条件整体加括号；仅分组/排序时以 `1 = 1` 补齐 where；
- lambda 解析仅支持 **getter 方法引用**（`User::getName`、`User::isActive`），表达式 lambda（`u -> u.getName()`）无法提取属性名，会快速失败。

---

## 七之二、安全边界与使用约定

- **原始 SQL 逃逸口不做注入筛查**：`last(sql)`、`having(sql, params)`、`inSql(col, sql, params)`、`setExpr(col, expr)` 四处接收原始 SQL 文本（与 sqlId 文本同级），**禁止拼接终端用户输入**；参数一律走命名参数绑定；
- **参数命名空间**：内部条件参数为 `:p1、:p2…`，`having`/`inSql` 的外部参数名禁用 `p` 加纯数字形式，调用时即校验抛错；
- **select 别名唯一性**：用户显式别名（`JoinCol.as(...)`、属性形式 select）与任何已有别名重复时抛异常（结果映射歧义）；框架 dump（`selectAll()`/`selectAll(Class)`）之间的同名列按声明顺序**主表优先跳过**（如主表与关联表都有 `status` 列时，关联表 dump 跳过该列），需要关联表同名列时用 `JoinCol.as` 显式改名；
- **join 自关联不支持**：同一实体注册两次（含 from 后再 join 同类）抛异常，lambda join 无法为同实体生成两个别名；
- **结果类型为 VO 时**属性形式 `select(VO::getX)` 在 join 通道不可用（VO 未参与 join，无法限定别名），抛异常；VO 场景用 `JoinCol...as()` 或 `selectAll/selectAll(Class)`；
- **`last(sql)` 的通道限制**：join 通道正常追加到 SQL 末尾；单表通道（EntityQuery 的 where 无法承载尾部原始 sql）调用即抛异常，改用 `findTop/findPage` 或 join 通道；
- **外部参数命名空间**：两个 `inSql`/`having` 共用同一命名参数且**值不同**时抛异常（静默覆盖会产生错误结果）；同值共享绑定是允许的；
- **代理 lambda 不支持**：IDEA Evaluate 窗口或 Mockito mock 产生的动态代理 lambda 在 JDK 模块强封装下无法解析元信息，抛异常并提示加 `--add-opens java.base/java.lang.invoke=ALL-UNNAMED` 或改用方法引用；
- **构建器单次使用、非线程安全**：一个构建器实例对应一次查询组装；终端执行（assemble）后再调用 `from/leftJoin/on` 等结构变更方法会抛异常，条件追加亦不会生效；并发场景每请求新建；
- **字段必须是映射属性**：条件/select/set 引用的属性须为实体 `@Column` 映射字段，未映射属性（辅助 getter、`getClass` 等）装配期抛异常，不会生成 `null = :p1` 这类静默错果；
- **更新/删除构建器拒绝分组排序**：`groupBy/having/orderBy` 仅 `LambdaQuery` 支持，在 `LambdaUpdate/LambdaDelete` 上调用装配期抛异常；
- **`not(...)` 与前条件自动补 AND**：`eq(a).not(n -> ...)` 渲染为 `a AND NOT (...)`；空 `not(...)` 的悬挂 NOT 自动剔除；
- **删除通道的无参数 where 兜底**：与更新同口径（`isNull` 等无命名参数条件、`matchAll` 场景自动补 `1=:DEFAULT_VALUE`），不会触发 deleteByQuery 的空值拒绝；
- **主键可被显式 set/setExpr**：属显式意图（自然键修正等场景），框架不拦截；多行更新为同一主键值会被数据库主键约束拒绝；整对象更新的主键安全由 `lightDao.update(entity)` 保证（主键走 where）。

## 八、错误语义速查

| 场景 | 行为 |
| --- | --- |
| `getOne()` 匹配多条 | 抛异常（含匹配条数），提示检查条件唯一性或改用 `find()` |
| 更新/删除无任何 where 条件 | 抛异常，需显式 `matchAll()` |
| 条件/select/set 字段所属实体未参与 join | 抛异常：实体未参与当前查询/join |
| join 后缺 `on()` | 装配期抛异常 |
| join 更新/删除缺主表 | 装配期抛异常（查询场景主表可缺省为结果类型） |
| `setExpr` 表达式含 `=` | 调用时抛异常 |
| `setExpr` 表达式引号内含字面量 `?` | 调用时抛异常（更新通道做全量 `?` 文本替换，引号内 `?` 会被误当参数位） |
| `ExcludeCols` 字段不属于主表实体 | 装配期抛异常 |
| `selectAll(ExcludeCols...)` 排除全部字段 | 装配期抛异常 |
| 构建器未绑定 dao 调用终端 | 抛异常并提示创建方式 |

---

## 九、自 sqltoy-plus 迁移对照

| sqltoy-plus | lambda 条件体系 |
| --- | --- |
| `Wrappers.lambdaQuery(entityClass)` | `LambdaQuery.create(entityClass)` 或 `lightDao.lambdaQuery(entityClass)` |
| `LambdaQueryWrapper / LambdaUpdateWrapper` | `LambdaQuery / LambdaUpdate` |
| `SqlToyPlusDao.findList/findOne/findPage/count/exists/delete/update(wrapper)` | 构建器终端：`lambdaQuery(...).find()/getOne()/findPage()/count()/exists()`、`lambdaUpdate(...).update()`、`lambdaDelete(...).delete()` |
| `lambdaQueryChain/lambdaUpdateChain` | `lightDao.lambdaQuery/lambdaUpdate`（工厂即绑定 dao，直接终端） |
| `Wrappers.lambdaMultiWrapper(toClass).select(...).from(...)` | `lightDao.lambdaQuery(toClass)[.selectAll(...)].from(...).leftJoin(...).on(...)` |
| `LambdaColumn` | `JoinCol` |
| `lambdaUpdateMultiWrapper / lambdaDeleteMultiWrapper` | `lightDao.lambdaUpdate/lambdaDelete` + join 步骤 |
| `SFunction` | `LambdaFn` |
| `FiledValueFilterStrategy` 全局静态 | 构建器实例级 `valueFilter(...)` |
| `type.valuePairs.MPG1` 形式参数名 | `:p1…` |
| 字符串列名 wrapper（QueryWrapper 等） | 不再提供：单表字符串条件用 `EntityQuery`，复杂动态用 SQL 模式 |
| `@EnableSqlToyPlus` / 映射策略 Bean | 无需任何配置，能力随 `LightDao` 提供 |

---

## 十、能力边界（不做什么）

- **字符串条件 DSL**：lambda 层只接受方法引用；字符串单表条件用 `EntityQuery/EntityUpdate`，复杂动态用 SQL 模式；
- **实体级增强在 join 通道不生效**（分片/翻译/脱敏/租户）；
- **OLAP 库的 join 更新/删除**：clickhouse/doris/starrocks 等无事务性行级 DML 能力的库，join 更新/删除用例跳过（数据库自身能力边界，由开发者控制）；关系型库的 join 更新/删除采用可移植 EXISTS-over-derived 改写，经 mysql/postgresql/sqlserver/oracle/db2 等真实库验证；
- **整对象并入更新**：按主键整对象更新用 `lightDao.update(entity)`，lambda 层只提供 `set/setExpr` 显式字段；
- **拦截器/插件体系**：lambda 条件最终走 sqltoy 既有执行链路，插件能力（SqlInterceptor 等）照常生效，但 lambda 层自身不提供插件点。
