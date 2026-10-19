# Lambda Conditions

> Available since 6.0.8. Build query, update and delete conditions from **entity property method references** (e.g. `StaffInfo::getStatus`), so a misspelled property is caught at compile time. Single-table and multi-table joins share one builder — whether a query is a join is decided by whether you call a join step.

## 0. Positioning and division of labour

sqltoy offers three ways to organize a query; pick by scenario:

| Approach | Good for | Entry point |
| --- | --- | --- |
| **Lambda conditions** (this page) | Everyday conditional queries over one or more joined tables; conditional update/delete with conditions expressed as property references | `lightDao.lambdaQuery/lambdaUpdate/lambdaDelete` |
| **EntityQuery/EntityUpdate** | Single-table string conditions (where text + named parameters) | `lightDao.findEntity/updateByQuery` etc. |
| **SQL mode** (sqlId + `#[...]` segments + `@if` macros) | Complex dynamic SQL, multi-branch condition combinations, dialect variants, configurable reports | `lightDao.find/findPage` + sqlId, see [Dynamic SQL Guide](dynamic_sql.md) |

Dynamism in the lambda layer is expressed with the `IfPresent` sugar (see [Dynamic conditions](#dynamic-conditions)); **do not try to pile complex dynamic logic into the lambda layer — switch to SQL mode instead**, where segments, macros, dialect variants and hot reload already exist.

On the **single-table channel** a lambda query converts conditions into `EntityQuery`/`EntityUpdate` and inherits every entity-level capability (sharding, cache translate, encryption/masking, tenant filtering, unified update fields). On the **join channel** it assembles full SQL and goes through the native SQL path, so entity-level enhancements no longer apply (a multi-table SQL cannot use single-entity enhancements by nature).

---

## 1. Entry points and builders

```java
LambdaQuery<T>  lightDao.lambdaQuery(Class<T> entityClass);   // query (single table or join)
LambdaUpdate<T> lightDao.lambdaUpdate(Class<T> entityClass);  // update (single table or join)
LambdaDelete<T> lightDao.lambdaDelete(Class<T> entityClass);  // delete (single table or join)
```

A builder is a single mutable object; every method returns itself, so **chained and imperative styles can be mixed freely**:

```java
LambdaQuery<StaffInfo> query = lightDao.lambdaQuery(StaffInfo.class);
if (status != null) {
    query.eq(StaffInfo::getStatus, status);
}
List<StaffInfo> list = query.orderByDesc(StaffInfo::getEntryTime).find();
```

> **Note**: the `if` above only demonstrates that "the builder is a single mutable object, so imperative control flow (if/for) mixes freely with chaining" — it is **not** a recommendation to null-check by hand. The normal way to say "skip this condition when the value is null" is `eqIfPresent`, one line, no hand-written `if` (see [Dynamic conditions](#dynamic-conditions) later):

```java
List<StaffInfo> list = lightDao.lambdaQuery(StaffInfo.class)
        .eqIfPresent(StaffInfo::getStatus, status)   // skipped automatically when status is null
        .orderByDesc(StaffInfo::getEntryTime)
        .find();
```

You can also build first and execute later: a builder created with `LambdaQuery.create(...)` is not bound to a dao, so terminals are unavailable until you call `bind(lightDao)` (handy when a service layer assembles conditions and execution happens after crossing layers):

```java
LambdaQuery<StaffInfo> query = LambdaQuery.create(StaffInfo.class).eq(StaffInfo::getStatus, 1);
List<StaffInfo> list = query.bind(lightDao).find();
```

> `LightDao` exposes only three lambda factories (`lambdaQuery/lambdaUpdate/lambdaDelete`); **all execution is driven by builder terminals**, the dao offers no execution overloads.

Query terminals at a glance:

| Terminal | Semantics |
| --- | --- |
| `find()` | All matching rows |
| `getOne()` | A single row: **0 rows returns null, more than 1 throws `DataAccessException`** (multiple matches mean the condition is defective; the first row is never taken silently) |
| `findPage(Page)` | Pagination, `new Page(pageSize, pageNo)` |
| `findTop(n)` / `findTop(0.2)` | First n rows / first 20% (greater than 1 means a row count, less than 1 a ratio), ordered by `orderBy` |
| `findRandom(n)` / `findRandom(0.2)` | n random rows / a random ratio |
| `count()` / `exists()` | Row count / whether anything matches |

### Choosing a datasource (multiple datasources / read-write splitting)

Builders offer `.dataSource(DataSource)` to pin the operation to a datasource; without it the dao's default datasource is used. Consistent with existing sqltoy practice (`EntityQuery` / `QueryExecutor` / `lightDao.update().dataSource(...)`), it **works for every terminal on both the single-table and join channels — query, count, update and delete**:

```java
// single-table query against a read-only replica
List<StaffInfo> list = lightDao.lambdaQuery(StaffInfo.class)
        .dataSource(readOnlyDs).eq(StaffInfo::getStatus, 1).find();

// join update against a specific database
lightDao.lambdaUpdate(StaffInfo.class).dataSource(ds2)
        .leftJoin(Depart.class).on(StaffInfo::getDeptId, Depart::getId)
        .set(StaffInfo::getStatus, 2).eq(Depart::getDeptName, "R&D").update();
```

> The single-table channel passes the datasource through `EntityQuery/EntityUpdate`; the join channel passes it through sqltoy's existing `query()`/`execute()` chain builders (query/count use `query().dataSource(ds)`, update/delete use `execute().dataSource(ds)` — both already supported datasource selection); for a join delete with several targets the transaction runs on the datasource you specified. A null `dataSource` behaves exactly as if it were not set.

### Pagination optimization (parallel count + keep-alive cache)

`findPage` can reuse sqltoy's existing pagination optimization through `.pageOptimize(PageOptimize)` (when unset, the global `SqlToyConfig.pageOptimize` applies). Two common knobs: **`parallel(true)`** runs the count and the data query in parallel; **`aliveSeconds(n)`** caches the count for n seconds (keep-alive), so paging skips the count query while the cache is warm:

```java
Page<StaffInfo> page = lightDao.lambdaQuery(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1)
        .pageOptimize(new PageOptimize().parallel(true).aliveSeconds(120))
        .findPage(new Page(20, 1));
```

`PageOptimize` also offers `aliveMax` (cache entry limit), `skipZeroCount` (skip the data query when the first page counts 0) and `parallelMaxWaitSeconds` (parallel wait limit). Both channels are covered (single table through `EntityQuery`, join through `QueryExecutor`).

---

## 2. Single-table queries

### Condition methods

Every condition method has a `(boolean condition, ...)` overload; when `condition` is false the condition does not participate in the SQL:

| Method | SQL shape |
| --- | --- |
| `eq / ne / gt / ge / lt / le` | `column = :p1`, `<>`, `>`, `>=`, `<`, `<=` |
| `between / notBetween` | `column BETWEEN :p1 AND :p2` |
| `like / notLike` | `column LIKE :p1` / `NOT LIKE :p1`; the `%value%` wildcards are wrapped into the parameter value (contains match) |
| `likeLeft / likeRight` | `LIKE :p1` with the value as `%value` (ends with) / `value%` (starts with) |
| `isNull / isNotNull` | `column IS NULL` / `IS NOT NULL` |
| `in(Collection)` / `in(values...)` | `column IN (:p1)`; empty collections/arrays are skipped automatically |
| `notIn(Collection)` / `notIn(values...)` | `column NOT IN (:p1)` |
| `inSql(column, subQuery[, paramMap])` | `column IN (subQuery)`; sqltoy named parameters of the sub-query come from the Map |
| `inb(colA, colB, tupleCollection)` | Multi-column tuple IN: a single column degenerates to `column IN (:p1,:p2…)`; several columns expand to OR-of-ANDs `((a=:p1 AND b=:p2) OR (a=:p3 AND b=:p4)…)`, avoiding row-value IN dialect differences on SQLServer/DB2 etc. |

```java
List<StaffInfo> list = lightDao.lambdaQuery(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1)
        .like(StaffInfo::getStaffName, "Smith")
        .between(StaffInfo::getEntryTime, start, end)
        .in(StaffInfo::getOrganId, organIds)
        .orderByDesc(StaffInfo::getEntryTime)
        .find();
```

### exists / notExists correlated sub-queries

A sub-query is built with the same lambda style; to reference an outer column use `OuterRef.of(outerField)` (type-safe, no hand-written table name or alias):

```java
// single-table channel: there exists an organ row that is enabled and matches the staff's organ id
lightDao.lambdaQuery(StaffInfo.class)
        .exists(OrganInfo.class, sub -> sub
                .eq(OrganInfo::getStatus, 1)
                .eq(OrganInfo::getOrganId, OuterRef.of(StaffInfo::getOrganId)))  // references the outer column
        .find();
// ... WHERE ... AND EXISTS (SELECT 1 FROM organ_table sq1 WHERE sq1.STATUS = :p2 AND sq1.ORGAN_ID = staff_table.ORGAN_ID)

// the join channel works the same way; the outer column is rendered with the outer alias (e.g. s1.ORGAN_ID)
lightDao.lambdaQuery(StaffInfoVO.class).selectAll()
        .from(StaffInfo.class).leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .notExists(BlackList.class, sub -> sub.eq(BlackList::getStaffId, OuterRef.of(StaffInfo::getStaffId)))
        .find();
```

Rules and boundaries:

- `OuterRef` only supports the six comparison methods `eq/ne/gt/ge/lt/le` (passing it to between/like/in throws); using it outside a sub-query also throws;
- On the single-table channel the outer column renders as `table.column`, on the join channel as `alias.column` — inside the sub-query it must be qualified, otherwise a same-named column becomes ambiguous;
- Sub-query table aliases use the `sq` prefix (`sq1`, `sq2`…), so they never collide with the outer single-letter aliases; nested exists supports several levels;
- Sub-query parameters share the named-parameter sequence with the outer query (`:p1, :p2…` are globally unique);
- The sub-query entity must match the entity that owns the sub-condition fields, otherwise assembly throws.

The `exists()` terminal (does any matching row exist) is implemented as `findTop(1)` and stops at the first hit — no full count aggregation.

### Logical composition and nesting

```java
// and/or connectors, nested parentheses, not negation (one grouping level)
lightDao.lambdaQuery(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1)
        .or(n -> n.eq(StaffInfo::getOrganId, "O001").eq(StaffInfo::getStaffName, "Zhang San"))
        .not(n -> n.isNull(StaffInfo::getMobile))
        .find();
// → status = :p1 OR (organ_id = :p2 AND staff_name = :p3) AND NOT (mobile IS NULL)

// multi-level grouping: the argument n of nested/and/or/not is the same builder type and nests further, unlimited depth
lightDao.lambdaQuery(StaffInfo.class)
        .nested(outer -> outer
                .nested(inner -> inner.eq(StaffInfo::getOrganId, "O001").or().eq(StaffInfo::getOrganId, "O002"))
                .eq(StaffInfo::getStatus, 1))
        .or().eq(StaffInfo::getStaffId, "S009")
        .find();
// → ((organ_id = :p1 OR organ_id = :p2) AND status = :p3) OR staff_id = :p4

// accept: reuse a block of conditions merged into the current level (no parentheses); nested: an independent group (parenthesized)
lightDao.lambdaQuery(StaffInfo.class).eq(StaffInfo::getStatus, 1)
        .accept(q -> q.eq(StaffInfo::getOrganId, "O001").eq(StaffInfo::getStaffName, "Zhang San")).find();
// → status = :p1 AND organ_id = :p2 AND staff_name = :p3
lightDao.lambdaQuery(StaffInfo.class).eq(StaffInfo::getStatus, 1)
        .nested(q -> q.eq(StaffInfo::getOrganId, "O001").eq(StaffInfo::getStaffName, "Zhang San")).find();
// → status = :p1 AND (organ_id = :p2 AND staff_name = :p3)

// last appends a raw SQL fragment (injection risk — use with care)
lightDao.lambdaQuery(StaffInfo.class).eq(StaffInfo::getStatus, 1).last("limit 10").find();
```

Adjacent conditions get an automatic `AND`; adjacent explicit `and()/or()` connectors are merged keeping the last one; leading/trailing dangling connectors are stripped; every nesting level is wrapped in parentheses, **with no depth limit** (in practice constrained by JVM stack depth and the target database's expression nesting limit — 1~3 levels is effortless, and extremely complex dynamic grouping should go to SQL mode). **Empty groups are dropped automatically**: when every condition inside a group is skipped by `condition=false` or `IfPresent`, the whole group disappears together with its surplus connectors, so illegal `()` SQL is never rendered — dynamic groups are therefore safe to write, and a group simply stops participating when its parameters are missing.

### Grouping, sorting and aggregate filtering

```java
lightDao.lambdaQuery(StaffInfo.class)
        .groupBy(StaffInfo::getOrganId)
        .having("count(*) > :min", MapKit.map("min", 5))
        .orderByAsc(StaffInfo::getOrganId)
        .orderByDesc(StaffInfo::getEntryTime)   // several orderBy calls merge into one clause
        .find();
```

With grouping/sorting but no where condition, `1 = 1` is added as the where clause automatically.

### Selecting specific columns

```java
lightDao.lambdaQuery(StaffInfo.class)
        .select(StaffInfo::getStaffId, StaffInfo::getStaffName)   // property form
        .eq(StaffInfo::getStatus, 1)
        .find();
```

### Dynamic conditions

**The recommended idiom is the `IfPresent` sugar**: the condition is skipped when the value is null (a blank string for strings, an empty collection for collections):

| Method | Skipped when |
| --- | --- |
| `eqIfPresent / neIfPresent / gtIfPresent / geIfPresent / ltIfPresent / leIfPresent` | the value is null |
| `likeIfPresent` | a blank string |
| `inIfPresent(Collection)` / `inIfPresent(values...)` / `notInIfPresent(Collection)` | the collection/array is null or empty |
| `betweenIfPresent(v1, v2)` / `betweenIfPresent(array)` | both are null; a half-open range degrades automatically: only a lower bound becomes `ge`, only an upper bound becomes `le` |

```java
// the typical page-query style: include the condition only when the parameter is present
lightDao.lambdaQuery(StaffInfo.class)
        .eqIfPresent(StaffInfo::getStatus, status)
        .likeIfPresent(StaffInfo::getStaffName, name)
        .inIfPresent(StaffInfo::getOrganId, organIds)
        .betweenIfPresent(StaffInfo::getEntryTime, start, end)
        .find();
```

A skipped condition never resolves its column name during assembly, so it has no side effects. **For more complex dynamic combinations (multiple branches, dialect differences, configurability) use SQL mode.**

### Value filtering

Null values are filtered by default; an instance-level strategy can be set before adding conditions:

```java
lightDao.lambdaQuery(StaffInfo.class)
        .valueFilter(v -> v != null && !"".equals(v))   // instance-level, not a global static
        .eq(StaffInfo::getStaffName, name)
        .find();
```

---

## 3. Single-table updates

```java
lightDao.lambdaUpdate(StaffInfo.class)
        .set(StaffInfo::getStatus, 2)
        .setExpr(StaffInfo::getLoginCount, "loginCount + 1")   // computed from the current value
        .eq(StaffInfo::getStaffId, staffId)
        .update();
```

### setExpr expression updates

| Form | Example | Notes |
| --- | --- | --- |
| Literal expression | `.setExpr(U::getLoginCount, "loginCount + 1")` | Fields inside the expression are written as **property names** and converted to database columns at execution time; other columns of the same table may be referenced |
| `?` placeholder binding | `.setExpr(U::getSalary, "salary * ?", rate)` | A single `?` binds the second argument |
| `:name` named parameter | `.setExpr(U::getSalary, "salary * :rate", rate)` | Supported on the single-table channel (reusing the expression-set capability of updateByQuery) |

The `=` character is **not allowed inside the expression** (the assignment equals sign is assembled by the framework); passing one throws.

Default value filtering skips `set(col, null)`. To set a column to null explicitly use `setNull`:

```java
lightDao.lambdaUpdate(StaffInfo.class).setNull(StaffInfo::getMobile).eq(StaffInfo::getStaffId, id).update();
```

### Safety boundaries

- **An update/delete with no where condition throws `DataAccessException` by default**; an explicit `.matchAll()` is required to allow it — this prevents accidental whole-table writes;
- When the where clause is a literal (no named parameters) `1=:DEFAULT_VALUE` is added internally as a fallback, sidestepping the parameter-count validation invisibly to the caller;
- **Whole-entity updates (by primary key) are not offered in the lambda layer**; use the existing path: `lightDao.update(entity)` / `lightDao.update(entity, forceUpdateProps)`.

---

## 4. Single-table deletes

```java
lightDao.lambdaDelete(StaffInfo.class)
        .eq(StaffInfo::getStatus, 0)
        .delete();

// an unconditional delete must be explicitly allowed
lightDao.lambdaDelete(StaffInfo.class).matchAll().delete();
```

The delete builder only supports where conditions (no select/orderBy), keeping its responsibilities separate from the query builder.

---

## 5. Multi-table join queries

Calling a join step on the same `LambdaQuery` switches it to the join channel — **a single-table query is merely the degenerate form of a join**:

```java
public class StaffInfoVO {
    private String staffId;
    private String staffName;
    private String organName;    // from the joined table
    // getters/setters
}

List<StaffInfoVO> rows = lightDao.lambdaQuery(StaffInfoVO.class)
        .selectAll(ExcludeCols.of(StaffInfo::getStatus))          // all main-table columns except status
        .from(StaffInfo.class)                                    // required when the result type is a VO
        .leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .select(JoinCol.of(OrganInfo::getOrganName).as("organName"))  // extra column + result alias
        .eqIfPresent(StaffInfo::getStatus, status)
        .orderByAsc(StaffInfo::getStaffId)
        .find();
```

Generated SQL (columns qualified by their entity alias; the `AS` aliases map to result object properties):

```sql
SELECT s1.STAFF_ID AS staffId, s1.STAFF_NAME AS staffName, o2.ORGAN_NAME AS organName
FROM sqltoy_staff_info s1 LEFT JOIN sqltoy_organ_info o2 ON s1.ORGAN_ID = o2.ORGAN_ID
WHERE s1.STATUS = :p1
ORDER BY s1.STAFF_ID ASC
```

### Join steps

| Method | Notes |
| --- | --- |
| `from(entityClass)` | Specifies the main table; **may be omitted** — in a query it defaults to the result type (it must be given when the result type is a non-entity such as a VO) |
| `leftJoin / rightJoin / innerJoin(entityClass)` | Starts a join and returns the on step; the first call switches to the join channel |
| `on(fieldA, fieldB)` | Equality join; two field pairs may be passed to one join (combined with AND); returns the query builder so further joins or conditions can follow |

Table aliases are the entity class initial in lower case plus a sequence number (`s1`, `o2`…). A join without `on()`, or a condition referencing an entity that does not participate in the join, throws during assembly.

### Forms of select

| Form | Semantics |
| --- | --- |
| no select | When the result type participates in the join, all of its columns are selected (`column AS property`); otherwise `*` |
| `selectAll()` | Explicitly declares all main-table columns; may coexist with extra `select(JoinCol...)` columns (main-table columns first) |
| `selectAll(Entity.class)` | Merges all columns of a **joined entity** into select as `alias.column AS property` (columns duplicating the main table are skipped); the entity must participate in the join, otherwise assembly throws |
| `selectAll(ExcludeCols.of(A::getX, A::getY))` | All main-table columns **excluding** the given ones; excluded fields must belong to the main entity; on the single-table channel it maps to `EntityQuery.unselect` |
| `select(JoinCol...)` | Explicit columns: `JoinCol.of/count/sum/avg/min/max(field).as(alias)`; its presence routes to the join channel, and it is also used for single-table grouping/aggregation (with `from(mainTable)` + `groupBy` + `having`) |
| `select(JoinCol.raw("..."))` | **Raw SQL fragment column**: shapes a typed select cannot express (window functions such as `ROW_NUMBER() OVER(..)`, database-specific functions, `CASE WHEN`, arithmetic expressions). `JoinCol.raw(fragment).as(alias)`, or inline `... AS alias` inside the fragment; it is spliced into SELECT verbatim and triggers the join channel (results map to a VO field with that alias) |
| `distinct()` | Distinct results: the single-table channel maps to `EntityQuery.distinct()`, the join channel renders `SELECT DISTINCT` (DISTINCT is a quantifier, not a function, so no column-function form is provided) |

`JoinCol.raw(...)` fills the blind spots of a typed select (window functions, for instance); the fragment references **real database column names / table aliases** (unqualified column names are fine for a single table, multi-table queries use the generated aliases such as `j1`):

```java
// window function: rank by salary, rn maps to the VO's rankNo field
List<StaffRankVO> ranks = lightDao.lambdaQuery(StaffRankVO.class)
        .select(JoinCol.of(StaffInfo::getStaffName).as("staffName"),
                JoinCol.raw("ROW_NUMBER() OVER(ORDER BY SALARY DESC)").as("rankNo"))
        .from(StaffInfo.class)
        .find();
// → SELECT s1.STAFF_NAME AS staffName, ROW_NUMBER() OVER(ORDER BY SALARY DESC) AS rankNo FROM sys_staff_info s1
```

> `JoinCol.raw` and `last(sql)` are both **raw SQL escape hatches**: the framework splices them verbatim without injection screening, so **never splice end-user input into them**; when working across databases, mind the portability of the fragment itself (window function syntax differs between databases).

### Grouping and aggregation (sum/avg/min/max/count)

Aggregate columns use `JoinCol`'s function factories together with `groupBy`/`having`; **single-table grouping and aggregation needs no join** — `JoinCol` switches the query to the SQL channel, where `from(mainTable)` names the aggregation subject:

```java
public class OrganSalaryStatVO {
    private String organId;
    private BigDecimal totalSalary;
    private BigDecimal avgSalary;
    private Long staffCount;
    // getters/setters
}

List<OrganSalaryStatVO> stats = lightDao.lambdaQuery(OrganSalaryStatVO.class)
        .select(JoinCol.of(StaffInfo::getOrganId).as("organId"),
                JoinCol.sum(StaffInfo::getSalary).as("totalSalary"),
                JoinCol.avg(StaffInfo::getSalary).as("avgSalary"),
                JoinCol.count(StaffInfo::getStaffId).as("staffCount"))
        .from(StaffInfo.class)
        .eqIfPresent(StaffInfo::getStatus, status)
        .groupBy(StaffInfo::getOrganId)
        .having("sum(SALARY) > :min", MapKit.map("min", 10000))   // having is raw SQL; named params via Map
        .find();
```

Aggregating in a join scenario is written the same way, with one extra `leftJoin(...).on(...)`; the `having` text is raw SQL (write real column names), and rows whose grouping key is null take part in the aggregation as well (standard SQL behaviour). To sort aggregate results, sort by the alias:

```java
.groupBy(StaffInfo::getOrganId)
.orderByDesc("staffCount")   // sort by the alias defined via "as" in select; only effective on the join channel
```

The single-table channel has no column aliases, so calling an alias sort there throws during assembly; aliases must be plain identifiers (anti-injection).

### Result mapping and LEFT JOIN

A column maps when its `AS` alias equals a property name of the result type; columns the result type does not have are ignored. With LEFT JOIN, properties of the joined table are null when there is no matching row.

### Terminals and limits of the join channel

`find/getOne/findPage/findTop/findRandom/count/exists` are all available; **the join channel does not inherit entity-level enhancements** (sharding, cache translate, masking, etc.) — an inherent boundary of multi-table SQL.

---

## 6. Multi-table join update and delete

Join updates/deletes use a **portable EXISTS-over-derived rewrite** (not the MySQL multi-table DML syntax): the join and where conditions go into a derived table, and the outer statement restricts rows by correlating the primary key through EXISTS. That preserves LEFT JOIN semantics in full and covers databases such as Oracle/PostgreSQL which have no multi-table `UPDATE ... JOIN` / `DELETE ... JOIN` syntax at all:

```sql
UPDATE target_table SET column = :p1 WHERE EXISTS (
    SELECT 1 FROM (SELECT alias.pk AS LPK1 FROM main_table alias LEFT JOIN ... WHERE conditions) sqd
    WHERE sqd.LPK1 = target_table.pk)

DELETE FROM target_table WHERE EXISTS (
    SELECT 1 FROM (SELECT alias.pk AS LPK1 FROM main_table alias LEFT JOIN ... WHERE conditions) sqd
    WHERE sqd.LPK1 = target_table.pk)
```

```java
// join update
lightDao.lambdaUpdate(StaffInfo.class)
        .leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .set(StaffInfo::getStatus, 2)
        .eq(OrganInfo::getOrganName, "R&D")
        .update();
// UPDATE sqltoy_staff_info SET STATUS = :p1 WHERE EXISTS (
//   SELECT 1 FROM (SELECT s1.STAFF_ID AS LPK1 FROM sqltoy_staff_info s1
//                  LEFT JOIN sqltoy_organ_info o2 ON s1.ORGAN_ID = o2.ORGAN_ID
//                  WHERE o2.ORGAN_NAME = :p2) sqd
//   WHERE sqd.LPK1 = sqltoy_staff_info.STAFF_ID)

// join delete: deleteTables names the delete target (defaults to the main table)
lightDao.lambdaDelete(StaffInfo.class)
        .leftJoin(OrganInfo.class).on(StaffInfo::getOrganId, OrganInfo::getOrganId)
        .deleteTables(StaffInfo.class)
        .eq(OrganInfo::getOrganName, "Marketing")
        .delete();
// DELETE FROM sqltoy_staff_info WHERE EXISTS (SELECT 1 FROM (SELECT s1.STAFF_ID AS LPK1 FROM ... ) sqd WHERE sqd.LPK1 = sqltoy_staff_info.STAFF_ID)
```

- The **main table of a join update/delete is implicitly the builder entity**, so `from()` is unnecessary;
- **The target entity must have an `@Id` primary key** (a composite key correlates through `LPK1…LPKn`): the EXISTS rewrite joins back to the target table by primary key, and an entity without one throws `DataAccessException` during assembly;
- The rewrite is verified against real relational databases (mysql/postgresql/sqlserver/oracle/db2 — part of the release multi-DB gate); clickhouse/doris/starrocks and other databases without transactional row-level DML are not supported and must use SQL mode instead;
- `setExpr` expressions in a join update are **emitted verbatim** (the single-table channel's automatic property-to-column conversion does not apply), so write real column names; a single `?` can still bind a value;
- The join channel is likewise subject to the unconditional-write guard (`matchAll()` allows it).

---

## 6b. Composed queries: CTE (WITH AS) / @fast pagination pushdown / UNION

lambda can compose **several lambdaQueries** into one big SQL statement: CTE (`WITH ... AS`), @fast page pushdown derived tables, UNION/UNION ALL. The branches **share the parameter sequence** (inner branches are assembled first, the outer statement continues the numbering), so parameter names are globally unique.

### CTE (WITH AS)

```java
// inner CTE body: an independent join lambdaQuery that is not executed but only contributes SQL
LambdaQuery<CteDept> inner = lightDao.lambdaQuery(CteDept.class).from(CteDept.class)
        .select(JoinCol.of(CteDept::getDeptId).as("deptId"), JoinCol.of(CteDept::getDeptName).as("deptName"))
        .eq(CteDept::getStatus, 1);

// outer query: register the CTE with with and reference it via fromCte; the outer type maps to a VO
List<CteDeptVO> rows = lightDao.lambdaQuery(CteDeptVO.class)
        .with("d", inner)
        .fromCte("d")
        .eq(CteDeptVO::getDeptName, "R&D Dept")
        .find();
// → WITH d AS (SELECT c1.DEPT_ID AS deptId, c1.DEPT_NAME AS deptName FROM cte_dept c1 WHERE c1.STATUS = :p1)
//   SELECT c2.DEPTNAME AS deptName, c2.DEPTID AS deptId FROM d c2 WHERE c2.DEPTNAME = :p2
```

- **Several CTEs / a CTE referencing another CTE**: chain `.with("a", qa).with("b", qb)` and let `qb` use `fromCte("a")` → `WITH a AS (..), b AS (..)`.
- **Recursive CTE**: `.withRecursive(name, q, "id", "pid", "name")` → `WITH RECURSIVE name(id, pid, name) AS (..)`; **the column list is strongly recommended** — recursive CTEs on H2 and others require it, and PG/MySQL/SQLServer support it as standard. Oracle/SQLServer recursive CTEs omit the `RECURSIVE` keyword, which the framework adapts by target database type. The recursive branch must join the CTE to itself with **innerJoin** (a LEFT JOIN produces a row with no child and makes the recursion never terminate), and the join direction is "child.pid = current node.id" walking downwards.
- **PostgreSQL materialization hint**: `.with(name, q, Boolean.TRUE/FALSE)` renders `AS MATERIALIZED` / `AS NOT MATERIALIZED`; **other databases ignore it** (decided by dbType).
- **Position constraint on WITH**: the generated `WITH` is always at position 0 — sqltoy detects WITH textually (`SqlWithAnalysis`/`hasWith`) to strip it outside the wrapper for count/pagination, and a leading semicolon would break that detection; a single SQLServer statement starting with WITH needs no leading semicolon anyway (the semicolon requirement only applies to batches with an unterminated statement before the WITH).
- The outer column resolution uses the **result VO's EntityMeta** (a CTE is not a real table and has no EntityMeta), so the outer query must be typed to a VO whose fields align with the CTE output columns; databases without CTE support must be handled by the developer (the framework does not degrade).

### @fast pagination pushdown with derived tables

`@fast` semantics: **first paginate the inner @fast block to pageSize rows, then join those rows to outer tables** (avoiding a full join followed by pagination); the pagination count defaults to the inner @fast SQL (the simplified form). lambda expresses this as a derived table:

```java
LambdaQuery<StaffInfo> inner = lightDao.lambdaQuery(StaffInfo.class).from(StaffInfo.class)
        .eq(StaffInfo::getStatus, 1).orderByDesc(StaffInfo::getEntryDate);   // inner: filter + sort (pushdown subject)

Page<StaffOrganVO> page = lightDao.lambdaQuery(StaffOrganVO.class)
        .fromFast(inner, "t1")                                   // FROM @fast(inner sql) t1
        .leftJoin(OrganInfo.class).on(StaffOrganVO::getOrganId, OrganInfo::getOrganId)
        .findPage(new Page(10, 1));
// → select t1.*, t2.ORGAN_NAME from @fast(select ... from staff t where t.STATUS=:p1 order by t.ENTRY_DATE desc) t1
//   left join organ t2 on t1.organ_id=t2.ORGAN_ID   (limit/offset is pushed into the @fast inner block by sqltoy)
```

`@fast` can also be nested inside a CTE body: `.with("tmp", q)` where `q` internally uses `fromFast(...)` → `WITH tmp AS (SELECT * FROM @fast(..) t1 ...)`.

**An even leaner count**: `.countSql("select count(1) from staff where status=:p1")` supplies a hand-written count that is leaner than the inner @fast count (effective only for `findPage` on the join/SQL channel), corresponding to sqltoy's `count-sql` configuration.

### UNION / UNION ALL

```java
LambdaQuery<NameVO> q1 = lightDao.lambdaQuery(NameVO.class).from(Staff.class)
        .select(JoinCol.of(Staff::getName).as("name")).eq(Staff::getStatus, 1);
LambdaQuery<NameVO> q2 = lightDao.lambdaQuery(NameVO.class).from(Staff.class)
        .select(JoinCol.of(Staff::getName).as("name")).eq(Staff::getStatus, 2);

q1.unionAll(q2).find();          // (q1) UNION ALL (q2)  no dedup, faster
q1.union(q2).count();            // (q1) UNION (q2)     dedup
q1.unionAll(q2).findPage(page);  // wrapped as a sub-query then paginated; count likewise
```

- Both sides must map to **the same result type** with identical select columns/aliases, and both are join/SQL channel queries (requiring `from`/`select`).
- **Every query terminal applies to the composed SQL** (`find/getOne/findPage/findTop/findRandom/count/exists` all take the composed SQL from `getSql()`, so CTE/UNION work with all of them); UNION ALL counts reuse sqltoy's union-all-count optimization (summing the branches).

> Composed queries (CTE/@fast/UNION) are all join/SQL channel and **do not inherit entity-level enhancements** (sharding/translate/masking/tenant); the raw SQL fragments and aliases in CTE/@fast/UNION are the developer's responsibility for dialect portability.

---

## 7. Parameter and SQL-shape conventions

- Condition parameters are uniformly named `:p1、:p2…`, unique across the whole builder (nested conditions and the set/where parts of a join share the sequence), which keeps SQL logs readable;
- External named parameters of `having` and `inSql` should **avoid the `p` + pure-digit form** to prevent collisions with internal parameter names;
- Nested conditions are parenthesized as a whole; when only grouping/sorting is present, `1 = 1` is used to complete the where clause;
- lambda extraction only supports **getter method references** (`User::getName`, `User::isActive`); an expression lambda (`u -> u.getName()`) cannot yield a property name and fails fast.

---

## 7b. Safety boundaries and usage conventions

- **Raw SQL escape hatches are not injection-screened**: `last(sql)`, `having(sql, params)`, `inSql(col, sql, params)` and `setExpr(col, expr)` accept raw SQL text (at the same trust level as sqlId text), so **never concatenate end-user input**; always bind parameters by name;
- **Parameter namespaces**: internal condition parameters are `:p1、:p2…`; external parameter names of `having`/`inSql` may not use the `p` + pure-digit form, validated at call time;
- **Select alias uniqueness**: a user alias (`JoinCol.as(...)` or the property form of select) that duplicates any existing alias throws (result-mapping ambiguity); duplicate column names among framework dumps (`selectAll()`/`selectAll(Class)`) are **skipped in declaration order with the main table winning** (e.g. when both the main table and a joined table have a `status` column, the joined one is skipped) — use `JoinCol.as` to rename explicitly when you need the joined column;
- **Self-joins are not supported**: registering the same entity twice (including `from` followed by joining the same class) throws, because the lambda join cannot generate two aliases for one entity;
- **When the result type is a VO**, the property form `select(VO::getX)` is unavailable on the join channel (the VO does not participate in the join, so no alias can qualify it) and throws; for VOs use `JoinCol...as()` or `selectAll/selectAll(Class)`;
- **Channel restriction of `last(sql)`**: on the join channel it is appended to the end of the SQL normally; on the single-table channel (where the `EntityQuery` where clause cannot carry trailing raw SQL) calling it throws — use `findTop/findPage` or the join channel instead;
- **External parameter namespace**: two `inSql`/`having` sites sharing one named parameter with **different values** throws (silent overwriting would produce wrong results); sharing it with the same value is allowed;
- **Proxy lambdas are unsupported**: lambdas produced by the IDEA Evaluate window or Mockito mocks cannot have their metadata resolved under JDK module encapsulation and throw, with a hint to add `--add-opens java.base/java.lang.invoke=ALL-UNNAMED` or switch to a method reference;
- **Builders are single-use and not thread-safe**: one builder instance corresponds to one assembly; calling structural mutators such as `from/leftJoin/on` after a terminal has executed (assembled) throws, and further conditions have no effect; create a new builder per request under concurrency;
- **Fields must be mapped properties**: properties referenced in conditions/select/set must be `@Column`-mapped fields; unmapped properties (helper getters, `getClass`, etc.) throw during assembly instead of silently producing `null = :p1`;
- **Update/delete builders reject grouping and sorting**: `groupBy/having/orderBy` are supported only by `LambdaQuery`; calling them on `LambdaUpdate/LambdaDelete` throws during assembly;
- **`not(...)` and the preceding condition get an automatic AND**: `eq(a).not(n -> ...)` renders as `a AND NOT (...)`; a dangling NOT from an empty `not(...)` is stripped;
- **Delete-channel fallback for a parameterless where**: same rule as update (conditions without named parameters such as `isNull`, and the `matchAll` case, get `1=:DEFAULT_VALUE` automatically), so `deleteByQuery`'s empty-value rejection is never triggered;
- **The primary key may be set explicitly**: an explicit `set/setExpr` on the primary key counts as intent (natural-key correction, etc.) and is not blocked; setting several rows to the same key is rejected by the database constraint; whole-entity update's primary-key safety is guaranteed by `lightDao.update(entity)` (the key goes into the where clause).

## 8. Error semantics at a glance

| Scenario | Behaviour |
| --- | --- |
| `getOne()` matches more than one row | Throws (including the match count), hinting at checking condition uniqueness or using `find()` |
| Update/delete with no where condition | Throws; an explicit `matchAll()` is required |
| Condition/select/set field belongs to an entity outside the join | Throws: the entity does not participate in the current query/join |
| A join without `on()` | Throws during assembly |
| Join update/delete without a main table | Throws during assembly (a query may default the main table to the result type) |
| `setExpr` expression contains `=` | Throws at call time |
| `ExcludeCols` field not belonging to the main entity | Throws during assembly |
| `selectAll(ExcludeCols...)` excludes every column | Throws during assembly |
| Terminal called on a builder not bound to a dao | Throws, hinting at how it must be created |

---

## 9. Migrating from sqltoy-plus

| sqltoy-plus | lambda conditions |
| --- | --- |
| `Wrappers.lambdaQuery(entityClass)` | `LambdaQuery.create(entityClass)` or `lightDao.lambdaQuery(entityClass)` |
| `LambdaQueryWrapper / LambdaUpdateWrapper` | `LambdaQuery / LambdaUpdate` |
| `SqlToyPlusDao.findList/findOne/findPage/count/exists/delete/update(wrapper)` | Builder terminals: `lambdaQuery(...).find()/getOne()/findPage()/count()/exists()`, `lambdaUpdate(...).update()`, `lambdaDelete(...).delete()` |
| `lambdaQueryChain/lambdaUpdateChain` | `lightDao.lambdaQuery/lambdaUpdate` (the factory binds the dao; go straight to a terminal) |
| `Wrappers.lambdaMultiWrapper(toClass).select(...).from(...)` | `lightDao.lambdaQuery(toClass)[.selectAll(...)].from(...).leftJoin(...).on(...)` |
| `LambdaColumn` | `JoinCol` |
| `lambdaUpdateMultiWrapper / lambdaDeleteMultiWrapper` | `lightDao.lambdaUpdate/lambdaDelete` + join steps |
| `SFunction` | `LambdaFn` |
| `FiledValueFilterStrategy` (global static) | builder-instance `valueFilter(...)` |
| parameter names of the `type.valuePairs.MPG1` form | `:p1…` |
| string-column wrappers (`QueryWrapper` etc.) | no longer provided: use `EntityQuery` for single-table string conditions and SQL mode for complex dynamic SQL |
| `@EnableSqlToyPlus` / mapping-strategy beans | no configuration needed; the capability ships with `LightDao` |

---

## 10. Boundaries (what it does not do)

- **String condition DSL**: the lambda layer accepts method references only; use `EntityQuery/EntityUpdate` for single-table string conditions and SQL mode for complex dynamic SQL;
- **Entity-level enhancements do not apply on the join channel** (sharding/translate/masking/tenant);
- **Join update/delete on OLAP databases**: clickhouse/doris/starrocks and other databases without transactional row-level DML are out of scope (a database capability boundary, at the developer's discretion); relational databases use the portable EXISTS-over-derived rewrite, verified on real mysql/postgresql/sqlserver/oracle/db2 databases;
- **Whole-entity merged updates**: update a whole object by primary key with `lightDao.update(entity)`; the lambda layer only offers explicit `set/setExpr` fields;
- **Interceptor/plugin system**: lambda conditions ultimately run through sqltoy's existing execution path, so plugins (`SqlInterceptor` etc.) keep working, but the lambda layer itself offers no extension points.
