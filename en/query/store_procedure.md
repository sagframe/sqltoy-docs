# Stored Procedures

sqltoy supports calling database stored procedures and can retrieve query results, out parameters, and multiple result sets.

## 1. LightDao API

```java
// call without result sets (in parameters are passed in ? order)
StoreResult executeStore(String storeSqlOrKey, Object[] inParamValues);

// with out parameters / a specified result type
// outParamsType can be null; resultType can be a VO, Map.class, LinkedHashMap.class, Array.class, or null (a two-dimensional List)
StoreResult executeStore(String storeSqlOrKey, Object[] inParamValues,
                         Integer[] outParamsType, Class resultType);

// stored procedure with multiple result sets
StoreResult executeMoreResultStore(String storeSqlOrKey, Object[] inParamValues,
                                   Integer[] outParamsType, Class... resultTypes);
```

`storeSqlOrKey` can be a sqlId defined in the xml, or directly `{call storeName(?,?)}`.

## 2. Fluent Style: store()

```java
StoreResult result = lightDao.store()
        .sql("{call storeName(?,?)}")
        .inParams(value1, value2)
        .outTypes(java.sql.Types.INTEGER)   // out parameter types; can be omitted
        .resultType(StaffInfoVO.class)
        .moreResult(false)                  // multiple result sets or not
        .timeout(30)
        .submit();
```

## 3. The StoreResult

| Method | Description |
| --- | --- |
| `getRows()` | Main result set (List) |
| `getMoreResults()` | All result sets (`List[]`, used for multiple result sets) |
| `getOutResult()` | Array of out parameter values (`Object[]`) |
| `getUpdateCount()` | Number of affected rows |
| `getLabelsList()` | Column names of each result set |

## 4. Call Examples

```java
// 1) call without results
lightDao.executeStore("{call storeName(?,?)}", new Object[]{value1, value2});

// 2) stored procedure query (named parameters)
List result = lightDao.executeStore("{call storeName(:param1,:param2)}",
        MapKit.keys("param1", "param2").values(value1, value2), VO.class).getRows();

// 3) multiple result sets
StoreResult more = lightDao.executeMoreResultStore("{call storeName(?,?,?)}",
        new Object[]{value1, value2}, new Integer[]{java.sql.Types.INTEGER},
        VO1.class, VO2.class);
List[] allResults = more.getMoreResults();
Object[] outValues = more.getOutResult();
```

## 5. Complete Example: Stored Procedure with Multiple Result Sets

When a stored procedure returns **multiple result sets** (e.g. a master table plus a detail table, or several groups of statistics), use `executeMoreResultStore` or the fluent `store().moreResult(true)`, and retrieve all result sets via `getMoreResults()`.

Suppose the stored procedure `proc_order_report` takes `organId` and `beginDate` as inputs, returns two result sets (an order list and order details), and has an out parameter `totalCount` that returns the total record count.

```java
// calls {call proc_order_report(?,?,?)}: the first two are in parameters, the last one is an out parameter
StoreResult storeResult = lightDao.executeMoreResultStore(
        "{call proc_order_report(?,?,?)}",
        new Object[]{ "T001", LocalDate.parse("2026-01-01") },  // in parameters (in ? order)
        new Integer[]{ java.sql.Types.INTEGER },                 // out parameter type
        OrderInfoVO.class,        // mapping type of the 1st result set
        OrderItemVO.class);       // mapping type of the 2nd result set

// 1) get all result sets: List[], each element corresponds to one result set
List[] allResults = storeResult.getMoreResults();
List<OrderInfoVO> orders = allResults[0];        // first result set (orders)
List<OrderItemVO> orderItems = allResults[1];    // second result set (details)

// 2) get out parameter values
Object[] outValues = storeResult.getOutResult();
Integer totalCount = (Integer) outValues[0];

// 3) getRows() returns the main result set (i.e. the first result set)
List<OrderInfoVO> mainRows = storeResult.getRows();

System.out.println("Order count=" + orders.size()
        + ", detail count=" + orderItems.size()
        + ", total records=" + totalCount);
```

The equivalent fluent style:

```java
StoreResult result = lightDao.store()
        .sql("{call proc_order_report(?,?,?)}")
        .inParams("T001", LocalDate.parse("2026-01-01"))
        .outTypes(java.sql.Types.INTEGER)
        .moreResult(true)
        .resultTypes(OrderInfoVO.class, OrderItemVO.class)
        .submit();

List[] all = result.getMoreResults();              // all[0]=orders, all[1]=details
Integer total = (Integer) result.getOutResult()[0]; // out parameter
```

> Note: `resultTypes` specifies the mapping type of each result set in the order the result sets appear (can be a VO, `Map.class`, `LinkedHashMap.class`, `Array.class`, or `null` for a two-dimensional List); `getMoreResults()` returns `List[]` (all result sets), `getRows()` returns the main (first) result set, and `getOutResult()` returns the array of out parameter values.
