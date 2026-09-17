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

**注意事项：**

- 内部参数以逗号分隔，若 `loopContent` 中含逗号，请用 `{}`、`''` 或 `""` 包裹内容，确保切割准确。
- 支持子对象属性模式：`staffInfos[i].xxxx`，应对极端场景。
- in 条件参数数组超过 1000 时，框架（5.1.32 / 4.19.25 起）会**自动切分**。
- `@secure-loop` 自 5.1.44 版本支持。

**范例：**

```text
@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or })
```

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

---

> 相关：[`#[]` 与 filters 过滤器](../query/dynamic_sql.md)、[常见 SQL 案例](../query/sql_showcase.md)、[分页优化](../query/pagination.md)。
