# Tags & Expressions Reference

In addition to [`#[]` dynamic condition fragments](en/query/dynamic_sql.md), sqltoy reserves a set of `@` macro directives inside SQL for highly complex dynamic SQL scenarios. Combining `@if`, `@value` and `@blank` flexibly solves the vast majority of problems; for more complex cases, the recommended approach is to assemble the SQL fragment in code and embed it dynamically with `@include(:sqlScript)` (the fragment may keep using named parameters); for plain-text injection, `@value(:sqlScript)` also works.

## 1. @if() / @elseif() / @else

Conditional logic reserved for special business scenarios; it can be written directly in the SQL.

**Two judging modes:**

```text
Single condition: @if(:paramName>=value)
Dual condition: @if(:paramName1>=value1 && :paramName2<=value2)
```

- Comparison operators: `>`, `>=`, `==`, `<`, `<=`, `!=`, `<>`
- Logical operators: `&&`, `||`, `include`, `in`, `out`
- Combine with `@elseif()` and `@else` to form complete branches.

**Time/date comparison:**

```text
@if(:paramName>=now()+x)   or   @if(:paramName>=now()-x)
```

- Time expressions: `now()`, `nowtime()`, `${.now}`
- Date expressions: `day()`, `sysdate()`, `${.day}`

**Collection/containment checks:**

| Syntax | Meaning |
| --- | --- |
| `@if(:statusAry include 1)` | When statusAry is an array, checks whether it contains 1; when it is a string, equivalent to `statusAry.contains("1")` |
| `@if(:statusAry exclude 1)` | The opposite of include — does not contain |
| `@if(size(:statusAry)>1)` | Gets the length of a collection/array via `size(:paramName)` |
| `@if(:status in '1,2,3')` | Returns true when status is one of 1/2/3 |
| `@if(:status out '1,2,3')` | Returns true when status is none of 1/2/3 |

## 2. @fast / @fastPage

`@fast()` is written inside the SQL for [fast pagination](en/query/pagination.md) (paginate first, then join). **For non-paged queries the framework automatically strips `@fast`**, so it does not affect find/findTop or other queries. `@fast` and `@fastPage` are equivalent.

## 3. @blank()

Invents a parameter for statements that are not conditions themselves, so they fit sqltoy's `#[]` organization rules.

```text
#[@blank(:sexType) t.SEX_TYPE]
```

- When `sexType` is null, the whole fragment is removed following the `#[]` logic;
- When `sexType` is not null, `@blank(:sexType)` automatically becomes blank, leaving `t.SEX_TYPE`, without affecting SQL execution.

`@blank` is not mandatory; it is commonly used to absorb other parts of the statement such as `and` and parentheses. For complex scenarios, combine it with `@if` and `@value`.

## 4. @value()

`@value(:paramName)` is similar to `@blank(:paramName)`, with the only difference that it **directly renders the value of paramName**.

Typical usage: `@value(:sqlScript)` embeds a SQL fragment assembled in code, handling highly complex dynamic SQL; if the fragment itself needs named parameters, use `@include(:scriptParam)` (section 7) instead.

> **Note**: `@value` injects text without validation. When all you need is to join a **list of field names** (page-configurable reports/API services where the configuration decides the select, group by and order by columns), use `@joinFields()` in section 8 instead — it validates field names against a whitelist and quotes reserved words per dialect.

## 5. @loop() / @secure-loop() / @loop-full() / @secure-loop-full()

Used to dynamically loop-concatenate fields or conditions in SQL, generally over arrays or collections; **not intended for in scenarios** (just use `in (:param)` directly for those).

- `@loop()`: parameters are concatenated directly into the SQL (**not recommended** — injection risk).
- `@secure-loop()`: parameters are passed as `?` placeholders, preventing SQL injection (**recommended**).
- The `-full` variants: by default `@secure-loop` skips null and empty values in the loop; if you don't want them skipped, use `@secure-loop-full`.

**Three formats:**

