# Best Picks

For CRUD, cascading, cross-database access, sharding and the like, sqltoy differs little from hibernate/mybatis. What sqltoy really wants to share is a **different way of thinking** — the "killer features" below are high-value capabilities distilled from extensive project practice.

## 1. The perfect SQL style

Requirement: query the order table with conditions covering a transaction date range, order status, organization, employee and order number.

**The mybatis way** (`<if>` tags interleaved with the SQL — verbose and error-prone):

```xml
<select id="findOrder" resultType="OrderInfoVO">
    select * from sqltoy_order_info t
    <where>
        <if test="beginDate!=null"> and t.trans_date &gt;= #{beginDate} </if>
        <if test="endDate!=null"> and t.trans_date &lt;= #{endDate} </if>
        <if test="status!=null"> and t.status=#{status} </if>
        <if test="organId!=null"> and t.organ_id=#{organId} </if>
        <if test="staffCode!=null"> and t.staff_code=#{staffCode} </if>
        <if test="orderId!=null"> and t.order_id=#{orderId} </if>
    </where>
</select>
```

**The sqltoy way** (clean SQL that can be copied straight into a database client and run; when a parameter is null the corresponding fragment is dropped automatically):

```xml
<sql id="findOrder">
    <value><![CDATA[
        select * from sqltoy_order_info t
        where 1=1
        #[and t.trans_date>=:beginDate]
        #[and t.trans_date<=:endDate]
        #[and t.status=:status]
        #[and t.organ_id=:organId]
        #[and t.staff_code=:staffCode]
        #[and t.order_id=:orderId]
    ]]></value>
</sql>
```

The business meaning is obvious at a glance, which makes later maintenance, tuning and adjustment much easier. See [Dynamic SQL Guide](../query/dynamic_sql.md).

## 2. Fast pagination and count optimization

sqltoy provides intelligent pagination automatically, so developers don't need to know each database's pagination dialect. Its count query is **not** the brute-force `select count(1) from (your sql) as t`; instead it:

- removes unnecessary `order by` clauses;
- removes unnecessary function computations and irrelevant information between `select` and `from`;
- fully distinguishes `union` and `group` type queries.

Combined with `@fast()` (paginate first, then join) and `<page-optimize>` (count caching), a pagination request that normally costs 2 queries drops to about **1.35 queries**. See [Pagination Optimize](../query/pagination.md).

## 3. Cache Translate

Delegate the "code value → name" conversion to the cache instead of writing piles of `left join`. Without cache translate, multi-table-join SQL is long and slow; with it, the SQL stays concise and clear and efficiency improves by orders of magnitude. See [Cache Translate in Action](../quickstart/translates.md).

## 4. Function replacement (cross-database)

Object operations easily cross databases — but what about **hand-written SQL**? Can SQL written for MySQL run directly on Oracle/SQL Server? sqltoy gives the answer: on first load or dynamic execution it **automatically replaces functions in the SQL according to the database type** (e.g. `nvl`/`ifnull`/`isnull`, `concat`, `to_char`, `date_format`, etc.). See [Dialect Adaptation & Functions](../dialect/sqltoy_function.md).

## 5. Preventing SQL injection

Many people misunderstand how SQL injection works and try to defend by "filtering whether parameter values from the page contain SQL fragments" — entirely missing the point. For example, in `select * from table t where t.password=:password`, if password becomes `(select password from table where id=xxx)` such checks can be bypassed.

sqltoy eliminates the problem at its root: **all SQL parameters are ultimately converted into `?` placeholders and set via `PreparedStatement`**, so parameters are always treated as "values" and never as "SQL fragments".

```text
-- What you write:
select * from sqltoy_staff_info t where t.staff_name=:staffName
-- What actually executes:
select * from sqltoy_staff_info t where t.staff_name=?
```

In addition, the `<valid-sqlInjection>` filter can validate parameters against injection (see [Dynamic SQL Guide](../query/dynamic_sql.md)).

## 6. Comments are allowed inside SQL

sqltoy insists that developers copy SQL written in clients such as DBeaver **directly into the xml** (and copy it back from the xml into the client when debugging), so SQL may keep its comments:

- `--` and `/* */` comments are stripped automatically when the SQL is loaded;
- but `/*+ xxxx */` comments are **not** stripped — they usually serve as database hints for SQL performance tuning.

---

> For more practical patterns, see [Common SQL Examples](../query/sql_showcase.md) and [Tags & Expressions Reference](../appendix/tags.md).
