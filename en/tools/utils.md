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
