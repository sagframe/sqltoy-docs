# 注解速查

sqltoy 的全部注解都位于 `org.sagacity.sqltoy.config.annotation`（共 23 个），按用途分为实体映射、主键与业务号、关联、企业级特性、缓存翻译、DDL 六组。本页给出每个注解的**目标位置、属性、默认值与用途**，细节用法请跳转到对应章节。

> 绝大多数 POJO 由 [quickvo](prepare/quickvo.md) 按数据库表自动生成并带好注解，手写注解主要出现在：调整映射、补充 `@Index`/`@Partition` 等 DDL 信息、给已有实体加企业级特性。

## 一、总览

| 注解 | 目标 | 用途 | 详见 |
| --- | --- | --- | --- |
| `@SqlToyEntity` | 类 | 标记为 sqltoy 实体（`@Entity` 的语义化别名，扫描依据之一） | 本页 |
| `@Entity` | 类 | 表映射：表名/模式/注释/主键约束名 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `@Column` | 字段 | 列映射：列名、JDBC 类型、长度、精度、默认值等 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `@Id` | 字段 | 主键：生成策略、sequence、生成器、辅助主键 | [主键策略](primarykey/sqltoy_primarykey.md) |
| `@BusinessId` | 字段 | 业务主键（订单号等规则号）与 `generateBizId` 配合 | [主键策略](primarykey/sqltoy_primarykey.md) |
| `@SqlToyFieldAlias` | 字段 | VO/POJO 字段名不一致时的别名映射 | [工具类](tools/utils.md) |
| `@OneToOne` | 字段 | 一对一/一对多级联加载与保存 | [对象化 CRUD](crud/sqltoy_crud.md) |
| `@OneToMany` | 字段 | 一对多级联（可带过滤、排序） | [对象化 CRUD](crud/sqltoy_crud.md) |
| `@Foreign` | 字段 | 外键约束（DDL 生成与删除/更新参照动作） | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |
| `@Sharding` | 类 | 分库分表策略（库、表、并发、全局回滚） | [分库分表](enterprise/sqltoy_sharding.md) |
| `@Strategy` | 类 | 分片策略引用（嵌在 `@Sharding` 内） | [分库分表](enterprise/sqltoy_sharding.md) |
| `@Tenant` | 类 / 字段 | 多租户字段标记 | [多租户](enterprise/sqltoy_multitenant.md) |
| `@DataVersion` | 类 / 字段 | 乐观锁版本号字段 | [数据版本控制](enterprise/data_version.md) |
| `@Secure` | 类 | 字段加密或脱敏规则 | [数据脱敏与加解密](enterprise/sqltoy_security.md) |
| `@SecureConfig` | 类 | 多条 `@Secure` 的容器 | [数据脱敏与加解密](enterprise/sqltoy_security.md) |
| `@Translate` | 字段 | 查询结果缓存翻译（单条） | [缓存翻译使用](quickstart/translates.md) |
| `@Translates` | 字段 | 多条 `@Translate` 的容器 | [缓存翻译使用](quickstart/translates.md) |
| `@Index` | 类 | 索引定义（进 DDL） | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |
| `@Indexes` | 类 | 多条 `@Index` 的容器 | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |
| `@Partition` | 类 | 表分区策略（进 DDL） | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |
| `@PartitionDef` | 类 | 单个分区明细（嵌在 `@Partition` 内） | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |
| `@PartitionKey` | 字段 | 分区字段标记（MPP 库建表与 DML 提示） | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |
| `@MppTable` | 类 | MPP 分析库表引擎元数据（ClickHouse/Doris/StarRocks） | [POJO 生成 DDL](primarykey/sqltoy_ddl.md) |

---

## 二、实体与字段映射

### @SqlToyEntity / @Entity

`@SqlToyEntity` 无属性，是 `@Entity` 的语义化别名；二者都可用于实体扫描（`packagesToScan`）。

| `@Entity` 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `tableName` | String | 必填 | 数据库表名（不含 schema） |
| `schema` | String | `""` | 模式名，多 schema 场景使用 |
| `comment` | String | `""` | 表注释，建表时写入 |
| `pk_constraint` | String | `""` | 主键约束名，如 `PRIMARY`；建表时用于命名主键 |

### @Column

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `name` | String | 必填 | 数据库列名 |
| `type` | int | `java.sql.Types.OTHER` | JDBC 类型；`OTHER` 时由字段 Java 类型推断 |
| `nativeType` | String | `""` | 原生类型名（如 `varchar2(50)`、`jsonb`），优先于 `type` 用于建表 |
| `nullable` | boolean | `true` | 是否可空 |
| `length` | long | `0` | 长度（字符/字节按字段类型） |
| `precision` / `scale` | int | `0` | 数值精度与小数位 |
| `generatedType` | `GeneratedType` | `DEFAULT` | 生成列：`DEFAULT`（普通）/`VIRTUAL`（虚拟列）/`STORED`（存储生成列） |
| `keyword` | boolean | `false` | 列名是否数据库保留字（影响对象操作为列名加引用符） |
| `comment` | String | `""` | 列注释 |
| `defaultValue` | String | `SqlToyConstants.DEFAULT_NULL` | 建表默认值；未设置表示无默认值 |
| `autoIncrement` | boolean | `false` | 是否自增列（DDL 用） |

