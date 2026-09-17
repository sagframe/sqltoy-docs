# 数据版本控制（@DataVersion）

> 自 sqltoy 5.12.11 / 4.19.62 版本开始支持。

## 一、目的

防止用户在操作数据期间，数据被其他用户修改而发生变化，从而有效提醒当前用户（乐观锁语义）。

## 二、逻辑

1. 数据**创建**时自动带入一个版本号；
2. **修改**时页面持有当前数据的版本号；
3. 提交修改时**校验版本是否一致**：一致则修改数据并将版本号 +1；不一致则抛出异常，提示数据已被他人变更。

## 三、使用说明

在 POJO 类上增加 `@DataVersion` 注解，标记该对象需要版本控制：

```java
@DataVersion(field = "dataVersion", startDate = false)
@Entity(tableName = "sqltoy_order_info", pk_constraint = "PRIMARY")
public class OrderInfo implements Serializable {
    @Id(...)
    private String orderId;
    // 版本号字段（field 指向该属性名）
    private Long dataVersion;
    // ... 其他字段
}
```

`@DataVersion` 属性：

| 属性 | 默认 | 说明 |
| --- | --- | --- |
| `field` | `""` | 版本号字段名（对象属性名） |
| `startDate` | `false` | 版本号是否以日期开头，如 `202209231`（`true` 时便于按日期区分版本批次） |

**修改数据时要带入当前版本号**：前端/调用方在提交更新时必须把查询时拿到的 `dataVersion` 一并传回，框架据此做版本校验。

```java
// 查询时拿到 dataVersion
OrderInfo order = lightDao.load(queryVO);
// 修改后提交，需保留原 dataVersion 用于校验
order.setStatus(2);
lightDao.update(order);   // 版本一致则更新并 +1，不一致抛异常
```

> 数据版本控制与[弹性更新](../crud/sqltoy_crud.md)、[数据权限](sqltoy_permission.md)等企业级特性可叠加使用。