```text
@secure-loop(:loopParam, loopContent)
@secure-loop(:loopParam, loopContent, linkSign)
@secure-loop(:loopParam, loopContent, linkSign, startIndex, endIndex)
```

**Parameters:** `startIndex` / `endIndex` are an optional loop index range (0-based; `endIndex` beyond the array length is clamped to the end), for looping over only a slice of the collection — e.g. skipping the first element and looping from the second to the end. **Write the indexes as bare numbers, without quotes:**

```text
@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or }, 1, 100)
```

**Notes:**

- Inner parameters are comma-separated; if `loopContent` contains commas, wrap the content with `{}`, `''` or `""` to ensure it is split correctly.
- Sub-object property patterns such as `staffInfos[i].xxxx` are supported for extreme scenarios.
- When `loopParam` is empty or absent the macro returns `@blank(:loopParam)`, which makes the enclosing `#[]` fragment drop out entirely — no extra null-check needed.
- When an in-condition parameter array exceeds 1000 entries (e.g. the Oracle limit), the framework (since 5.1.32 / 4.19.25) **splits it automatically**.
- `@secure-loop` is supported since version 5.1.44.

**Examples:**

```text
-- 1) OR condition chain (VALUE conditions use @secure-loop, bound as ? placeholders):
--    with staffIds = ["S0001","S0003"] it expands to:  and ( t.STAFF_ID=?  or  t.STAFF_ID=? )
#[and (@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or }))]

-- 2) Dynamic columns (column names are IDENTIFIERS — the placeholder mechanism does not
--    apply, so @loop concatenation is the only option here):
--    with fields = ["STAFF_NAME","EMAIL"] it expands to:  select t.STAFF_ID ,t.STAFF_NAME ,t.EMAIL from ...
select t.STAFF_ID @loop(:fields, { ,t.:fields[i] }) from sqltoy_staff_info t

-- 3) Index slice (bare numbers, no quotes): loop from the second element (skipping the first),
--    endIndex beyond the array is clamped
@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or }, 1, 100)
```

> Prefer `@secure-loop` whenever the loop involves **values** (injection-safe); reserve `@loop` for identifier concatenation such as column names.

## 6. @include(sqlId)

`@include(sqlId)` concatenates SQL: the SQL of the corresponding `sqlId` is substituted at the `@include` position. Multiple includes are allowed and can be embedded anywhere.

> The feature is provided but **not recommended**: it hurts readability and creates coupled side effects.

## 7. @include(:scriptParam)

A variant of `@include(sqlId)` that passes the SQL fragment in as a **dynamic parameter**:

```java
String sql = "select * from sqltoy_fruit_order where status=:status @include(:sqlScript)";
List result = lightDao.find(sql,
        MapKit.keys("status", "saleCount", "sqlScript")
              .values(1, 12, "and sale_count>:saleCount"));
```

## 8. @joinFields() (new in 6.0.7)

Joins a runtime-supplied **list of field names** into a SQL identifier list — for page-configurable reports and API services where the configuration decides the `select` / `group by` / `order by` columns.

**Formats:**

```text
@joinFields(:fields)
@joinFields(:fields, default)
@joinFields(?, default)
```

- Processed at the same stage as `@value` (after named parameters have become `?`, resolved positionally), so `@joinFields(:fields,...)` and writing `@joinFields(?,...)` directly in the SQL are equivalent; the consumed parameter is removed from the parameter set, so the remaining `?` placeholders stay aligned.
- When `fields` is null, empty or all-blank, `default` is emitted; without a `default` the result is an empty string.
- `default` comes from the SQL text (author-written, trusted) and is emitted verbatim without identifier validation, so it may be an expression such as `t.*` or `sum(t.amount)`; wrap it with `{}`, `''` or `""` when it contains commas or parentheses, e.g. `@joinFields(:fields,{a.id,a.code})`.

**Input normalization:**

