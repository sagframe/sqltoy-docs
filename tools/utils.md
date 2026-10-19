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

> [!TIP]
> **千分位数值自动剥离**（6.0.3 起）：查询结果经 `number-format` 格式化后的带千分位逗号数值（如 `"8,888.0000"`）再映射到 `BigDecimal`/`Integer`/`Long`/`Double` 等数值属性时，convertType 会自动剥离分组逗号。仅当整个字符串严格匹配千分位分组形态时才剥离（`"1,23"` 等非法形态不处理、保持原解析报错）。

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

## 四、常用工具类

sqltoy 的 `org.sagacity.sqltoy.utils` 下有一批"项目里总要自己写一遍"的工具，直接复用即可（`org.sagacity.sqltoy.plugins.utils.CalculateUtils` 提供按精度/舍入方式的计算）：

| 工具类 | 常用能力 |
| --- | --- |
| `IdUtil` | 主键/标识生成：`getUUID()`（UUIDv7）、`getNanoTimeId(workerId)` / `getShortNanoTimeId(...)`（26 位有序数字，返回 `BigDecimal`）、`getId(distributeIdGenerator, tableName, signature, ...)`（基于分布式生成器的业务主键）、`getDebugId()` |
| `SnowflakeIdWorker` / `StandardUUIDv7Generator` | 雪花、UUIDv7 的独立实现，可自行持有实例 |
| `DBTransUtils` | 手动事务：`doTrans(dataSource, transactionHandler)` 把一段逻辑包在事务里、`getCurrentConnection()` 取当前线程绑定的连接 |
| `StringUtil` | 空白判断、驼峰/下划线互转、按符号切分（可排除括号内内容）、占位符替换、`splitExcludeSymMark` |
| `DateUtil` | 日期格式化/解析、月末/季末、按间隔取日期、`getIntervalDays`（分片策略用到） |
| `NumberUtil` | 数字格式化（千分位/百分比）、`toCapitalMoney`（中文大写金额）、解析、`getProbabilityIndex(int[])`（按权重取随机下标，权重分库用到）、`getRandomNum` |
| `CalculateUtils` | 带精度与舍入方式的加减乘除（`RoundingMode` 可控） |
| `CollectionUtil` | 集合切分、分组、判空、类型转换 |
| `BeanUtil` | 属性读写、对象与 Map 互转、枚举取值、类型转换（`convertType` 的底层） |
| `SqlUtil` | SQL 片段识别与处理（剥离 order by、判断 union/group 等），自定义拦截器常用 |
| `ResultUtils` | 结果集到 Map/VO 的映射与扩展类型归一（自行接管结果处理时参考） |
| `MapperUtils` | 见第二节，VO↔POJO/Map 映射 |
| `ReservedWordsUtil` | 保留字按方言加引用符（`@joinFields` 内部使用） |

```java
// 不依赖 dao 生成标识
String uuid = IdUtil.getUUID();                                   // UUIDv7
BigDecimal nanoId = IdUtil.getNanoTimeId("0");                    // 26 位有序数字(workerId 用于多实例区分)

// 手动事务（纯 Java 场景）：把一段逻辑整体放进事务
Object result = DBTransUtils.doTrans(lightDao.getDataSource(), () -> {
    lightDao.updateByQuery(StaffInfo.class,
            EntityUpdate.create().set("sexType", "F").where("staffId=?").values("S0001"));
    return lightDao.find("select * from staff_info where status=:status",
            MapKit.map("status", "1"), StaffInfo.class);
});
```

> 这些工具类基本都是**无状态静态方法**（除 `SnowflakeIdWorker` 等需实例的以外），可多线程直接调用；`DBTransUtils` 的事务状态绑定在当前线程。更多工具入口见[API 速查](../appendix/api.md)。
