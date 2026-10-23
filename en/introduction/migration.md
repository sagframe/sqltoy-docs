# Migrating from MyBatis / MyBatis-Plus

SqlToy shares MyBatis's **dynamic-SQL mindset** (SQL in xml, conditions assembled on demand); what differs is how conditions are expressed and how strong the object operations are. Migration is normally **incremental**: let new queries go through sqltoy first, then convert the old mappers.

## 1. Concept mapping

| MyBatis / MyBatis-Plus | sqltoy | Notes |
| --- | --- | --- |
| `<select id="findXxx">` in a mapper XML | `<sql id="findXxx">` in `*.sql.xml` | Files are organized by module and hot-reload in debug mode |
| `<if test="x!=null"> and t.a=#{x}</if>` | `#[and t.a=:x]` | A null parameter removes the fragment automatically, and **the SQL can be pasted straight into a client** |
| `<where>` / `<trim prefixOverrides>` | `where 1=1` + `#[]` | No `<where>` wrapper needed |
| `#{}` | `:name` named parameter | Both end up as `?` through `PreparedStatement` |
| `${}` (string splicing) | `@value(:name)` / `@joinFields(:cols,default)` | Identifier scenarios get whitelist validation — see [Tags & Expressions](en/appendix/tags.md) |
| `<foreach collection="ids">` | `t.id in (:ids)` | Arrays/collections expand automatically and split above 1000 values |
| ResultMap + `<result column="A" property="a">` | Result type (VO/POJO) + `AS a` aliases | Use `@SqlToyFieldAlias` when names differ |
| `<collection>` nested mapping | Hierarchy packaging (hiberarchy) or a flat VO | One join SQL packs parent-child objects — see [Query API](en/query/sqltoy_query.md) |
| Pagination plugins (PageHelper etc.) | `findPage` | Automatic count optimization + `@fast` + parallel pagination |
| `@Select` annotation | `@Sql` annotation / SQL in code | Complex SQL still belongs in xml |
| MP `QueryWrapper` / `LambdaQueryWrapper` | `EntityQuery` / `LambdaQuery` | The former takes string conditions, the latter property references |
| MP `BaseMapper` / `IService` | `LightDao` / `SqlToyCRUDService` | `LightDao` has ~110 methods — see [API Cheat Sheet](en/appendix/api.md) |
| MP `@TableLogic` logical delete | Shared SQL fragment / interceptor | sqltoy has no built-in logical delete; use a common `<sql>` fragment or a `SqlInterceptor` |
| MP `@Version` optimistic lock | `@DataVersion` | See [Data Versioning](en/enterprise/data_version.md) |
| MP `@TableField(fill=...)` | `unifyFieldsHandler` | Unified gap-filling — see [Common-Field Auto-Fill](en/quickstart/helloworld_improve.md) |

## 2. Suggested rollout order

1. **Dependencies and configuration**: add `sagacity-sqltoy-spring-starter`, configure `sqlResourcesDir` + `debug=true` — see [Environment & Dependencies](en/prepare/environment.md);
2. **Create the SQL directory**: one `*.sql.xml` per module (e.g. `com/acme/crm/modules/staff.sql.xml`); write **new requirements** in sqltoy form first and leave the old mappers alone;
3. **Generate POJOs**: use [quickvo](en/prepare/quickvo.md) against the existing tables (fully annotated — do not hand-write them);
4. **Convert queries** (best payoff, lowest risk): start with the query that has the most conditions and is hardest to maintain, following section 3;
5. **Convert writes**: replace "load, modify, update" with elastic updates; high-concurrency ledgers become `updateSaveFetch` (select-or-insert-and-modify);
6. **Run the old and new side by side**: compare result sets for a while. `redoDataSources` can replay the new SQL on another database for verification — see [Multi-DB Verification](en/dialect/multi_db_verify.md).

## 3. Typical rewrites

### 3.1 Multi-condition dynamic query

```xml
<!-- MyBatis -->
<select id="findOrder">
    select * from sqltoy_order_info t
    <where>
        <if test="beginDate!=null"> and t.trans_date &gt;= #{beginDate} </if>
        <if test="endDate!=null"> and t.trans_date &lt;= #{endDate} </if>
        <if test="status!=null and status!=''"> and t.status=#{status} </if>
        <if test="orderId!=null and orderId!=''"> and t.order_id=#{orderId} </if>
    </where>
</select>
```

```xml
<!-- sqltoy: conditions do not fragment the SQL, which stays runnable in a client -->
<sql id="findOrder">
    <value><![CDATA[
        select * from sqltoy_order_info t
        where 1=1
        #[and t.trans_date>=:beginDate]
        #[and t.trans_date<=:endDate]
        #[and t.status=:status]
        #[and t.order_id=:orderId]
    ]]></value>
</sql>
```

"An empty string counts as not passed" is handled once by a filter rather than per condition:

```xml
<filters>
    <!-- blank strings become null, which removes the matching #[] fragment -->
    <blank params="status,orderId" />
</filters>
```

### 3.2 LIKE queries

```xml
<!-- MyBatis: concat('%',#{name},'%') -->
<!-- sqltoy: the framework adds the wildcards -->
#[and t.staff_name like :staffName]
<filters>
    <r-like params="staffName" />   <!-- appends %: starts with name -->
</filters>
```