| Input shape | Handling |
|---|---|
| a single string `"a,b,c"` | split on commas into 3 fields |
| a 1-element array `["a,b,c"]` | same (page multi-selects often serialize this way) |
| an array with more than 1 element `["a","b"]` | elements are the fields, **no further splitting** |
| more than 1 element where one contains a comma `["a,b","c"]` | rejected, never silently split |
| blank fragments (e.g. a trailing comma `"a,b,"`) | skipped |

**Security:** field names go through a character whitelist — letters (including Chinese), digits, underscore, and at most two dots for qualification (`schema.table.column`). `$` and `#` are explicitly excluded (they collide with the `#[]` dynamic segments and the `${}`/`#{}` parameter placeholders), as are whitespace, quotes, brackets, parentheses, semicolons, commas, comment markers and backslashes. An illegal value **throws immediately and names the offending value** — it is never silently sanitized. Legal fields are then quoted per dialect **only when they are reserved words** (backticks for the mysql family, double quotes for oracle/pg, square brackets for sqlserver); non-reserved identifiers stay bare, which avoids the case-sensitivity that quoting would introduce on oracle/pg.

**Plain identifiers only**: for expressions such as `sum(col)` or `col as alias` keep using `@value` (safety is then on you).

**Prerequisite: reserved-word quoting depends on the `spring.sqltoy.reservedWords` configuration, which has no default.** When it is not set the reserved-word set is empty, so `ReservedWordsUtil.convertWord` returns the name unchanged without any quoting; a field list containing a reserved word (`order`, `desc`, `level`, `group`, ...) then produces a bare identifier that the database rejects — verified to fail on three databases: PostgreSQL `ERROR: syntax error at or near ","` (the `order` in `select order,staff_code` is parsed as the `ORDER BY` keyword), MySQL `You have an error in your SQL syntax`, and SQL Server `Incorrect syntax near the keyword 'order'`. So **configure the reserved-word list whenever field names may hit one**:

```properties
spring.sqltoy.reservedWords=order,desc,level,group,key,comment
```

With it configured the same query renders as `select "order",staff_code` on PostgreSQL, ``select `order`,staff_code`` on MySQL and `select [order],staff_code` on SQL Server — all three were verified to execute and return the column values.

Also note that the `IllegalArgumentException` thrown on validation failure is wrapped into a `DataAccessException` by the DAO layer, so look at the root cause (the end of the `getCause()` chain) when catching it; the message carries the offending value.

**Constraint:** as with `@loop` and the other macros, when the SQL has no parameters at all it returns early and the macro is not expanded; real report queries always have `:fields`, so this does not bite in practice.

**Example:**

```xml
<sql id="report_columns">
	select @joinFields(:cols,{t.*}),count(1) total
	from sqltoy_staff_info t
	#[where t.status=:status]
	group by @joinFields(:cols,{t.organ_id})
</sql>
```

```java
// the page configuration decides which columns to select and group by
List result = lightDao.find("report_columns",
        MapKit.keys("cols", "status").values("organ_id,dept_id", 1));
```

## 9. @df() / @day() (date formatting)

Formats a date into a string and splices it into the SQL — **no knowledge of the target database's date functions required** (this is **string concatenation**, not database function replacement).

```text
@df(format)               → current time rendered with the format
@df(param, format)        → the parameter value rendered with the format
@day(...)                 → exactly equivalent to @df (historical alias)
```

- The default format is `yyMMdd`;
- An empty or `null` format **emits an empty string** (`@df('')` is a way to omit a whole condition);
- The parameter may be a named parameter (`@df(beginDate, yyyy-MM-dd)`) or the `${beginDate}` form, or a literal; **do not write `:beginDate`** — macro arguments are looked up in the parameter map, whose keys carry no colon.

```xml
<sql id="query_by_month">
	select * from sqltoy_order_info t
	where t.trans_month = '@df(yyyyMM)'
	#[and t.trans_date >= '@df(beginDate, yyyy-MM-dd)']
</sql>
```

> Difference from the [`<to-date>`](en/query/dynamic_sql.md) filter: `@df` formats the **value into SQL text** (producing a literal), while `<to-date>` converts the **parameter to a date type and still binds it as `?`**. Prefer `<to-date>` for external input; `@df` suits report concatenation and partition-table names.

