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

## 九、@df() / @day()（日期格式化）

把日期格式化成字符串后拼进 SQL，**不需要**关心目标库的日期函数（这是**字符串拼接**，不是数据库函数替换）。

```text
@df(格式)                 → 取当前时间按格式输出
@df(参数, 格式)           → 把参数值按格式输出
@day(...)                 → 与 @df 完全等价（历史别名）
```

- 默认格式 `yyMMdd`；
- 格式为空串或 `null` 时**输出空串**（`@df('')` 可实现"某段条件整体省略"的写法）；
- 参数可以是命名参数（`@df(beginDate, yyyy-MM-dd)`）或 `${beginDate}` 形式，也可直接用字面量；**不要写成 `:beginDate`**——宏的取值来自传入的参数 Map，键名不带冒号。

```xml
<sql id="query_by_month">
	select * from sqltoy_order_info t
	where t.trans_month = '@df(yyyyMM)'
	#[and t.trans_date >= '@df(beginDate, yyyy-MM-dd)']
</sql>
```

> 与 [filter 的 `<to-date>`](../query/dynamic_sql.md) 区别：`@df` 是把**值格式化后拼进 SQL 文本**（会形成字面量），`<to-date>` 是把**参数转成日期类型后仍以 `?` 绑定**。涉及外部输入时优先用 `<to-date>`，`@df` 更适合报表拼接期间、分区表名等场景。

## 十、@case()（decode 式枚举判断）

类似 Oracle `decode` 的取值映射，把参数值按枚举翻译成对应的字符串或 SQL 片段：

```text
@case(参数, 值1, 结果1, 值2, 结果2, ..., 默认结果)
```

- 参数可以是命名参数（`@case(orderType, ...)`）或 `${orderType}` 形式；
- 参数少于 3 个时输出空串；
- **最后一个参数是默认结果**（没有匹配项时输出）。

```xml
<!-- 按订单类型拼不同的排序规则 -->
select * from sqltoy_order_info t
where t.status=1
order by @case(orderType,'SALE','t.sale_date desc','BUY','t.buy_date desc','t.create_time desc')
```

> 业务主键场景同样使用该宏，见 [主键策略 · @BusinessId](../primarykey/sqltoy_primarykey.md)。

## 十一、@substr() / @substring()（子串截取）

```text
@substr(参数, 起始位置, 长度)
```

- 起始位置从 0 开始；**为负数表示从尾部截取**；
- 起始位置大于等于字符串长度时输出空串；
- 参数为空时输出空串；`@substring` 与 `@substr` 等价。

```xml
<!-- 用订单号前两位区分业务线 -->
select * from sqltoy_order_info t
where t.biz_line = '@substr(orderId,0,2)'
```

## 十二、@virtualTable()（跨库虚表）

"select 常量行 union 真实查询"类写法（字典下拉兜底行、报表固定合计行等）在 oracle/db2/hana 上必须挂伪表，而 mysql/pg/sqlserver 等写 `from dual` 反而报错。用该宏在解析期按方言自动展开：

```sql
select '0' id,'全局公共' name @virtualTable()
union
select id,name from sqltoy_dict_detail where status=1
```

- oracle 系（oracle/oracle11/dm/oceanbase）→ `from dual`；db2 → `from sysibm.sysdummy1`；hana → `from dummy`；其余方言直接剔除；
- 兼容别名 `@dual()` / `@dummyTable()`，三者等价、大小写不敏感、括号内空白容错；一条 SQL 可出现多次；
- 不含该宏的 SQL 零影响；详见[方言自适配与函数扩展](../dialect/sqltoy_function.md)。

---

## 十三、@split()（参数拆分数组）

把传入的**一个字符串参数**按分隔符拆分成数组，交给 `in` 等集合展开机制使用——典型场景是前端只传 `"A;B;C"` 一个字符串，SQL 里直接 `field in (...)`，省去 Java 侧手工 split。在 SQL 解析期由 `SqlConfigParseUtils` 处理。

三种形态：

```sql
-- 1、默认逗号分隔（按正则 \s*,\s* 切分，容忍空白）
select * from sqltoy_order_info t where t.status in (@split(:statusStr))

-- 2、指定分隔符（可带单引号或双引号）
select * from sqltoy_order_info t where t.status in (@split(:statusStr,';'))

-- 3、指定分隔符并转数字数组（各段转 Integer，空白段跳过）
select * from sqltoy_order_info t where t.status in (@split(:statusStr,int,','))
```

要点：

- `@split(...)` 执行期被替换回 `?`，切分后的数组放入对应参数位，随后按集合展开机制自动拆成多个 `?` 占位符；
- 仅当参数值为 `String` 时才切分；每段自动 trim，参数自带首尾引号时先剥离；
- 不传第二个参数时默认分隔符为逗号（`\s*,\s*`）。

Java 调用（前端传一个字符串即可）：

```java
List rows = lightDao.findByQuery(
        new QueryExecutor("sqltoy_order_info_find")
            .names("statusStr").values("1,2,3")   // 一个字符串，无需前端给数组
            .resultType(OrderVO.class))
        .getRows();
```

---

> 相关：[`#[]` 与 filters 过滤器](../query/dynamic_sql.md)、[常见 SQL 案例](../query/sql_showcase.md)、[分页优化](../query/pagination.md)、[注解速查](annotations.md)。
