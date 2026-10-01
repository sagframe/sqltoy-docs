# POJO to DDL
* sqltoy supports generating DDL scripts from POJO entities at application startup and executing them in the database

```yml
spring:
	sqltoy:
		# specify the POJO package paths to scan; you can specify a top-level package for automatic recursive scanning, or a lower-level package
		packagesToScan:
			- com.example.modules.commons.entity
			- com.example.modules.system.entity
		autoDDL: true
		#dialectDDLGenerator: com.xxx custom extension implementation class
```

* Generate the database script for all POJOs in the project via code

```java
@Test
public void testCreateSqlFile() {
	// specify the package path where the POJOs reside
	String[] scanPackages = new String[] { "org.sagacity.sqltoy.demo.domain" };
	try {
		/**
		 * @param scanPackages
		 * @param saveFile            file where the script is saved
		 * @param upperOrLower        upper|lower whether table names and column names in the script are uniformly converted to upper or lower case
		 * @param dbType              database type, provided via DBType.xx
		 * @param schema              required for sqlserver (can be null for other databases); at application startup the schema is obtained from the connection
		 * @param dialectDDLGenerator your own DDL creator; for databases such as mysql, oracle, pg, sqlserver, no extension is needed, just pass null
		 */
		DDLFactory.createSqlFile(scanPackages, "D://sqltoy.sql", "upper", DBType.MYSQL, null, null);
	} catch (Exception e) {
		// TODO Auto-generated catch block
		e.printStackTrace();
	}
}
```

## Entity Annotations and DDL Metadata

