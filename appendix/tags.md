# 补充说明：标签与表达式参考

除了 [`#[]` 动态条件片段](../query/dynamic_sql.md)，sqltoy 还在 SQL 中预留了一组 `@` 宏指令，用于应对极端复杂的动态 SQL 场景。灵活搭配 `@if`、`@value`、`@blank`、`@loop` 可解决 99.99% 的问题；遇到超复杂场景，推荐在代码中组织好 SQL 片段，再用 `@value(:sqlScript)` 嵌入。

## 一、@if() / @elseif() / @else

为特殊业务场景预留的条件逻辑判断，可写在 SQL 中。

**两种判断模式：**

```text
单逻辑判断：@if(:paramName>=value)
双逻辑判断：@if(:paramName1>=value1 && :paramName2<=value2)
```

- 比较符号：`>`、`>=`、`==`、`<`、`<=`、`!=`、`<>`
- 逻辑运算符：`&&`、`||`、`include`、`in`、`out`
- 配合 `@elseif()`、`@else` 构成完整分支。

**时间/日期比较：**

```text
@if(:paramName>=now()+x)   或   @if(:paramName>=now()-x)
```

- 表示时间：`now()`、`nowtime()`、`${.now}`
- 表示日期：`day()`、`sysdate()`、`${.day}`

**集合/包含判断：**

| 写法 | 含义 |
| --- | --- |
| `@if(:statusAry include 1)` | statusAry 为数组时判断是否包含 1；为字符串时等价于 `statusAry.contains("1")` |
| `@if(:statusAry exclude 1)` | 与 include 相反，不包含 |
| `@if(size(:statusAry)>1)` | 通过 `size(:参数名)` 取集合/数组长度 |
| `@if(:status in '1,2,3')` | status 属于 1/2/3 之一时返回 true |
| `@if(:status out '1,2,3')` | status 不属于 1/2/3 时返回 true |

## 二、@fast / @fastPage

`@fast()` 写在 SQL 中，用于[快速分页](../query/pagination.md)（先分页后关联）。**非分页查询时框架会自动剔除 `@fast`**，因此不影响 find/findTop 等其他查询。`@fast` 与 `@fastPage` 等效。

## 三、@blank()

为非条件部分的语句**虚构出一个参数**，使其符合 sqltoy 的 `#[]` 组织规则。

```text
#[@blank(:sexType) t.SEX_TYPE]
```

- 当 `sexType` 为 null 时，按 `#[]` 逻辑整段被剔除；
- 当 `sexType` 不为 null 时，`@blank(:sexType)` 自动变为空白，剩下 `t.SEX_TYPE`，不影响 SQL 执行。

`@blank` 并非必须，常用于融合 `and`、括号等其他语句。复杂场景请结合 `@if` 和 `@value` 使用。

## 四、@value()

`@value(:paramName)` 类似 `@blank(:paramName)`，唯一区别是它会**直接显示 paramName 对应的值**。

典型用法：`@value(:sqlScript)` 直接把代码中组织好的 SQL 片段嵌入进来，应对超复杂动态 SQL。

> **注意**：`@value` 注入的是未经校验的文本。若只是要拼接**字段名列表**（页面配置化的报表/接口服务按配置决定 select、group by、order by 的列），请改用第八节的 `@joinFields()`——它带字段名白名单校验与按方言的保留字引用。

## 五、@loop() / @secure-loop() / @loop-full() / @secure-loop-full()

用于 SQL 动态循环拼接字段、条件，一般针对数组或集合，**不适用于 in 场景**（in 直接用 `in (:param)` 即可）。

- `@loop()`：参数直接拼接到 SQL 中（**不推荐**，有注入风险）。
- `@secure-loop()`：参数以 `?` 形式入参，防止 SQL 注入（**推荐**）。
- `-full` 版本：默认 `@secure-loop` 会跳过 null 和空值不参与循环；若不想跳过，用 `@secure-loop-full`。

**三种格式：**

```text
@secure-loop(:loopParam, loopContent)
@secure-loop(:loopParam, loopContent, linkSign)
@secure-loop(:loopParam, loopContent, linkSign, startIndex, endIndex)
```

**参数说明：** `startIndex` / `endIndex` 是可选的循环下标区间（从 0 开始计数，`endIndex` 超出数组长度时自动截断到末尾），用于只循环集合中的一段——例如跳过首个元素、从第 2 项开始循环到结尾。**下标直接写数字即可，无需引号**：

```text
@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or }, 1, 100)
```

**注意事项：**

- 内部参数以逗号分隔，若 `loopContent` 中含逗号，请用 `{}`、`''` 或 `""` 包裹内容，确保切割准确。
- 支持子对象属性模式：`staffInfos[i].xxxx`，应对极端场景。
- `loopParam` 为空或未传时，宏返回 `@blank(:loopParam)`，配合外层 `#[]` 会把整段条件自动剔除，无需额外判空。
- in 条件参数数组超过 1000 时，框架（5.1.32 / 4.19.25 起）会**自动切分**。
- `@secure-loop` 自 5.1.44 版本支持。

**范例：**

```text
-- 1) OR 条件链（值条件用 @secure-loop，参数以 ? 占位）：staffIds = ["S0001","S0003"] 时展开为：
--    and ( t.STAFF_ID=?  or  t.STAFF_ID=? )
#[and (@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or }))]

-- 2) 动态列（列名属标识符，占位符机制不适用，只能用 @loop 拼接）：
--    fields = ["STAFF_NAME","EMAIL"] 时展开为 select t.STAFF_ID ,t.STAFF_NAME ,t.EMAIL from ...
select t.STAFF_ID @loop(:fields, { ,t.:fields[i] }) from sqltoy_staff_info t

-- 3) 下标切片（数字直接写，无需引号）：从第 2 个元素开始循环（跳过首元素），endIndex 超长自动截断
@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or }, 1, 100)
```

