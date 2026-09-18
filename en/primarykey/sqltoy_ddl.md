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

## Entity Foreign Key and Partition Key Markers

DDL generation supports two entity annotations:

| Annotation | Description |
| --- | --- |
| `@Foreign(table, field, constraintName)` | **Foreign key marker** (new in 6.0/2023.07): declares the table and field a column references; a foreign key constraint is created when the DDL is generated |
| `@PartitionKey` | **Partition key marker**: the partition key when creating tables on MPP databases (such as StarRocks) |

```java
@Accessors(chain = true)
@Entity(tableName = "sqltoy_order_info", pk_constraint = "PRIMARY")
public class OrderInfo implements Serializable {

    @Column(name = "ORGAN_ID")
    // Foreign key: references the ORGAN_ID field of the sqltoy_organ_info table
    @Foreign(table = "sqltoy_organ_info", field = "ORGAN_ID", constraintName = "FK_ORDER_ORGAN")
    private String organId;

    @Column(name = "BIZ_DATE")
    // Partition field when creating tables on MPP databases (such as StarRocks)
    @PartitionKey
    private LocalDate bizDate;
}
```

> These two annotations only affect DDL generation (autoDDL / DDLFactory) and do not change runtime behavior.
