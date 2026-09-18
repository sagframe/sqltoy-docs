# Parallel Query

## 1. Applicable Scenarios

Parallel query is used to **execute several SQL statements that have no dependencies on each other at the same time**, turning sequential execution into parallel execution to improve overall efficiency (e.g. a page that needs to load multiple independent statistics blocks at once).

Notes:

- **Do not use it in the middle of a transaction.**
- Multiple SQL statements **share the same parameter conditions** (the union of several query parameters); sqltoy automatically extracts the parameters each SQL actually needs.
- Supports paginated queries, non-paginated queries, and a mix of both: setting a `Page` on a `ParallelQuery` marks that query as paginated.

## 2. API

```java
// returns the QueryResult of each query, in the same order as the given ParallelQuery list
public <T> List<QueryResult<T>> parallelQuery(List<ParallelQuery> parallelQueryList, Map<String, Object> paramsMap);
```

`ParallelQuery` is built fluently: `create()`, `sql()`, `page()`, `topSize()`, `randomSize()`, `names()`, `values()`, `paramsMap()`, `dataSource()`, `showSql()`, `contextData()`.

## 3. Usage Example

```java
List<ParallelQuery> queries = new ArrayList<>();
// plain query
queries.add(ParallelQuery.create().sql("sys_staff_find").resultType(StaffInfoVO.class));
// paginated query (setting page makes it a paginated query)
queries.add(ParallelQuery.create().sql("sys_order_find").page(new Page(10, 1)));
// top N query
queries.add(ParallelQuery.create().sql("sys_sale_top").topSize(10));

// shared parameter conditions; sqltoy automatically extracts the parameters each sql needs
Map<String, Object> paramsMap = MapKit.keys("status", "organId").values(1, "T001");
List<QueryResult> results = lightDao.parallelQuery(queries, paramsMap);

List<StaffInfoVO> staff = results.get(0).getRows();
Page orderPage = results.get(1).getPageResult();
List saleTop = results.get(2).getRows();
```

Each query can also **set its own parameters individually** (overriding/adding to the shared parameters):

```java
queries.add(ParallelQuery.create().sql("sys_order_find")
        .names("status").values(1)
        .page(new Page(10, 1)));
```

> Common `QueryResult` methods: `getRows()` (result set), `getPageResult()` (pagination result), `getExecuteTime()` (execution time).

> **Renamed since 6.0**: `parallQuery` / `ParallQuery` are renamed to `parallelQuery` / `ParallelQuery`; use the old names in version 5.6.x.

> 🎬 Full runnable example: `ParallelQueryTest.java` in the demo project `sqltoy-showcase` (basic parallel execution, `ParallelConfig` thread configuration, and the three mixed pagination forms).