> 涉及**值**的循环一律优先 `@secure-loop`（防注入）；`@loop` 仅用于列名等标识符拼接场景。

## 六、@include(sqlId)

支持 `@include(sqlId)` 进行 SQL 拼接：在 `@include` 处用对应 `sqlId` 的 SQL 替换。可多处 include、嵌入任意位置。

> 提供该功能但**不推荐**：可读性较差、存在关联影响。

## 七、@include(:scriptParam)

`@include(sqlId)` 的变种，通过**动态传参**形式传入 SQL 片段：

```java
String sql = "select * from sqltoy_fruit_order where status=:status @include(:sqlScript)";
List result = lightDao.find(sql,
        MapKit.keys("status", "saleCount", "sqlScript")
              .values(1, 12, "and sale_count>:saleCount"));
```

## 八、@joinFields()（6.0.7 新增）

把运行期传入的**字段名列表**拼成 SQL 标识符串，用于页面配置化的报表与接口服务（由配置决定 `select` / `group by` / `order by` 的列）。

**格式：**

```text
@joinFields(:fields)
@joinFields(:fields, default)
@joinFields(?, default)
```

- 与 `@value` 处于同一处理位置（命名参数已转成 `?` 之后按位置取值），因此 `@joinFields(:fields,...)` 与在 SQL 里直写 `@joinFields(?,...)` 完全等价；被消费的参数会从参数集合中剔除，不影响其余 `?` 的对位。
- `fields` 为 null、空集合或全空白时输出 `default`；未提供 `default` 则输出空串。
- `default` 取自 SQL 文本（开发者编写，可信），原样输出、不做标识符校验，因此可以写 `t.*`、`sum(t.amount)` 这类表达式；含逗号或括号时用 `{}`、`''` 或 `""` 包裹，如 `@joinFields(:fields,{a.id,a.code})`。

**入参归一规则：**

| 传入形态 | 处理 |
|---|---|
| 单个字符串 `"a,b,c"` | 按逗号切割成 3 个字段 |
| 长度为 1 的数组 `["a,b,c"]` | 同上（页面多选常序列化成这种形态） |
| 长度 > 1 的数组 `["a","b"]` | 元素即字段，**不做二次切割** |
| 长度 > 1 且某元素含逗号 `["a,b","c"]` | 报错，不静默拆分 |
| 空白段（如尾逗号 `"a,b,"`） | 跳过 |

**安全：** 字段名走字符白名单——字母（含中文）、数字、下划线，最多三段点号限定（`schema.table.column`）；显式排除 `$` 与 `#`（与 `#[]` 动态段和 `${}`/`#{}` 参数占位冲突），以及空白、引号、括号、分号、逗号、注释符、反斜杠。非法值**直接抛异常并带上具体值**，不做静默清洗。合法字段再按方言对**保留字**加引用符（mysql 系反引号、oracle/pg 系双引号、sqlserver 方括号），非保留字保持裸标识符，避免 oracle/pg 上引号引入的大小写敏感问题。

**只受理纯标识符**：`sum(col)`、`col as alias` 这类表达式请继续用 `@value`（安全自负）。

**前提：保留字引用依赖 `spring.sqltoy.reservedWords` 配置，而该配置没有默认值。** 未配置时保留字集合为空，`ReservedWordsUtil.convertWord` 会原样返回、不加任何引用符，于是字段列表里含保留字（`order`、`desc`、`level`、`group` 等）时会产出裸标识符并被数据库拒绝——三库实测均报错：PostgreSQL `ERROR: syntax error at or near ","`（`select order,staff_code` 里的 `order` 被当成 `ORDER BY` 关键字解析）、MySQL `You have an error in your SQL syntax`、SQL Server `Incorrect syntax near the keyword 'order'`。因此**若字段名可能命中保留字，必须配置保留字词表**：

```properties
spring.sqltoy.reservedWords=order,desc,level,group,key,comment
```

配置后同一查询在三个库上分别产出 `select "order",staff_code`（PG）、``select `order`,staff_code``（MySQL）、`select [order],staff_code`（SQL Server），实测均正常执行并取回列值。

另外，字段名校验失败抛出的 `IllegalArgumentException` 经 DAO 层会被统一包装成 `DataAccessException`，捕获时请取根因（`getCause()` 链末端），异常信息里带有具体的非法值。

**约束：** 与 `@loop` 等宏一样，SQL 完全没有任何参数时会提前返回、宏不展开；实际报表场景总有 `:fields`，故不受影响。

**示例：**

```xml
<sql id="report_columns">
	select @joinFields(:cols,{t.*}),count(1) total
	from sqltoy_staff_info t
	#[where t.status=:status]
	group by @joinFields(:cols,{t.organ_id})
</sql>
```

```java
// 由页面配置决定展示与分组哪些列
List result = lightDao.find("report_columns",
        MapKit.keys("cols", "status").values("organ_id,dept_id", 1));
```

---

> 相关：[`#[]` 与 filters 过滤器](../query/dynamic_sql.md)、[常见 SQL 案例](../query/sql_showcase.md)、[分页优化](../query/pagination.md)。