DDL generation supports the following entity annotations (`@Partition`/`@PartitionDef`/`@MppTable` are **new in 6.0.3**; quickvo generates them automatically from the database's partition definitions and MPP table definitions, and you can also add them by hand):

| Annotation | Description |
| --- | --- |
| `@Foreign(table, field, constraintName)` | **Foreign key marker** (new in 6.0/2023.07): declares the table and field a column references; a foreign key constraint is created when the DDL is generated |
| `@PartitionKey` | **Partition key marker**: the partition key when creating tables on MPP databases (such as StarRocks) |
| `@Partition` | **Partition strategy marker** (new in 6.0.3): describes the partitioning method and partition key; renders the `PARTITION BY` clause |
| `@PartitionDef` | **Partition detail** (new in 6.0.3): used with `@Partition` to describe each partition's name and bound |
| `@MppTable` | **MPP table-engine metadata** (new in 6.0.3): engine, key model, bucketing and similar definitions when creating tables on ClickHouse/Doris/StarRocks |

### 1. Foreign keys and referential actions

```java
@Accessors(chain = true)
@Entity(tableName = "sqltoy_order_info", pk_constraint = "PRIMARY")
public class OrderInfo implements Serializable {

    @Column(name = "ORGAN_ID")
    // Foreign key: references the ORGAN_ID field of the sqltoy_organ_info table
    // deleteRestict/updateRestict values: see the org.sagacity.sqltoy.config.model.ReferentialAction constants:
    // 0:CASCADE, 1:RESTRICT (default), 2:SET_NULL, 3:NO_ACTION, 4:SET_DEFAULT
    @Foreign(table = "sqltoy_organ_info", field = "ORGAN_ID", constraintName = "FK_ORDER_ORGAN", deleteRestict = 0)
    private String organId;
}
```

When generating the foreign key constraint, actions are trimmed automatically per database compatibility: Oracle/DM do not support the `ON UPDATE` clause; Oracle rejects the `NO ACTION` keyword (ORA-02000); Oracle/DM and the MySQL family (InnoDB) do not support `SET DEFAULT` — unsupported actions are skipped automatically, degrading to the default NO ACTION behavior.

### 2. Table partitioning (@Partition / @PartitionDef / @PartitionKey)

```java
@Entity(tableName = "SQLTOY_TRANS_INFO", pk_constraint = "PRIMARY")
// Partition strategy: RANGE|LIST|HASH|RANGE_COLUMNS|LIST_COLUMNS;
// columns: partition key columns (defaults to collecting fields marked with field-level @PartitionKey; the two link both ways);
// expression: the database-native partition expression verbatim (e.g. mysql's TO_DAYS(createTime)); takes precedence when provided
@Partition(strategy = "RANGE", columns = { "BIZ_DATE" }, partitions = {
        @PartitionDef(name = "p202601", value = "2026-02-01"),   // bound value: date-form values are quoted automatically
        @PartitionDef(name = "p202602", value = "2026-03-01"),
        @PartitionDef(name = "pmax", value = "MAXVALUE") })      // catch-all partition
public class TransInfo implements Serializable {

    @Column(name = "BIZ_DATE")
    @PartitionKey   // field-level partition marker, linked both ways with @Partition.columns
    private LocalDate bizDate;
}
```

The generated MySQL create-table statement renders automatically:

```sql
CREATE TABLE SQLTOY_TRANS_INFO (...)
PARTITION BY RANGE (BIZ_DATE) (
   PARTITION p202601 VALUES LESS THAN ('2026-02-01'),
   PARTITION p202602 VALUES LESS THAN ('2026-03-01'),
   PARTITION pmax VALUES LESS THAN (MAXVALUE)
)
```

Partition detail rendering rules: RANGE partitions are sorted by upper bound ascending (the MAXVALUE catch-all partition goes last); LIST partitions render `VALUES (v)` on Oracle/DM and `VALUES IN (v)` on the MySQL family; HASH/KEY strategies render `PARTITIONS n` by partition count; on strategy-based partitioning databases such as pg/oracle, when no details are present they remain in comment form and partitions are managed by the database itself.

### 3. MPP analytical-database table engines (@MppTable)

Creating tables on ClickHouse/Doris/StarRocks requires engine, sort key, bucketing and similar metadata, described via `@MppTable`:

```java
@Entity(tableName = "SQLTOY_ORDER_OLAP")
@MppTable(
    engine = "OLAP",                          // ClickHouse: MergeTree/ReplacingMergeTree etc.; Doris/StarRocks: OLAP
    keyModel = "DUPLICATE",                   // Doris/StarRocks key model: UNIQUE/PRIMARY/DUPLICATE/AGGREGATE
    orderBy = { "EVENT_TIME", "ORDER_ID" },   // sort key: ClickHouse's ORDER BY columns; Doris/SR's KEY-model key columns
    distributedBy = { "ORDER_ID" },           // bucketing columns: Doris/StarRocks's DISTRIBUTED BY HASH columns
    buckets = 10,                             // bucket count; by default the database decides
    properties = { "replication_num=3" })     // table properties: CK renders SETTINGS k=v; Doris/SR renders PROPERTIES("k"="v")
@Partition(strategy = "RANGE", columns = { "EVENT_TIME" })
public class OrderOlap implements Serializable { ... }
```

The Doris/StarRocks create-table statement looks like:

```sql
CREATE TABLE SQLTOY_ORDER_OLAP (...)
ENGINE = OLAP
DUPLICATE KEY(EVENT_TIME, ORDER_ID)
COMMENT 'order detail'
PARTITION BY RANGE (EVENT_TIME) (...)
DISTRIBUTED BY HASH(ORDER_ID) BUCKETS 10
PROPERTIES ("replication_num" = "3")
```

The ClickHouse create-table statement looks like (`engine=ReplacingMergeTree`, `engineArgs` carrying engine arguments such as the version column, `properties` rendered as `SETTINGS`):

```sql
CREATE TABLE SQLTOY_ORDER_OLAP (...)
ENGINE = ReplacingMergeTree(ver)
ORDER BY (EVENT_TIME, ORDER_ID)
PARTITION BY EVENT_TIME
SETTINGS index_granularity = 8192
```

### 4. DDL generator support per database (6.0.3)

| Database | Generator | Notes |
| --- | --- | --- |
| MySQL / MySQL 5.7 | `MySqlDDLGenerator` | supports the `@Partition` partition clause |
| Doris / StarRocks | `DorisDDLGenerator` / `StarRocksDDLGenerator` | dedicated generators new in 6.0.3 (previously reused the MySQL generator); support `@MppTable` engine/key model/bucketing/properties and partition clauses; VARCHAR beyond 65533 degrades to STRING automatically |
| ClickHouse | `ClickHouseDDLGenerator` | new in 6.0.3; supports the MergeTree engine family, `ORDER BY`, `SETTINGS` and `PARTITION BY` expressions |
| PostgreSQL family (PG/GaussDB/OpenGauss/MogDB/Vastbase/StarDB/Oscar/Kingbase) | `PostgreSqlDDLGenerator` | includes Kingbase coverage added in 6.0.3 |
| Oracle / Oracle11 / DM | `OracleDDLGenerator` | |
| SQL Server | `SqlServerDDLGenerator` | |
| DB2 | `DB2DDLGenerator` | dedicated generator new in 6.0.3 (incl. CLOB and JSON→CLOB carrier) |
| SAP HANA | `HanaDDLGenerator` | new in 6.0.3 (incl. NCLOB large text and JSON→NCLOB carrier) |
| SQLite | `SQLiteDDLGenerator` | new in 6.0.3 |
| H2 | `H2DDLGenerator` | |

Other typing details: JSON columns degrade gracefully on databases without a native JSON type (HANA→NCLOB, SQL Server→NVARCHAR(MAX), DB2/Oracle11→CLOB); the pgvector vector type renders `(n)` only when the dimension is valid, and an unbounded vector renders as `vector`.

> These annotations only affect DDL generation (autoDDL / DDLFactory) and do not change runtime behavior (`@PartitionKey` also serves as the partition key hint for DML on MPP databases).
