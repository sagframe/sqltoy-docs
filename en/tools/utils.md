# Utility Classes: DTO / POJO Conversion

In architectures where DTOs (VOs) and POJOs (entities) are strictly layered, sqltoy provides convenient, fast object/collection conversion and property copying, saving you from hand-writing large amounts of `get/set` copy code.

## 1. convertType (LightDao / SqlToyCRUDService)

`LightDao`, `SqlToyCRUDService` and `SqlToyDaoSupport` all provide `convertType` shortcut methods:

```java
// Convert a single object
OrderInfo entity = lightDao.convertType(orderInfoVO, OrderInfo.class);

// Ignore some properties
OrderInfo entity2 = lightDao.convertType(orderInfoVO, OrderInfo.class, "createBy", "createTime");

// Convert a collection
List<OrderInfoVO> voList = lightDao.convertType(entityList, OrderInfoVO.class);

// Convert a Page object (pagination info is converted along with the data)
Page<OrderInfoVO> voPage = lightDao.convertType(entityPage, OrderInfoVO.class);
```

Signatures:

```java
<T extends Serializable> T convertType(Serializable source, Class<T> resultType, String... ignoreProperties);
<T extends Serializable> List<T> convertType(List sourceList, Class<T> resultType, String... ignoreProperties);
<T extends Serializable> Page<T> convertType(Page sourcePage, Class<T> resultType, String... ignoreProperties);
```

Typical usage (VO→POJO when saving):

```java
@Transactional
public void createOrderInfo(OrderInfoVO orderInfoVO) {
    OrderInfo entity = lightDao.convertType(orderInfoVO, OrderInfo.class);
    lightDao.save(entity);
}
```

> [!TIP]
> **Thousands-separator stripping** (since 6.0.3): when numeric strings with grouping commas produced by `number-format` (e.g. `"8,888.0000"`) are mapped to numeric properties such as `BigDecimal`/`Integer`/`Long`/`Double`, convertType strips the grouping commas automatically. Stripping happens only when the whole string strictly matches the grouping format (`"1,23"` and other invalid forms are left untouched and keep raising the original parse error).

## 2. MapperUtils (since 5.6.x)

From version 5.6.x onward you can also use the `MapperUtils` utility class for mapping, which suits object mapping outside of a DAO context.

## 3. Mismatched Field Names: @SqlToyFieldAlias

When the VO and the POJO use different field names, annotate the mapping with `@SqlToyFieldAlias`:

```java
// postType in the VO corresponds to post in the POJO
@SqlToyFieldAlias("post")
private String postType;
```

This way `convertType` maps fields with different names correctly.

> For a complete example of strict layering, see the project https://github.com/sagframe/sqltoy-strict , where POJOs/VOs are generated into different packages by [quickvo](../prepare/quickvo.md).

## 4. Common utility classes

Under `org.sagacity.sqltoy.utils` there is a set of helpers you would otherwise rewrite in every project (plus `org.sagacity.sqltoy.plugins.utils.CalculateUtils` for precision/rounding-aware arithmetic):

| Class | What it gives you |
| --- | --- |
| `IdUtil` | Identifier generation: `getUUID()` (UUIDv7), `getNanoTimeId(workerId)` / `getShortNanoTimeId(...)` (26-digit ordered numbers, returning `BigDecimal`), `getId(distributeIdGenerator, tableName, signature, ...)` (business keys from a distributed generator), `getDebugId()` |
| `SnowflakeIdWorker` / `StandardUUIDv7Generator` | Standalone snowflake / UUIDv7 implementations you can hold as instances |
| `DBTransUtils` | Manual transactions: `doTrans(dataSource, transactionHandler)` wraps a block in a transaction, `getCurrentConnection()` returns the thread-bound connection |
| `StringUtil` | Blank checks, camelCase↔underscore conversion, symbol-aware splitting (brackets excluded), placeholder replacement, `splitExcludeSymMark` |
| `DateUtil` | Formatting/parsing, month-end/quarter-end, date stepping, `getIntervalDays` (used by sharding strategies) |
| `NumberUtil` | Number formatting (thousands separators, percentages), `toCapitalMoney` (Chinese uppercase amounts), parsing, `getProbabilityIndex(int[])` (weighted random index, used by weighted sharding), `getRandomNum` |
| `CalculateUtils` | Add/subtract/multiply/divide with explicit precision and `RoundingMode` |
| `CollectionUtil` | Collection splitting, grouping, empty checks, type conversion |
| `BeanUtil` | Property read/write, object↔Map conversion, enum value extraction, type conversion (the engine behind `convertType`) |
| `SqlUtil` | SQL fragment inspection and rewriting (strip order by, detect union/group, etc.) — handy in custom interceptors |
| `ResultUtils` | Result-set to Map/VO mapping and extended-type normalization (consult when taking over result processing) |
| `MapperUtils` | See section 2: VO↔POJO/Map mapping |
| `ReservedWordsUtil` | Quotes reserved words per dialect (used internally by `@joinFields`) |

```java
// Generate identifiers without a dao
String uuid = IdUtil.getUUID();                                   // UUIDv7
BigDecimal nanoId = IdUtil.getNanoTimeId("0");                    // 26-digit ordered number (workerId separates instances)

// Manual transaction (plain Java): run a block atomically
Object result = DBTransUtils.doTrans(lightDao.getDataSource(), () -> {
    lightDao.updateByQuery(StaffInfo.class,
            EntityUpdate.create().set("sexType", "F").where("staffId=?").values("S0001"));
    return lightDao.find("select * from staff_info where status=:status",
            MapKit.map("status", "1"), StaffInfo.class);
});
```

> These utilities are almost all **stateless static methods** (except instance-based ones such as `SnowflakeIdWorker`) and are safe to call from multiple threads; `DBTransUtils` transaction state is bound to the current thread. For more entry points see the [API Cheat Sheet](../appendix/api.md).
