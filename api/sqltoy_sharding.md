# 分库分表
* sqltoy支持分库分表功能，但随着Doris等分布式高性能数据库的广泛应用，分库分表意义逐步淡化
* sqltoy分库分表主要分以下几个步骤
* 1、定义分库分表策略

```java
@Configuration
public class ShardingStrategyConfig {

	/**
	 * @TODO 演示实时表和历史表分表效果
	 * @return
	 */
	@Bean(name = "realHisTable", initMethod = "initialize")
	public ShardingStrategy realHisTable() {
		DefaultShardingStrategy strategy = new DefaultShardingStrategy();
		// 分:当天、15天、90天、全量 四张表
		strategy.setDays("1,15,90");
		HashMap<String, String> tableMap = new HashMap<String, String>();
		// 写sql时用SQLTOY_TRANS_INFO(当天)
		tableMap.put("SQLTOY_TRANS_INFO",
				"SQLTOY_TRANS_INFO,SQLTOY_TRANS_INFO_15,SQLTOY_TRANS_INFO_90,SQLTOY_TRANS_INFO_HIS");
		strategy.setTableNamesMap(tableMap);
		return strategy;
	}
	
	/**
	 * @TODO 通过hash取模方式分库
	 * @return
	 */
	@Bean(name = "hashDataSource", initMethod = "initialize")
	public ShardingStrategy hashDataSource() {
		HashShardingStrategy strategy = new HashShardingStrategy();
		HashMap<String, String> dataSourceMap = new HashMap<String, String>();
		// 根据hash取模分库
		dataSourceMap.put("0", "dataSource");
		// 暂时用同一个数据库来模拟多个库
		// dataSourceMap.put("1", "slave1");
		// dataSourceMap.put("2", "slave2");
		strategy.setDataSourceMap(dataSourceMap);
		return strategy;
	}
}
```

* 2、sqltoy框架提供了2种策略实现供快速使用（开发者也可以自行扩展实现）

```java
# 按日期周期分段分表、按权重分库
org.sagacity.sqltoy.plugins.sharding.impl.DefaultShardingStrategy;
# 按hash取模分库分表
org.sagacity.sqltoy.plugins.sharding.impl.HashShardingStrategy;

# 实现接口

public interface ShardingStrategy {
	/**
	 * @todo 根据条件确定当前sql语句中的表要替换成的具体表名
	 * @param sqlToyContext
	 * @param entityClass
	 * @param baseTableName 传递过来的当前表名
	 * @param decisionType  决策类别
	 * @param paramsMap     传递{[参数1,参数1值],[参数2,参数2值]}
	 * @return 根据参数取得具体表名,返回null表示使用原表
	 */
	public String getShardingTable(SqlToyContext sqlToyContext, Class entityClass, String baseTableName,
			String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

	/**
	 * @todo 根据分库策略获取最终执行的数据库信息
	 * @param sqlToyContext
	 * @param entityClass
	 * @param tableOrSql
	 * @param decisionType  决策类别
	 * @param paramsMap     传递{[参数1,参数1值],[参数2,参数2值]}
	 * @return 根据参数取得具体dataSource,返回null则表示使用当前默认的数据源
	 */
	public ShardingDBModel getShardingDB(SqlToyContext sqlToyContext, Class entityClass, String tableOrSql,
			String decisionType, IgnoreCaseLinkedMap<String, Object> paramsMap);

	/**
	 * @TODO 初始化
	 */
	public void initialize();
}

```

* 3、查询时分库分表:分库、分表可以根据实际情况使用其中一种，并非要按示例里面同时使用

* 3.1 基于xml定义分库分表策略

```xml
<sql id="sys_queryTransInfo">
	   <!-- 根据租户id取模，决定使用哪个数据库 -->
		<sharding-datasource strategy="hashDataSource" params="tenantId"/>
		<!-- 根据日期决定查询那张表 -->
		<sharding-table tables="SQLTOY_TRANS_INFO" strategy="realHisTable" params="bizDate"/>
		<value>
			<![CDATA[
			select * from SQLTOY_TRANS_INFO where tenant_id=:tenantId and bizDate<=:bizDate 
			]]>
		</value>
</sql>
```

* 3.2 基于java通过QueryExecutor或EntityQuery中的dbSharding、tableSharding模式分库分表

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

* 4、增删改操作分库分表:需要在POJO上增加@Sharding注解，然后通过lightDao.save(entity)就会自动存放到具体表或库中

* 4.1 POJO上注解示例同时分库、分表

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
	@Column(name="ID",comment="ID主键",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String id;
	
	@Column(name="TENANT_ID",comment="租户ID",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String tenantId;
	
	@Column(name="BIZ_DATE",comment="业务日期",type=java.sql.Types.DATE,nullable=false)
	private LocalDate bizDate;
	
	//.....
}

```

* 4.2 POJO上注解示例同时分表

```java
@Data
@Accessors(chain = true)
@Entity(tableName="SQLTOY_TRANS_INFO",pk_constraint="PRIMARY")
@Sharding(table = @Strategy(name = "realHisTable", fields = { "bizDate" })
)
public class SqlToyTransInfo implements Serializable
{
	@Id
	@Column(name="ID",comment="ID主键",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String id;
	
	@Column(name="TENANT_ID",comment="租户ID",length=50L,type=java.sql.Types.VARCHAR,nullable=false)
	private String tenantId;
	
	@Column(name="BIZ_DATE",comment="业务日期",type=java.sql.Types.DATE,nullable=false)
	private LocalDate bizDate;
	
	//.....
}

```

