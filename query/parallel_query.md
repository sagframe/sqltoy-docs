# 并行查询（parallelQuery）

## 一、适用场景

并行查询用于**同时执行几个没有前后依赖关系的 SQL**，把顺序执行变为并行执行，提升整体效率（如一个页面需要同时加载多块互不依赖的统计数据）。

注意事项：

- **不要用于事务操作过程中**。
- 多个 SQL **共用相同的参数条件**（几个查询参数的合集），sqltoy 会自动为每个 SQL 提取出它实际需要的参数。
- 支持分页、非分页、分页+非分页混合：通过 `ParallelQuery` 设置 `Page` 即表示该查询为分页查询。

## 二、API

```java
// 返回每个查询对应的 QueryResult，顺序与传入的 ParallelQuery 列表一致
public <T> List<QueryResult<T>> parallelQuery(List<ParallelQuery> parallelQueryList, Map<String, Object> paramsMap);
```

`ParallelQuery` 链式构建：`create()`、`sql()`、`page()`、`topSize()`、`randomSize()`、`names()`、`values()`、`paramsMap()`、`dataSource()`、`showSql()`、`contextData()`。

## 三、使用范例

```java
List<ParallelQuery> queries = new ArrayList<>();
// 普通查询
queries.add(ParallelQuery.create().sql("sys_staff_find").resultType(StaffInfoVO.class));
// 分页查询（设置 page 即为分页）
queries.add(ParallelQuery.create().sql("sys_order_find").page(new Page(10, 1)));
// 取 Top
queries.add(ParallelQuery.create().sql("sys_sale_top").topSize(10));

// 共用参数条件，sqltoy 自动为每个 sql 提取所需参数
Map<String, Object> paramsMap = MapKit.keys("status", "organId").values(1, "T001");
List<QueryResult> results = lightDao.parallelQuery(queries, paramsMap);

List<StaffInfoVO> staff = results.get(0).getRows();
Page orderPage = results.get(1).getPageResult();
List saleTop = results.get(2).getRows();
```

每个查询也可以**单独设置自己的参数**（覆盖/补充共用参数）：

```java
queries.add(ParallelQuery.create().sql("sys_order_find")
        .names("status").values(1)
        .page(new Page(10, 1)));
```

> `QueryResult` 常用方法：`getRows()`（结果集）、`getPageResult()`（分页结果）、`getExecuteTime()`（执行时长）。

> **6.0 起更名**：`parallQuery` / `ParallQuery` 更名为 `parallelQuery` / `ParallelQuery`，5.6.x 版本请使用旧名称。
