# 工具类：DTO 与 POJO 互转

在 DTO(VO) 与 POJO(entity) 严格分层的场景下，sqltoy 提供了便捷的对象/集合快速转换与赋值能力，避免手写大量 `get/set` 拷贝代码。

## 一、convertType（LightDao / SqlToyCRUDService）

`LightDao`、`SqlToyCRUDService`、`SqlToyDaoSupport` 中都提供了 `convertType` 快捷方法：

```java
// 单个对象转换
OrderInfo entity = lightDao.convertType(orderInfoVO, OrderInfo.class);

// 忽略部分属性
OrderInfo entity2 = lightDao.convertType(orderInfoVO, OrderInfo.class, "createBy", "createTime");

// 集合转换
List<OrderInfoVO> voList = lightDao.convertType(entityList, OrderInfoVO.class);

// 分页对象转换（连同分页信息一起转）
Page<OrderInfoVO> voPage = lightDao.convertType(entityPage, OrderInfoVO.class);
```

签名：

```java
<T extends Serializable> T convertType(Serializable source, Class<T> resultType, String... ignoreProperties);
<T extends Serializable> List<T> convertType(List sourceList, Class<T> resultType, String... ignoreProperties);
<T extends Serializable> Page<T> convertType(Page sourcePage, Class<T> resultType, String... ignoreProperties);
```

典型用法（保存时 VO→POJO）：

```java
@Transactional
public void createOrderInfo(OrderInfoVO orderInfoVO) {
    OrderInfo entity = lightDao.convertType(orderInfoVO, OrderInfo.class);
    lightDao.save(entity);
}
```

## 二、MapperUtils（5.6.x 起）

5.6.x 版本开始也可直接使用 `MapperUtils` 工具类进行映射处理，适合在非 DAO 上下文中做对象映射。

## 三、字段名不一致：@SqlToyFieldAlias

当 VO 与 POJO 字段名称不一致时，用 `@SqlToyFieldAlias` 标注对应关系：

```java
// VO 中的 postType 对应 POJO 中的 post
@SqlToyFieldAlias("post")
private String postType;
```

这样 `convertType` 即可正确映射名称不同的字段。

> 严格分层的完整示例参见项目 https://github.com/sagframe/sqltoy-strict ，POJO/VO 由 [quickvo](../prepare/quickvo.md) 生成到不同包。