> `keyword=true` 与全局 `spring.sqltoy.reservedWords` 是两条不同路径：前者解决**对象操作**中该列名的引用，后者解决**自定义 SQL** 中保留字的按方言适配，详见[常见问题](faq/faq.md)。

### @SqlToyFieldAlias

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `value` | String | 目标 POJO 的属性名；用于 VO 与 POJO 字段名不同时 `convertType` 的正确映射 |

---

## 三、主键与业务号

### @Id

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `strategy` | String | `assign` | 主键策略：`assign`（手工赋值）、`sequence`、`identity`、`default`（22 位）、`nanotime`（26 位）、`snowflake`、`UUID`、`ULID`、`redis` 等，取值与[主键策略](primarykey/sqltoy_primarykey.md)一致 |
| `sequence` | String | `""` | `sequence` 策略对应的序列名 |
| `generator` | String | `""` | 自定义生成器实现类（实现 `IdGenerator`），配置后优先于 `strategy` 的内置实现 |
| `isAssist` | boolean | `false` | 辅助主键：分区表的分区字段在有主键时必须同为主键，用它标记（mysql、pg 等） |

### @BusinessId

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `signature` | String | 必填 | 识别区分符表达式，支持 `@case(name,v1,then1,...)`、`@day(yyMMdd)`、`@substr(name,start,length)` 等宏 |
| `generator` | String | 必填 | 生成策略实现类，如 `org.sagacity.sqltoy.plugins.id.impl.RedisIdGenerator` |
| `length` | int | `-1` | 业务主键总长度，-1 取全局配置 |
| `sequenceSize` | int | `-1` | 尾部流水位数，-1 取全局配置 |
| `relatedColumns` | String[] | `{}` | 参与生成的关联字段（取值来源） |
| `start` | long | `1` | 流水初始值 |

> 一个表只支持配置**单个**业务主键；多个业务主键时用 `@BusinessId` + `lightDao.generateBizId(...)` 自行赋值，详见[主键策略](primarykey/sqltoy_primarykey.md)。

---

## 四、关联与级联

### @OneToOne / @OneToMany

两者属性基本一致，`@OneToMany` 多一个 `orderBy`：

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `fields` | String[] | `{}` | 主表参与关联的字段（为空表示用主键） |
| `mappedFields` | String[] | 必填 | 子表对应的字段 |
| `delete` | boolean | `false` | 删除主表时是否级联删除子表 |
| `load` | String | `""` | 级联加载时附带的过滤条件（如 `status=1`） |
| `update` | String | `""` | 级联修改控制 |
| `notNullField` | String | `""` | 非空校验字段 |
| `orderBy` | String | `""` | 仅 `@OneToMany`：子集合排序 |

> sqltoy 只支持**一级级联**；`loadAllCascade`/`updateCascade` 等批量方法底层用 in 查询优化，避免 N+1。

### @Foreign

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `constraintName` | String | `""` | 外键约束名 |
| `table` | String | 必填 | 被引用的表 |
| `field` | String | 必填 | 被引用的列 |
| `deleteRestict` | int | `1` | 删除参照动作（`ReferentialAction` 常量：CASCADE/RESTRICT/SET_NULL/NO_ACTION/SET_DEFAULT） |
| `updateRestict` | int | `1` | 更新参照动作，同上 |

> 6.0.3 起按数据库兼容性自动裁剪不支持的参照动作；字段名拼写 `Restict` 为历史遗留，勿改。

---

## 五、企业级特性

### @Sharding 与 @Strategy

| `@Sharding` 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `db` | `@Strategy` | 空 | 分库策略 |
| `table` | `@Strategy` | 空 | 分表策略 |
| `maxConcurrents` | int | `10` | 分片并行线程数：0 不限制、1 串行 |
| `maxWaitSeconds` | int | `-1` | 分片并行等待上限（秒） |
| `is_global_rollback` | boolean | `true` | 任一分片失败是否全局回滚 |

| `@Strategy` 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `name` | String | `""` | 策略 bean 名称 |
| `fields` | String[] | `{}` | 参与决策的字段 |
| `aliasNames` | String[] | `{}` | 字段别名（与 `fields` 对应，用于参数别名场景） |
| `decisionType` | String | `""` | 决策类型（传给策略实现区分场景，如查询/更新） |

```java
@Sharding(db = @Strategy(name = "hashDataSource", fields = { "tenantId" }),
          table = @Strategy(name = "realHisTable", fields = { "bizDate" }))
```

