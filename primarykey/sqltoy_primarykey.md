# 主键策略介绍

sqltoy 的主键分两类：**程序化主键**（框架或自定义生成器产出，不依赖数据库）与**数据库主键**（`sequence` / `identity`，由数据库产生）。前者跨库无差异，是产品化推荐做法。

## 一、策略总览

| 策略关键字（quickvo `generator` / `@Id.generator` 的取值） | 实现类（`org.sagacity.sqltoy.plugins.id.impl`） | 形态 |
| --- | --- | --- |
| `default` | `DefaultIdGenerator` | 22 位有序数字：13 位当前毫秒 + 6 位纳秒 + 3 位主机 ID，如 `1592214184072221900219` |
| `nanotime` | `NanoTimeIdGenerator` | 26 位有序数字：15 位 `yyMMddHHmmssSSS` + 6 位纳秒 + 2 位（线程 Id + 随机数）+ 3 位主机 ID |
| `snowflake` | `SnowflakeIdGenerator` | 雪花算法，有序数字 |
| `uuid` | `UUIDGenerator` | 32 位 UUIDv7（有序版本） |
| `ulid` | `ULIDGenerator` | 26 位有序字符：时间戳 10 位 + 随机熵 16 位（需引入 `ulid-creator`） |
| `redis` | `RedisIdGenerator` | 业务主键：按规则生成，如订单号「年月日 + 流水」 |
| `sequence` / `identity` / `assign` | 由数据库或调用方负责 | 数据库序列 / 自增列 / 手工赋值 |

> 关键字大小写不敏感，`defaultIdGenerator`、`snowflakeIdGenerator` 等写法同样可用（框架做了命名容错）。

内置生成器实现（`plugins.id.impl`，截图早于 ULID 的加入）：

![内置主键生成器实现](../_media/pk-strategy-overview.png)

`ULID` 需要额外依赖：

```xml
<dependency>
	<groupId>com.github.f4b6a3</groupId>
	<artifactId>ulid-creator</artifactId>
	<!-- 具体版本可调整 -->
	<version>5.2.4</version>
</dependency>
```

## 二、在 quickvo.xml 中指定策略

```xml
<!-- 主键策略：identity 列会自动识别，其余按类型/长度自动推断；
     strategy: sequence(需 sequence 名) | assign(手工) |
               generator(default 22位 | nanotime 26位 | snowflake | uuid | ulid | redis | 自定义类) -->
<primary-key>
    <!-- 可用正则批量匹配表名 -->
    <table name="SQLTOY_\w+|LESSON_\w+|SYS_\w+" strategy="generator" generator="default" />
    <!-- 指定数据库序列 -->
    <table name="XXX_TABLE" strategy="sequence" sequence="SEQ_XXXX" />
    <!-- 指定雪花算法 -->
    <table name="sys_staff_info" strategy="generator" generator="snowflake" />
</primary-key>
```

**自动推断**（不配置 `primary-key` 时）：`bigint` → 雪花算法；22 位字符 → `DefaultIdGenerator`；26 位字符 → `NanoTimeIdGenerator`；`identity` 列 → 由数据库生成，无需配置。

真实的 sequence 配置示例：

![quickvo.xml 中配置 sequence 策略](../_media/pk-quickvo-sequence.png)

## 三、生成的注解

quickvo 依据上述配置在 POJO 主键字段上生成 `@Id`：

```java
// strategy="generator" + generator 关键字
@Id(strategy = "generator", generator = "org.sagacity.sqltoy.plugins.id.impl.NanoTimeIdGenerator")
@Column(name = "ID", type = java.sql.Types.VARCHAR, length = 26, nullable = false)
private String id;

// strategy="sequence" 时指向序列名
@Id(strategy = "sequence", sequence = "SEQ_XXXX")
@Column(name = "ID", type = java.sql.Types.BIGINT, nullable = false)
private Long id;
```

> `@Id` 只描述生成策略，`@Column` 描述列；两者都要标在主键字段上。属性含义见[注解速查 · @Id](../appendix/annotations.md)。

quickvo 实际生成的片段（截图）：

![生成的 @Id 注解](../_media/pk-id-annotation.png)

## 四、redis 业务主键

redis 策略属于**业务主键**范畴（订单号、单据号这类有规则的号）。quickvo 用 `business-primary-key` 声明：

```xml
<!-- 宏：@substr(${field},startIndex,length) @case(value,case1,value1,...) @df(yyMMdd)
     不需要日期时用 @df('')；related-columns 是参与生成的来源字段 -->
<business-primary-key>
    <table name="LESSON_DEVICE_ORDER" column="ORDER_ID"
           generator="redis" signature="PO@df(yyMMdd)" length="16" />
</business-primary-key>
```

一个更完整的真实配置（含宏组合与来源字段）：

![quickvo.xml 中的 redis 业务主键配置](../_media/pk-quickvo-redis.png)

> 若业务主键字段本身也是主键（`@Id`），它会**覆盖**原主键策略——即业务号直接作为物理主键；`length` 与流水位数决定号的形态。

