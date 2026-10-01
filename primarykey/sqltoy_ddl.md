# POJO生成表结构DDL
* sqltoy支持项目启动时根据POJO实体生成ddl脚本并在数据库中执行

```yml
spring:
	sqltoy:
		#指定扫描POJO包路径，可以指定一个顶层包会自动递归扫描，也可以指定比较底层的包
		packagesToScan:
			- com.example.modules.commons.entity
			- com.example.modules.system.entity
		autoDDL: true
		#dialectDDLGenerator: com.xxx 自定义扩展实现类
```

* 通过代码生成整个项目POJO对应的数据库脚本

```java
@Test
public void testCreateSqlFile() {
	// 指定POJO所在的包路径
	String[] scanPackages = new String[] { "org.sagacity.sqltoy.demo.domain" };
	try {
		/**
		 * @param scanPackages
		 * @param saveFile            脚本存放文件
		 * @param upperOrLower        upper|lower 脚本表名、字段名是否统一转大写或小写
		 * @param dbType              数据库类型，用DBType.xx 提供
		 * @param schema              针对sqlserver需要提供(其他数据库可为null)，项目启动时会根据connection获取schema
		 * @param dialectDDLGenerator 自己指定ddl创建器,如果是：mysql、oracle、pg、sqlserver等数据库无需扩展，传递null即可
		 */
		DDLFactory.createSqlFile(scanPackages, "D://sqltoy.sql", "upper", DBType.MYSQL, null, null);
	} catch (Exception e) {
		// TODO Auto-generated catch block
		e.printStackTrace();
	}
}
```

## 实体注解与 DDL 元数据

DDL 生成支持以下实体注解（`@Partition`/`@PartitionDef`/`@MppTable` 为 **6.0.3 新增**，由 quickvo 依据数据库的分区定义、MPP 表定义自动产生，也可手工标注）：

| 注解 | 说明 |
| --- | --- |
| `@Foreign(table, field, constraintName)` | **外键标记**（6.0/2023.07 新增）：声明字段关联的表与字段，生成 DDL 时创建外键约束 |
| `@PartitionKey` | **分区字段标记**：MPP 数据库（如 StarRocks）建表时的分区键 |
| `@Partition` | **分区策略标记**（6.0.3 新增）：描述分区方式与分区键，生成 `PARTITION BY` 子句 |
| `@PartitionDef` | **分区明细**（6.0.3 新增）：配合 `@Partition` 描述每个分区的名称和边界 |
| `@MppTable` | **MPP 表引擎元数据**（6.0.3 新增）：ClickHouse/Doris/StarRocks 建表时的引擎、键模型、分桶等定义 |

### 1、外键与参照动作

```java
@Accessors(chain = true)
@Entity(tableName = "sqltoy_order_info", pk_constraint = "PRIMARY")
public class OrderInfo implements Serializable {

    @Column(name = "ORGAN_ID")
    // 外键：关联 sqltoy_organ_info 表的 ORGAN_ID 字段
    // deleteRestict/updateRestict 取值见 org.sagacity.sqltoy.config.model.ReferentialAction 常量：
    // 0:CASCADE(级联)、1:RESTRICT(限制，默认)、2:SET_NULL(置空)、3:NO_ACTION(无动作)、4:SET_DEFAULT(置默认值)
    @Foreign(table = "sqltoy_organ_info", field = "ORGAN_ID", constraintName = "FK_ORDER_ORGAN", deleteRestict = 0)
    private String organId;
}
```

生成外键约束时按数据库兼容性自动裁剪：Oracle/DM 不支持 `ON UPDATE` 子句，Oracle 不接受 `NO ACTION` 关键字（ORA-02000），Oracle/DM 与 MySQL 系（InnoDB）不支持 `SET DEFAULT`——不支持的动作自动跳过，退化为默认的 NO ACTION 行为。

### 2、表分区（@Partition / @PartitionDef / @PartitionKey）

```java
@Entity(tableName = "SQLTOY_TRANS_INFO", pk_constraint = "PRIMARY")
// 分区策略：RANGE|LIST|HASH|RANGE_COLUMNS|LIST_COLUMNS；
// columns 为分区键列（缺省时自动收集字段级 @PartitionKey 标记的字段，两者双向联动）；
// expression 为数据库原生分区表达式原文（如 mysql 的 TO_DAYS(createTime)），提供时优先生效
@Partition(strategy = "RANGE", columns = { "BIZ_DATE" }, partitions = {
        @PartitionDef(name = "p202601", value = "2026-02-01"),   // 边界值：日期形态自动加引号
        @PartitionDef(name = "p202602", value = "2026-03-01"),
        @PartitionDef(name = "pmax", value = "MAXVALUE") })      // 兜底分区
public class TransInfo implements Serializable {

    @Column(name = "BIZ_DATE")
    @PartitionKey   // 字段级分区标记，与 @Partition.columns 双向联动
    private LocalDate bizDate;
}
```

生成 MySQL 建表语句时自动渲染：