### 3.3 IN collections and empty collections

```xml
#[and t.organ_id in (:organIds)]
```

- Passing a `List`/array expands to several `?`;
- **An empty collection skips the condition** (never produces `in ()`);
- More than 1000 values are split automatically (the Oracle limit).

### 3.4 Pagination

```java
// MyBatis-Plus
Page<OrderInfo> page = orderMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
```

```java
// sqltoy
Page<OrderInfoVO> page = lightDao.findPage(new Page(pageSize, pageNo),
        "crm_order_findlist", paramsMap, OrderInfoVO.class);
```

The count SQL is rewritten by the framework (order by removed, select list trimmed); for large-table join pagination use `@fast()` — see [Pagination Optimize](en/query/pagination.md).

### 3.5 Single-table conditional update

```java
// MyBatis-Plus
new LambdaUpdateWrapper<StaffInfo>()
        .set(StaffInfo::getStatus, 2)
        .eq(StaffInfo::getStaffId, id)
```

```java
// sqltoy: use lambda for single tables (reuses the entity path, so sharding/translate/tenant apply)
lightDao.lambdaUpdate(StaffInfo.class)
        .set(StaffInfo::getStatus, 2)
        .eq(StaffInfo::getStaffId, id)
        .update();

// or with string conditions
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create().set("status", 2).where("staff_id=?").values(id));
```

### 3.6 Load-then-update → elastic update / upsert (updateSaveFetch)

```java
// The usual MyBatis shape: load, decide, update (two interactions, and it can overwrite a concurrent change)
OrderInfo o = mapper.selectById(id);
o.setStatus(2);
mapper.updateById(o);
```

```java
// sqltoy elastic update: update itself is elastic — one interaction, null fields are skipped
// (you never wipe a field someone else changed, no hand-written update set fragment)
OrderInfo orderInfo = new OrderInfo();
orderInfo.setOrderId(id);
orderInfo.setStatus(2);
lightDao.update(orderInfo);

// High-concurrency "select-or-insert-and-modify": one interaction — lock-query, update if exists
// or insert if not, return the result. uniqueProps names the business unique-key properties
// (falls back to the primary key when omitted). Inside the callback the entity is a proxy:
// get reads the current DB value, set writes back to the current row; a thrown exception rolls back.
OrderInfo entity = new OrderInfo();
entity.setOrderId(id);
entity.setStatus(2);
OrderInfo order = lightDao.updateSaveFetch(
        entity,
        (loaded, rowIndex) -> {
            if (!"1".equals(loaded.getStatus())) {
                throw new IllegalStateException("status already changed, please refresh and retry");
            }
            loaded.setStatus(2);
        },
        "orderId");
```

> If the record is **guaranteed to exist** and you need freely-defined query conditions and locking, use `updateFetch` (sql + `UpdateRowHandler`, see [Object-Oriented CRUD §10](en/crud/sqltoy_crud.md)); for ledger-style "update if exists, insert if not", prefer `updateSaveFetch`.

### 3.7 Batch insert

```java
// MyBatis: foreach over values (the SQL length explodes with the data volume)
// sqltoy: batch APIs that split automatically (batchSize defaults to 200)
lightDao.saveAll(list);
lightDao.saveAllIgnoreExist(list);   // skip existing rows
```

## 4. Common pitfalls

| Symptom | Cause and fix |
| --- | --- |
| A parameter has no effect | Named parameters are **case-sensitive**, and the name inside `#[]` must match the Map key exactly |
| Every result property is null | Column and property names differ: add `AS` aliases, configure `humpMapResultTypeLabel`, or use `@SqlToyFieldAlias` |
| `in` raises a syntax error | String splicing was used instead of `:ids`; hand empty collections to the framework |
| The paged total is smaller than the data | `@fast` plus an outer join filter makes the count use the inner SQL; supply `<count-sql>` explicitly — see [FAQ 10](en/faq/faq.md) |
| Dynamic SQL needs an identifier | Never splice user input with `@value`; use `@joinFields` (whitelist) or `<valid-sqlInjection>` |
| Logical-delete conditions everywhere | There is no built-in logical delete; inject it once with an `@include`d `<sql>` fragment or a `SqlInterceptor` |
| Transaction behaviour differs | Object operations still honour Spring `@Transactional`; for multiple datasources see [Multi-Datasource & Transactions](en/config/dynamic_datasource.md) |

## 5. What you gain

- **Querying**: native-shaped SQL (paste it into a client), smart counts, `@fast`, parallel pagination, join-free cache translate;
- **Writing**: elastic update / `updateFetch` / `updateSaveFetch` collapse "several interactions plus manual locking" into one call;
- **Cross-database**: 25 dialects with automatic function replacement, so one SQL runs on many databases;
- **Analytics**: pivot/unpivot, YoY/MoM and tree rollups happen in memory, so you no longer write a different SQL per database.

> Related: [Best Picks](en/best/best_practices.md) (side-by-side sqltoy vs MyBatis), [Feature List](en/introduction/feature.md), [API Cheat Sheet](en/appendix/api.md)
