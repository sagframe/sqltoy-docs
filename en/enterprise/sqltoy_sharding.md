# Sharding
* sqltoy supports database & table sharding, but with the wide adoption of distributed high-performance databases such as Doris, database & table sharding has gradually become less significant
* sqltoy database & table sharding mainly involves the following steps
* 1. Define the sharding strategies

```java
@Configuration
public class ShardingStrategyConfig {

	/**
	 * @TODO Demonstrates table sharding between the real-time table and history tables
	 * @return
	 */
	@Bean(name = "realHisTable", initMethod = "initialize")
	public ShardingStrategy realHisTable() {
		DefaultShardingStrategy strategy = new DefaultShardingStrategy();
		// Split into four tables: current day, 15 days, 90 days, and full history
		strategy.setDays("1,15,90");
		HashMap<String, String> tableMap = new HashMap<String, String>();
		// Use SQLTOY_TRANS_INFO (current day) when writing SQL
		tableMap.put("SQLTOY_TRANS_INFO",
				"SQLTOY_TRANS_INFO,SQLTOY_TRANS_INFO_15,SQLTOY_TRANS_INFO_90,SQLTOY_TRANS_INFO_HIS");
		strategy.setTableNamesMap(tableMap);
		return strategy;
	}
	
	/**
	 * @TODO Shards databases by hash modulo
	 * @return
	 */
	@Bean(name = "hashDataSource", initMethod = "initialize")
	public ShardingStrategy hashDataSource() {
		HashShardingStrategy strategy = new HashShardingStrategy();
		HashMap<String, String> dataSourceMap = new HashMap<String, String>();
		// Shard databases by hash modulo
		dataSourceMap.put("0", "dataSource");
		// Temporarily use the same database to simulate multiple databases
		// dataSourceMap.put("1", "slave1");
		// dataSourceMap.put("2", "slave2");
		strategy.setDataSourceMap(dataSourceMap);
		return strategy;
	}
}
```

* 2. The sqltoy framework provides two strategy implementations for quick use (developers can also extend and implement their own)

```java
# Segments tables by date period, shards databases by weight
org.sagacity.sqltoy.plugins.sharding.impl.DefaultShardingStrategy;
# Shards databases & tables by hash modulo
org.sagacity.sqltoy.plugins.sharding.impl.HashShardingStrategy;

> [!NOTE]
> Since 6.0, `DefaultShardingStrategy` (table sharding by date period) lives in the **spring / spring-starter modules** (package name unchanged: `org.sagacity.sqltoy.plugins.sharding.impl`), and core only keeps `HashShardingStrategy`; imports are unaffected in a Spring environment, while in a pure Java environment you need to include the spring module or implement the strategy yourself.

# The interface to implement

public interface ShardingStrategy {
	/**
	 * @todo Determine the concrete table name that the table in the current SQL statement should be replaced with, based on the conditions
	 * @param sqlToyContext
	 * @param entityClass
	 * @param baseTableName the current table name passed in
	 * @param decisionType  decision category
	 * @param paramsMap     carries {[param1,param1 value],[param2,param2 value]}
	 * @return returns the concrete table name resolved from the parameters; returning null means the original table is used
	 */
	public String getShardingTable(SqlToyContext sqlToyContext, Class entityClass, String baseTableName,
			String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

	/**
	 * @todo Get the database information for final execution according to the database sharding strategy
	 * @param sqlToyContext
	 * @param entityClass
	 * @param tableOrSql
	 * @param decisionType  decision category
	 * @param paramsMap     carries {[param1,param1 value],[param2,param2 value]}
	 * @return returns the concrete dataSource resolved from the parameters; returning null means the current default data source is used
	 */
	public ShardingDBModel getShardingDB(SqlToyContext sqlToyContext, Class entityClass, String tableOrSql,
			String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

	/**
	 * @TODO Initialization
	 */
	public void initialize();
}

```

* 3. Database & table sharding at query time: database sharding and table sharding can each be used on its own depending on the actual situation — they do not have to be combined as in the example; it also supports **database sharding and multiple table sharding within a single SQL** (each strategy is defined independently). In insert/update/delete scenarios, the @Sharding annotation can likewise configure both db and table strategies

* 3.1 Define database & table sharding strategies in XML

```xml
<sql id="sys_queryTransInfo">
	   <!-- Determine which database to use by modulo on the tenant id -->
		<sharding-datasource strategy="hashDataSource" params="tenantId"/>
		<!-- Decide which table to query based on the date -->
		<sharding-table tables="SQLTOY_TRANS_INFO" strategy="realHisTable" params="bizDate"/>
		<value>
			<![CDATA[
			select * from SQLTOY_TRANS_INFO where tenant_id=:tenantId and bizDate<=:bizDate 
			]]>
		</value>
</sql>
```

* 3.2 Shard databases & tables in Java via the dbSharding and tableSharding modes of QueryExecutor or EntityQuery

```java
@Test
public void testSharding() {
	String sql = """
			select * from SQLTOY_TRANS_INFO where tenant_id=:tenantId and bizDate<=:bizDate
			""";
	lightDao.findByQuery(new QueryExecutor(sql)
			.values(MapKit.keys("tenantId", "bizDate").values("S001", LocalDate.now().plusDays(-2)))
			.dbSharding("hashDataSource", "tenantId")
			.tableSharding("realHisTable", new String[] { "SQLTOY_TRANS_INFO" }, "bizDate"));
}
```

* 4. Database & table sharding for insert/update/delete operations: add the @Sharding annotation on the POJO, then lightDao.save(entity) will automatically store the data into the concrete table or database

* 4.1 Annotation example on a POJO with both database sharding and table sharding

```java
@Data
@Accessors(chain = true)
@Entity(tableName="SQLTOY_TRANS_INFO",pk_constraint="PRIMARY")
@Sharding(db = @Strategy(name = "hashDataSource", fields = { "tenantId" })
,table = @Strategy(name = "realHisTable", fields = { "bizDate" })
)
public class SqlToyTransInfo implements Serializable
{
	@Id
	@Column(name="ID",comment="ID primary key",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String id;
	
	@Column(name="TENANT_ID",comment="Tenant ID",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String tenantId;
	
	@Column(name="BIZ_DATE",comment="Business date",type=java.sql.Types.DATE,nullable=false)
	private LocalDate bizDate;
	
	//.....
}

```

* 4.2 Annotation example on a POJO with table sharding only

```java
@Data
@Accessors(chain = true)
@Entity(tableName="SQLTOY_TRANS_INFO",pk_constraint="PRIMARY")
@Sharding(table = @Strategy(name = "realHisTable", fields = { "bizDate" })
)
public class SqlToyTransInfo implements Serializable
{
	@Id
	@Column(name="ID",comment="ID primary key",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String id;
	
	@Column(name="TENANT_ID",comment="Tenant ID",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String tenantId;
	
	@Column(name="BIZ_DATE",comment="Business date",type=java.sql.Types.DATE,nullable=false)
	private LocalDate bizDate;
	
	//.....
}

```