```sql
CREATE TABLE SQLTOY_TRANS_INFO (...)
PARTITION BY RANGE (BIZ_DATE) (
   PARTITION p202601 VALUES LESS THAN ('2026-02-01'),
   PARTITION p202602 VALUES LESS THAN ('2026-03-01'),
   PARTITION pmax VALUES LESS THAN (MAXVALUE)
)
```

分区明细渲染规则：RANGE 分区按上界升序排序（MAXVALUE 兜底分区置末），LIST 分区在 Oracle/DM 下渲染 `VALUES (v)`、MySQL 系渲染 `VALUES IN (v)`；HASH/KEY 策略按分区数量渲染 `PARTITIONS n`；pg/oracle 等策略型分区库无明细时保持注释形态，分区由数据库自行管理。

### 3、MPP 分析库表引擎（@MppTable）

ClickHouse/Doris/StarRocks 建表需要引擎、排序键、分桶等元数据，通过 `@MppTable` 描述：

```java
@Entity(tableName = "SQLTOY_ORDER_OLAP")
@MppTable(
    engine = "OLAP",                          // ClickHouse 为 MergeTree/ReplacingMergeTree 等；Doris/StarRocks 为 OLAP
    keyModel = "DUPLICATE",                   // Doris/StarRocks 键模型：UNIQUE/PRIMARY/DUPLICATE/AGGREGATE
    orderBy = { "EVENT_TIME", "ORDER_ID" },   // 排序键：ClickHouse 的 ORDER BY 列；Doris/SR 为 KEY 模型的键列
    distributedBy = { "ORDER_ID" },           // 分桶列：Doris/StarRocks 的 DISTRIBUTED BY HASH 列
    buckets = 10,                             // 分桶数，缺省由数据库自动决定
    properties = { "replication_num=3" })     // 表属性：CK 渲染为 SETTINGS k=v；Doris/SR 渲染为 PROPERTIES("k"="v")
@Partition(strategy = "RANGE", columns = { "EVENT_TIME" })
public class OrderOlap implements Serializable { ... }
```

Doris/StarRocks 生成的建表语句形如：

```sql
CREATE TABLE SQLTOY_ORDER_OLAP (...)
ENGINE = OLAP
DUPLICATE KEY(EVENT_TIME, ORDER_ID)
COMMENT '订单明细'
PARTITION BY RANGE (EVENT_TIME) (...)
DISTRIBUTED BY HASH(ORDER_ID) BUCKETS 10
PROPERTIES ("replication_num" = "3")
```

ClickHouse 生成的建表语句形如（`engine=ReplacingMergeTree`、`engineArgs` 为版本列等引擎参数、`properties` 渲染为 `SETTINGS`）：

```sql
CREATE TABLE SQLTOY_ORDER_OLAP (...)
ENGINE = ReplacingMergeTree(ver)
ORDER BY (EVENT_TIME, ORDER_ID)
PARTITION BY EVENT_TIME
SETTINGS index_granularity = 8192
```

### 4、各数据库 DDL 生成器支持（6.0.3）

| 数据库 | 生成器 | 说明 |
| --- | --- | --- |
| MySQL / MySQL 5.7 | `MySqlDDLGenerator` | 支持 `@Partition` 分区子句 |
| Doris / StarRocks | `DorisDDLGenerator` / `StarRocksDDLGenerator` | 6.0.3 新增专用生成器（此前复用 MySQL 生成器），支持 `@MppTable` 引擎/键模型/分桶/属性、分区子句，VARCHAR 超 65533 自动降级 STRING |
| ClickHouse | `ClickHouseDDLGenerator` | 6.0.3 新增，支持 MergeTree 系引擎、`ORDER BY`、`SETTINGS`、`PARTITION BY` 表达式 |
| PostgreSQL 系（PG/GaussDB/OpenGauss/MogDB/Vastbase/StarDB/Oscar/Kingbase） | `PostgreSqlDDLGenerator` | 含 6.0.3 对 Kingbase 的纳入 |
| Oracle / Oracle11 / 达梦 | `OracleDDLGenerator` | |
| SQL Server | `SqlServerDDLGenerator` | |
| DB2 | `DB2DDLGenerator` | 6.0.3 新增专用生成器（含 CLOB、JSON→CLOB 承载） |
| SAP HANA | `HanaDDLGenerator` | 6.0.3 新增（含 NCLOB 大文本、JSON→NCLOB 承载） |
| SQLite | `SQLiteDDLGenerator` | 6.0.3 新增 |
| H2 | `H2DDLGenerator` | |

其他类型化细节：JSON 列在无原生 JSON 类型的库自动降级承载（HANA→NCLOB、SQL Server→NVARCHAR(MAX)、DB2/Oracle11→CLOB）；pgvector 向量类型仅在维度有效时渲染 `(n)`，无界向量渲染为 `vector`。

> 这些注解只影响 DDL 生成（autoDDL / DDLFactory），不改变运行时行为（`@PartitionKey` 亦作为 MPP 库 DML 的分区键提示）。
