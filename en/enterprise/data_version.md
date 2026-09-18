# Data Versioning

> Supported since sqltoy 5.12.11 / 4.19.62.

## 1. Purpose

Prevents data from being changed by other users while the current user is working on it, so the current user can be effectively alerted (optimistic locking semantics).

## 2. Logic

1. A version number is automatically assigned when the data is **created**;
2. On **update**, the page holds the current version number of the data;
3. When the update is submitted, the **version is checked for consistency**: if it matches, the data is updated and the version number is incremented by 1; otherwise an exception is thrown, indicating that the data has been changed by someone else.

## 3. Usage

Add the `@DataVersion` annotation to the POJO class to mark the object as requiring version control:

```java
@DataVersion(field = "dataVersion", startDate = false)
@Entity(tableName = "sqltoy_order_info", pk_constraint = "PRIMARY")
public class OrderInfo implements Serializable {
    @Id(...)
    private String orderId;
    // Version number field (field points to this property name)
    private Long dataVersion;
    // ... other fields
}
```

`@DataVersion` attributes:

| Attribute | Default | Description |
| --- | --- | --- |
| `field` | `""` | Version number field name (the object's property name) |
| `startDate` | `false` | Whether the version number starts with a date, e.g. `202209231` (with `true` it is easy to distinguish version batches by date) |

**The current version number must be carried when updating data**: when submitting the update, the front end / caller must send back the `dataVersion` obtained at query time; the framework uses it to perform the version check.

```java
// Get dataVersion at query time
OrderInfo order = lightDao.load(queryVO);
// Submit after modification; the original dataVersion must be kept for the check
order.setStatus(2);
lightDao.update(order);   // If the version matches, update and increment by 1; otherwise an exception is thrown
```

> Data versioning can be combined with other enterprise-grade features such as the [elastic update](../crud/sqltoy_crud.md) and [data permission](sqltoy_permission.md).
