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