使用 redis 生成主键需要应用侧定义 `RedisTemplate`。

### @BusinessId 注解与 generateBizId

配置层面**一张表只支持一个**业务主键。当一个表涉及多个业务主键时，用 `@BusinessId` 注解 + `generateBizId` 自行生成后赋值：

```java
/** 订单编号（业务主键） */
@BusinessId(signature = "HW@case(orderType,SALE,SC,BUY,PO)@day(yyMMdd)",
        generator = "org.sagacity.sqltoy.plugins.id.impl.RedisIdGenerator",
        length = 20, sequenceSize = 5, relatedColumns = {"orderType"})
private String orderId;
```

`@BusinessId` 属性：

| 属性 | 说明 |
| --- | --- |
| `signature` | 识别区分符号表达式，支持 `@case(name,v1,then1,v2,then2)`、`@day(yyMMdd)`、`@substr(name,start,length)` 等宏 |
| `generator` | 主键生成策略实现类（如 redis 策略 `RedisIdGenerator`） |
| `length` / `sequenceSize` | 业务主键总长度 / 尾部流水位数（默认 -1 取全局配置） |
| `relatedColumns` | 参与主键生成的关联字段 |
| `start` | 流水初始值，默认 1 |

通过 `LightDao` 生成：

```java
// 1) 基于实体对象配置的 @BusinessId 策略，提取属性值生成业务主键
String orderId = lightDao.generateBizId(orderInfo);

// 2) 动态传参生成（业务主键按表维度隔离管理；signature 支持 @case/@day/@substr 宏）
String bizId = lightDao.generateBizId("sqltoy_order_info",
        "HW@case(orderType,SALE,SC,BUY,PO)@day(yyMMdd)",
        MapKit.map("orderType", "SALE"), null, 20, 5);

// 3) 简单形态：唯一标识符号 + 增量
long id = lightDao.generateBizId("ORDER", 1);
```

> 🎬 完整可运行示例：演示项目 `sqltoy-showcase` 的 `BusinessIdAndDataVersionTest.java`（含 @BusinessId 注解用法；运行依赖 redis，已标注 @Disabled 作为参考实现）。

## 五、使用自定义主键策略

实现 `IdGenerator` 接口（包 `org.sagacity.sqltoy.plugins.id`；旧资料里常写成 `IdGenarator`，属笔误）：

```java
public interface IdGenerator {
    /**
     * @param tableName       表名（部分策略需要按表隔离）
     * @param signature       识别区分符号
     * @param relatedColumns  关联字段名
     * @param relatedColValue 关联字段值
     * @param bizDate         当前日期
     * @param idJavaType      主键 Java 类型
     * @param length          主键长度
     * @param sequenceSize    流水号长度（如 20210709[001] 后三位为流水）
     */
    public Object getId(String tableName, String signature, String[] relatedColumns, Object[] relatedColValue,
            Date bizDate, String idJavaType, int length, int sequenceSize);

    /** 可选：初始化（框架启动时回调） */
    public default void initialize(SqlToyContext sqlToyContext) throws Exception { }
}
```

![IdGenerator 接口定义](../_media/pk-id-generator.png)

然后在 quickvo.xml 里把 `generator` 指向实现类，支持**两种写法**：全限定类名，或 `@bean(beanName)`（生成器交给 Spring 容器管理，便于注入依赖）：

```xml
<primary-key>
    <table name="SQLTOY_\w+" strategy="generator"
           generator="com.yourproject.MyIdGenerator" />
    <!-- 或：交给 Spring 容器 -->
    <table name="SQLTOY_\w+" strategy="generator"
           generator="@bean(myIdGenerator)" />
</primary-key>
```

![quickvo.xml 自定义主键策略配置](../_media/pk-quickvo-custom.png)

也可以直接在 POJO 上标注，绕过 quickvo：

```java
@Id(strategy = "generator", generator = "com.yourproject.MyIdGenerator")
```

> 自定义生成器若依赖 Spring 的 bean（如 redis 模板），用 `initialize(SqlToyContext)` 拿上下文，或在实现类内部自行获取；native 镜像下该实现类需要反射注册，见 [GraalVM Native Image 指引](../tools/graalvm_native.md)。

## 六、主键重复处理

`default`、`nanotime`、`snowflake` 三种策略依赖**主机 ID** 区分 worker。同一台 IP 的服务器部署多个应用实例时会重复，需显式指定：

```shell
# default、nanotime：三位数字
java -Dsqltoy.server.id=112

# snowflake：两个参数，数字形式且小于 32
java -Dsqltoy.snowflake.workerId=11
java -Dsqltoy.snowflake.dataCenterId=20
```

> 容器化/云环境（Pod IP 动态变化）建议：显式配置上述参数，或改用 `redis` 策略/自定义生成器集中发号。

## 七、相关

- `@Id`/`@BusinessId` 属性表：[注解速查](../appendix/annotations.md)
- 主键插入返回值的方言差异：[方言自适配与函数扩展](../dialect/sqltoy_function.md)
- 换库迁移时的主键评估：[换库迁移适配指引](../introduction/xinchuang.md)
