# Tags & Expressions Reference

In addition to [`#[]` dynamic condition fragments](../query/dynamic_sql.md), sqltoy reserves a set of `@` macro directives inside SQL for extremely complex dynamic SQL scenarios. Combining `@if`, `@value` and `@blank` flexibly solves 99.99% of problems; for ultra-complex cases, the recommended approach is to assemble the SQL fragment in code and embed it with `@value(:sqlScript)`.

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

`@fast()` is written inside the SQL for [fast pagination](../query/pagination.md) (paginate first, then join). **For non-paged queries the framework automatically strips `@fast`**, so it does not affect find/findTop or other queries. `@fast` and `@fastPage` are equivalent.

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

Typical usage: `@value(:sqlScript)` embeds a SQL fragment assembled in code, handling ultra-complex dynamic SQL.

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

**Notes:**

- Inner parameters are comma-separated; if `loopContent` contains commas, wrap the content with `{}`, `''` or `""` to ensure it is split correctly.
- Sub-object property patterns such as `staffInfos[i].xxxx` are supported for extreme scenarios.
- When an in-condition parameter array exceeds 1000 entries (e.g. the Oracle limit), the framework (since 5.1.32 / 4.19.25) **splits it automatically**.
- `@secure-loop` is supported since version 5.1.44.

**Example:**

```text
@secure-loop(:staffIds, { t.STAFF_ID=:staffIds[i] }, { or })
```

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

---

> Related: [`#[]` and filters](../query/dynamic_sql.md), [Common SQL Examples](../query/sql_showcase.md), [Pagination Optimize](../query/pagination.md).