## 10. @case() (decode-style enumeration)

A `decode`-like value mapping that turns a parameter value into the matching string or SQL fragment:

```text
@case(param, value1, result1, value2, result2, ..., defaultResult)
```

- The parameter may be a named parameter (`@case(orderType, ...)`) or the `${orderType}` form;
- Fewer than three parameters emits an empty string;
- **The last parameter is the default result** (emitted when nothing matches).

```xml
<!-- splice a different ORDER BY per order type -->
select * from sqltoy_order_info t
where t.status=1
order by @case(orderType,'SALE','t.sale_date desc','BUY','t.buy_date desc','t.create_time desc')
```

> The same macro is used for business keys — see [Primary Key Strategies · @BusinessId](en/primarykey/sqltoy_primarykey.md).

## 11. @substr() / @substring() (substring)

```text
@substr(param, startIndex, length)
```

- `startIndex` is 0-based; **a negative value means taking from the tail**;
- A start index at or beyond the string length emits an empty string;
- A blank parameter emits an empty string; `@substring` and `@substr` are equivalent.

```xml
<!-- use the first two characters of the order id as the business line -->
select * from sqltoy_order_info t
where t.biz_line = '@substr(orderId,0,2)'
```

## 12. @virtualTable() (cross-database dummy table)

"select constant rows union real query" SQL (dictionary dropdown fallback rows, fixed report total rows, etc.) needs a pseudo-table on oracle/db2/hana, while mysql/pg/sqlserver error out on `from dual`. This macro expands per dialect at parse time:

```sql
select '0' id,'Global' name @virtualTable()
union
select id,name from sqltoy_dict_detail where status=1
```

- oracle family (oracle/oracle11/dm/oceanbase) → `from dual`; db2 → `from sysibm.sysdummy1`; hana → `from dummy`; stripped for every other dialect;
- Compatible aliases `@dual()` / `@dummyTable()` — all three equivalent, case-insensitive, tolerant of spaces inside the parentheses; may appear several times in one SQL;
- SQL without the macro is completely unaffected; see [Dialect Adaptation & Functions](en/dialect/sqltoy_function.md).

---

## 13. @split() (split a parameter into an array)

Splits **one string parameter** into an array by a separator, then feeds it to collection-expansion mechanisms such as `in` — the typical case is the frontend sending a single `"A;B;C"` string while the SQL writes `field in (...)` directly, saving a manual split on the Java side. Handled by `SqlConfigParseUtils` at SQL parse time.

Three forms:

```sql
-- 1. default comma separator (split by the regex \s*,\s*, tolerant of blanks)
select * from sqltoy_order_info t where t.status in (@split(:statusStr))

-- 2. explicit separator (single or double quotes allowed)
select * from sqltoy_order_info t where t.status in (@split(:statusStr,';'))

-- 3. explicit separator plus numeric conversion (each segment to Integer, blank segments skipped)
select * from sqltoy_order_info t where t.status in (@split(:statusStr,int,','))
```

Notes:

- `@split(...)` is replaced back to `?` at execution time, the split array is put back into the corresponding parameter slot, and then automatically expanded into multiple `?` placeholders by the collection-expansion mechanism;
- Splitting happens only when the parameter value is a `String`; every segment is trimmed automatically, and leading/trailing quotes on the parameter are stripped first;
- Without a second argument the default separator is the comma (`\s*,\s*`).

Java call (the frontend just sends one string):

```java
List rows = lightDao.findByQuery(
        new QueryExecutor("sqltoy_order_info_find")
            .names("statusStr").values("1,2,3")   // a single string; no need to pass an array
            .resultType(OrderVO.class))
        .getRows();
```

---

> Related: [`#[]` and filters](en/query/dynamic_sql.md), [Common SQL Examples](en/query/sql_showcase.md), [Pagination Optimize](en/query/pagination.md), [Annotations Cheat Sheet](en/appendix/annotations.md).