### @Tenant

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `field` | String | `""` | 租户字段名（实体属性名，框架自动映射列名）；为空时按约定/拦截器处理 |

### @DataVersion

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `field` | String | `""` | 版本号属性名 |
| `startDate` | boolean | `false` | 版本号是否以日期开头（如 `202209231`） |

### @Secure / @SecureConfig

| `@Secure` 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `field` | String | 必填 | 被加密/脱敏的列名 |
| `secureType` | `SecureType` | `ENCRYPT` | `encrypt`（RSA 加解密）或脱敏类型：`tel`、`name`、`email`、`address`、`bank-card`、`id-card`、`public-account`、`discrete-rate`、`other` |
| `sourceField` | String | `""` | 脱敏取值的源字段（如姓名取 `staffName` 的某个字） |
| `maskCode` | String | `""` | 脱敏替换字符，默认 `*` |
| `headSize` / `tailSize` | int | `0` | 保留首/尾字符数 |
| `maskRate` | int | `0` | 离散脱敏比例（`discrete-rate` 用） |

`@SecureConfig` 只有一个属性 `secures`（`Secure[]`），把多条 `@Secure` 装配到同一个实体上。

---

## 六、缓存翻译

### @Translate / @Translates

| `@Translate` 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `cacheName` | String | 必填 | 缓存名称（对应 `sqltoy-translate.xml` 中的 `cache`） |
| `cacheType` | String | `""` | 缓存内的类型（如字典分类） |
| `cacheIndex` | int | `1` | 用结果集的第几列去匹配缓存 key |
| `keyField` | String | 必填 | 翻译结果写入的属性名 |
| `split` | String | `""` | 多个 key 的分隔符（一个字段含多个码值时） |
| `join` | String | `""` | 翻译结果多值时的拼接符 |
| `where` | String | `""` | 条件翻译：仅当条件成立才翻译 |
| `uncached` | String | `""` | 未命中时的占位输出 |

`@Translates` 只有一个属性 `value`（`Translate[]`）。

---

## 七、DDL 相关

| 注解 | 必要属性 | 说明 |
| --- | --- | --- |
| `@Index` | `name`、`columns` | `isUnique`（默认 false）、`sortTypes`（各列 ASC/DESC） |
| `@Indexes` | `indexes` | 多条 `@Index` |
| `@Partition` | `strategy` | 分区策略（RANGE/LIST/HASH/RANGE COLUMNS/LIST COLUMNS）；`columns`、`expression`、`partitions` |
| `@PartitionDef` | `name` | 分区明细：`value`、`tablespace`、`endValue`、`endInclusive`（默认 true） |
| `@PartitionKey` | 无 | 标记分区字段，MPP 库建表与 DML 的分区键提示 |
| `@MppTable` | 无（按需） | `engine`、`engineArgs`、`keyModel`、`orderBy`、`distributedBy`、`buckets`、`properties`，对应 ClickHouse/Doris/StarRocks 的引擎元数据 |

```java
@SqlToyEntity
@Entity(tableName = "sqltoy_order_info", pk_constraint = "PRIMARY", comment = "订单主表")
@Indexes({ @Index(name = "idx_order_staff", columns = { "STAFF_CODE" }),
           @Index(name = "uk_order_no", isUnique = true, columns = { "ORDER_NO" }) })
@Partition(strategy = "RANGE", columns = { "TRANS_DATE" }, partitions = {
        @PartitionDef(name = "p202601", endValue = "2026-02-01"),
        @PartitionDef(name = "p202602", endValue = "2026-03-01", endInclusive = false) })
public class OrderInfo implements Serializable {
    @Id(strategy = "default")
    @Column(name = "ID", type = java.sql.Types.VARCHAR, length = 22, nullable = false)
    private String id;
    // ...
}
```

---

## 八、常见组合与注意事项

- **实体扫描**：`@Entity` / `@SqlToyEntity` 二者任一即可；`packagesToScan` 未配置时实体在首次使用时按需加载（native 场景**必须**配置，见 [GraalVM Native Image 指引](tools/graalvm_native.md)）；
- **`@Id` 与 `@Column` 必须同时标注在主键字段上**，`@Id` 只描述生成策略、`@Column` 描述列；
- **`@Column.type` 留 `OTHER`** 让框架按 Java 类型推断是最省心的做法；跨库建表有差异时用 `nativeType` 精确控制；
- **复合主键**：多个字段标 `@Id`，join 的 lambda 更新/删除会按 `LPK1…LPKn` 关联；
- **DDL 相关注解（`@Index`/`@Partition`/`@MppTable`/`@Foreign`）只在 `autoDDL=true` 建表或由 `lightDao.tableApi()` 生成 DDL 时生效**，不影响运行时 CRUD；
- **企业级注解是"声明"不是"配置"**：`@Tenant`/`@Sharding`/`@Secure` 都需要对应的拦截器、策略 bean 或 provider 配合，单独标注不会生效。
