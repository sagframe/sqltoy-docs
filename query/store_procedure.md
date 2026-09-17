# 存储过程调用

sqltoy 支持调用数据库存储过程，并可获取查询结果、out 参数与多结果集。

## 一、LightDao 接口

```java
// 无结果集调用（in 参数按 ? 顺序传入）
StoreResult executeStore(String storeSqlOrKey, Object[] inParamValues);

// 带 out 参数 / 指定结果类型
// outParamsType 可为 null；resultType 可为 VO、Map.class、LinkedHashMap.class、Array.class、null(二维 List)
StoreResult executeStore(String storeSqlOrKey, Object[] inParamValues,
                         Integer[] outParamsType, Class resultType);

// 多结果集存储过程
StoreResult executeMoreResultStore(String storeSqlOrKey, Object[] inParamValues,
                                   Integer[] outParamsType, Class... resultTypes);
```

`storeSqlOrKey` 可以是 xml 中的 sqlId，也可以直接是 `{call storeName(?,?)}`。

## 二、链式写法 store()

```java
StoreResult result = lightDao.store()
        .sql("{call storeName(?,?)}")
        .inParams(value1, value2)
        .outTypes(java.sql.Types.INTEGER)   // out 参数类型，可省略
        .resultType(StaffInfoVO.class)
        .moreResult(false)                  // 是否多结果集
        .timeout(30)
        .submit();
```

## 三、StoreResult 结果

| 方法 | 说明 |
| --- | --- |
| `getRows()` | 主结果集（List） |
| `getMoreResults()` | 全部结果集（`List[]`，多结果集时使用） |
| `getOutResult()` | out 参数值数组（`Object[]`） |
| `getUpdateCount()` | 影响行数 |
| `getLabelsList()` | 各结果集的列名 |

## 四、调用示例

```java
// 1) 无结果调用
lightDao.executeStore("{call storeName(?,?)}", new Object[]{value1, value2});

// 2) 存储过程查询（命名参数）
List result = lightDao.executeStore("{call storeName(:param1,:param2)}",
        MapKit.keys("param1", "param2").values(value1, value2), VO.class).getRows();

// 3) 多结果集
StoreResult more = lightDao.executeMoreResultStore("{call storeName(?,?,?)}",
        new Object[]{value1, value2}, new Integer[]{java.sql.Types.INTEGER},
        VO1.class, VO2.class);
List[] allResults = more.getMoreResults();
Object[] outValues = more.getOutResult();
```

## 五、多结果集存储过程完整范例

当一个存储过程返回**多个结果集**（如主表 + 明细表，或多组统计结果）时，用 `executeMoreResultStore` 或链式 `store().moreResult(true)`，并通过 `getMoreResults()` 获取全部结果集。

假设存储过程 `proc_order_report`：入参 `organId`、`beginDate`，返回两个结果集（订单列表、订单明细），并有一个 out 参数 `totalCount` 返回总记录数。

```java
// 调用 {call proc_order_report(?,?,?)}：前两个为 in 参数，最后一个为 out 参数
StoreResult storeResult = lightDao.executeMoreResultStore(
        "{call proc_order_report(?,?,?)}",
        new Object[]{ "T001", LocalDate.parse("2026-01-01") },  // in 参数（按 ? 顺序）
        new Integer[]{ java.sql.Types.INTEGER },                 // out 参数类型
        OrderInfoVO.class,        // 第 1 个结果集的映射类型
        OrderItemVO.class);       // 第 2 个结果集的映射类型

// 1) 获取全部结果集：List[]，每个元素对应一个结果集
List[] allResults = storeResult.getMoreResults();
List<OrderInfoVO> orders = allResults[0];        // 第一个结果集（订单）
List<OrderItemVO> orderItems = allResults[1];    // 第二个结果集（明细）

// 2) 获取 out 参数值
Object[] outValues = storeResult.getOutResult();
Integer totalCount = (Integer) outValues[0];

// 3) getRows() 返回主结果集（即第一个结果集）
List<OrderInfoVO> mainRows = storeResult.getRows();

System.out.println("订单数=" + orders.size()
        + "，明细数=" + orderItems.size()
        + "，总记录数=" + totalCount);
```

等价的链式写法：

```java
StoreResult result = lightDao.store()
        .sql("{call proc_order_report(?,?,?)}")
        .inParams("T001", LocalDate.parse("2026-01-01"))
        .outTypes(java.sql.Types.INTEGER)
        .moreResult(true)
        .resultTypes(OrderInfoVO.class, OrderItemVO.class)
        .submit();

List[] all = result.getMoreResults();              // all[0]=订单, all[1]=明细
Integer total = (Integer) result.getOutResult()[0]; // out 参数
```

> 说明：`resultTypes` 按结果集出现顺序依次指定各结果集的映射类型（可为 VO、`Map.class`、`LinkedHashMap.class`、`Array.class`，或 `null` 表示二维 List）；`getMoreResults()` 返回 `List[]`（全部结果集），`getRows()` 返回主（第一个）结果集，`getOutResult()` 返回 out 参数值数组。
