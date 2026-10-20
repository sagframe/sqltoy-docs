# Principles for learning sqltoy-orm
* Do not carry over habits from MyBatis(-Plus) or similar frameworks
* Think in explicit logic and straightforward patterns
* When you see something slightly different from what you know, don't rush to reject it

# Steps to build a sqltoy project

> This article is fully in sync with the demo project [sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld): the project runs on an **in-memory H2 database** by default (schema and seed data load automatically), so `mvn test` works right after cloning — zero install (7 demo tests, all green).

## 1. Create a Spring Boot project and configure the data source
* See: [sqltoy demo project sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld)

```java
@SpringBootApplication
@ComponentScan(basePackages = { "com.sqltoy.helloworld" })
@EnableTransactionManagement
public class SqlToyApplication {
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		SpringApplication.run(SqlToyApplication.class, args);
	}
}
```
* Hikari is used as the connection pool (choose any pool you prefer)

```xml
<!-- Spring's built-in database connection pool (version managed by spring-boot-starter-parent) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>
<!-- zero-install in-memory database: the demo project runs on H2 by default -->
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
</dependency>
```

* Configure application.yml (the zero-install H2 form, identical to the demo project)

```yml
spring:
    # Zero install: H2 in-memory database by default; schema and seed data are
    # loaded by spring.sql.init (mock/h2/)
    datasource:
       name: dataSource
       type: com.zaxxer.hikari.HikariDataSource
       driver-class-name: org.h2.Driver
       username: sa
       password: ""
       isAutoCommit: false
       # random database name per Spring context, so test contexts never interfere
       url: jdbc:h2:mem:helloworld-${random.uuid};DB_CLOSE_DELAY=-1
    # demo schema + seed data (H2 DDL in step 3)
    sql:
       init:
         mode: always
         schema-locations: classpath:mock/h2/schema-h2.sql
         data-locations: classpath:mock/h2/data-h2.sql
    # note: sqltoy properties live under the spring.sqltoy prefix
    # (a common mistake is omitting the "spring." prefix so nothing gets loaded)
    sqltoy:
       # Optional: where the sql.xml files live (scanned recursively; multiple paths example: classpath:com/sqltoy/helloworld,classpath:com/sqltoy/system
       sqlResourcesDir: classpath:com/sqltoy/helloworld
       # Defaults to false; in debug mode executed SQL is printed and sql files are watched and reloaded on change
       debug: true
```

* Switching to MySQL (or any real database): replace the datasource section and set `sql.init.mode` to `never` (create the tables with the MySQL DDL in step 3)

```yml
spring:
    datasource:
       name: dataSource
       type: com.zaxxer.hikari.HikariDataSource
       driver-class-name: com.mysql.cj.jdbc.Driver
       username: helloworld
       password: helloworld
       isAutoCommit: false
       url: jdbc:mysql://127.0.0.1:3306/helloworld?useUnicode=true&characterEncoding=utf-8&serverTimezone=GMT%2B8&useSSL=false&allowPublicKeyRetrieval=true
```

> **Best practice: keep `*.sql.xml` files in the code directory (not resources)**, next to the VOs of the same module. Benefits: ① developers write and maintain SQL inside their own module without jumping between directories; ② the whole module can be extracted and reused as a unit, evolving toward productized modules. This requires a `resources` section in pom.xml so XML files under the java source directory get packaged:

```xml
<resources>
	<resource>
		<directory>src/main/java</directory>
		<excludes>
			<exclude>**/*.java</exclude>
		</excludes>
		<includes>
			<include>**/*.xml</include>
		</includes>
	</resource>
	<resource>
		<directory>src/main/resources</directory>
		<includes>
			<include>**/*.xml</include>
			<include>**/*.properties</include>
			<include>**/*.yml</include>
			<!-- H2 schema / seed-data scripts -->
			<include>**/*.sql</include>
		</includes>
	</resource>
</resources>
```

## 2. Add sqltoy-orm-spring-starter in pom.xml
* Spring Boot

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-spring-starter</artifactId>
	<!-- For JDK 8 use 5.6.96.jre8 (final) -->
	<version>6.0.8</version>
</dependency>
<!-- Cache translate (see the Cache Translate tutorial) needs a cache implementation;
     sqltoy supports ehcache by default (runtime scope so it is packaged into the boot jar) -->
<dependency>
	<groupId>org.ehcache</groupId>
	<artifactId>ehcache</artifactId>
	<scope>runtime</scope>
</dependency>
```
* Solon

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-solon-plugin</artifactId>
	<!-- For JDK 8 use 5.6.96.jre8 (final) -->
	<version>6.0.8</version>
</dependency>
```

## 3. Create the table: sqltoy_order_info

* Zero-install H2 form: the DDL lives in `src/main/resources/mock/h2/schema-h2.sql` and is executed at startup by `spring.sql.init` (the demo project also ships the organ/dictionary tables used by the cache-translate demos, plus seed data in `data-h2.sql`):

```sql
DROP TABLE IF EXISTS SQLTOY_ORDER_INFO;
CREATE TABLE SQLTOY_ORDER_INFO (
    ORDER_ID     VARCHAR(32) NOT NULL,
    ORDER_TYPE   VARCHAR(32),
    PRODUCT_CODE VARCHAR(32),
    UOM          VARCHAR(30),
    PRICE        DECIMAL(24, 6),
    QUANTITY     DECIMAL(24, 6),
    TOTAL_AMT    DECIMAL(24, 6),
    STAFF_CODE   VARCHAR(32),
    ORGAN_ID     VARCHAR(32),
    STATUS       INT,
    CREATE_BY    VARCHAR(32),
    CREATE_TIME  TIMESTAMP,
    UPDATE_BY    VARCHAR(32),
    UPDATE_TIME  TIMESTAMP,
    CONSTRAINT PK_ORDER_INFO PRIMARY KEY (ORDER_ID)
);
COMMENT ON TABLE SQLTOY_ORDER_INFO IS 'sqltoy demo order table';
COMMENT ON COLUMN SQLTOY_ORDER_INFO.ORDER_ID IS 'order id';
-- ... remaining column comments: see schema-h2.sql in the demo project
```

* Real-database form (MySQL):

```sql
DROP TABLE IF EXISTS SQLTOY_ORDER_INFO;
CREATE TABLE SQLTOY_ORDER_INFO(
    `ORDER_ID` VARCHAR(32) NOT NULL  COMMENT 'order id' ,
    `ORDER_TYPE` VARCHAR(32)   COMMENT 'order type' ,
    `PRODUCT_CODE` VARCHAR(32)   COMMENT 'product code' ,
    `UOM` VARCHAR(30)   COMMENT 'unit of measure' ,
    `PRICE` DECIMAL(24,6)   COMMENT 'price' ,
    `QUANTITY` DECIMAL(24,6)   COMMENT 'quantity' ,
    `TOTAL_AMT` DECIMAL(24,6)   COMMENT 'total amount' ,
    `STAFF_CODE` VARCHAR(32)   COMMENT 'sales person' ,
    `ORGAN_ID` VARCHAR(32)   COMMENT 'sales department' ,
    `STATUS` INT   COMMENT 'order status' ,
    `CREATE_BY` VARCHAR(32)   COMMENT 'created by' ,
    `CREATE_TIME` DATETIME   COMMENT 'create time' ,
    `UPDATE_BY` VARCHAR(32)   COMMENT 'updated by' ,
    `UPDATE_TIME` DATETIME   COMMENT 'update time' ,
    PRIMARY KEY (ORDER_ID)
)  COMMENT = 'sqltoy demo order table';

```

## 4. Configure the quickvo-maven-plugin to generate POJOs and DTOs

* Add quickvo-maven-plugin to pom.xml

```xml
<plugin>
	<groupId>com.sagframe</groupId>
	<artifactId>quickvo-maven-plugin</artifactId>
	<version>2.0.3</version>
	<configuration>
		<configFile>./src/main/resources/quickvo.xml</configFile>
		<baseDir>${project.basedir}</baseDir>
	</configuration>
	<dependencies>
		<!-- H2 driver: quickvo boots its own in-memory schema via INIT=RUNSCRIPT,
		     so reverse generation works with zero install -->
		<dependency>
			<groupId>com.h2database</groupId>
			<artifactId>h2</artifactId>
			<version>2.4.240</version>
		</dependency>
		<!-- add the driver of your real database when generating against it, e.g. mysql -->
		<dependency>
			<groupId>com.mysql</groupId>
			<artifactId>mysql-connector-j</artifactId>
			<version>${mysql.version}</version>
		</dependency>
	</dependencies>
</plugin>
```

* Create quickvo.xml under src/main/resources (identical to the demo project — the H2 self-bootstrapping form).
  For the full quickvo.xml reference see: [quickvo-maven-plugin](https://gitee.com/sagacity/maven-quickvo-plugin)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.sagframe.com/schema/quickvo https://sagframe.github.io/schema/quickvo.xsd">
	<property name="project.version" value="1.0.0" />
	<property name="project.name" value="sqltoy-helloworld" />
	<!-- default package of the project -->
	<property name="project.package" value="com.sqltoy.helloworld" />

	<!-- Points at an in-memory H2 database: INIT=RUNSCRIPT in the url creates the tables
	     from mock/h2/schema-h2.sql when the connection opens. To generate against your own
	     database: change url/driver/schema/username/password (a <property file> import of
	     application.yml with ${spring.datasource.url} references works too) -->
	<datasource name="helloworld" url="jdbc:h2:mem:quickvogen;INIT=RUNSCRIPT FROM 'src/main/resources/mock/h2/schema-h2.sql'"
		driver="org.h2.Driver" schema="PUBLIC" catalog="" username="sa" password="" />

	<!-- dist: where generated java code goes, relative to baseDir in the pom -->
	<tasks dist="src/main/java" encoding="UTF-8">
		<!-- multiple tasks are allowed to generate POJOs into different packages -->
		<task datasource="helloworld" author="zhongxuchen"	include="^SQLTOY_\w+" active="true">
			<entity package="${project.package}.entity" substr="Sqltoy"	name="#{subName}" lombok-chain="true" />
			<vo package="${project.package}.dto" lombok-chain="true" substr="Sqltoy" name="#{subName}VO" />
		</task>
	</tasks>

	<!-- type mapping: H2 TIMESTAMP columns would generate java.sql.Timestamp by default;
	     map them to LocalDateTime to stay consistent with the unified-fields handler
	     (SqlToyUnifyFieldsHandler assigns LocalDateTime values) -->
	<type-mapping>
		<sql-type native-types="TIMESTAMP" jdbc-type="TIMESTAMP" java-type="java.time.LocalDateTime" />
	</type-mapping>
</quickvo>
```

## 5. Run quickvo to generate the POJO and DTO
* In the project root run: mvn quickvo:quickvo
* `src/main/java/com/sqltoy/helloworld/dto/OrderInfoVO.java` is generated
* `src/main/java/com/sqltoy/helloworld/entity/OrderInfo.java` is generated
  containing `@Entity`, `@Id`, `@Column` annotations that map the object to the table

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_order_info",comment="sqltoy demo order table",pk_constraint="PRIMARY")
public class OrderInfo implements Serializable {
	
	/**
	 * 
	 */
	private static final long serialVersionUID = 7200696852961513069L;
/*---begin-auto-generate-don't-update-this-area--*/	

	/**
	 * Order id
	 */
	@Id(strategy="generator",generator="org.sagacity.sqltoy.plugins.id.impl.NanoTimeIdGenerator")
	@Column(name="ORDER_ID",comment="order id",length=32L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String orderId;

	/**
	 * Order type
	 */
	@Column(name="ORDER_TYPE",comment="order type",length=32L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=true)
	private String orderType;

	// ... remaining fields omitted for brevity (price, quantity, totalAmt, staffCode, organId,
	//     status and the audit fields; createTime/updateTime are generated as LocalDateTime
	//     thanks to the type-mapping above)
/*---end-auto-generate-don't-update-this-area--*/
}
```

> The area between `begin-auto-generate` and `end-auto-generate` is regenerated by quickvo — do not edit it by hand (regeneration overwrites it). Put extended properties/methods outside the markers: that is exactly how the demo project's OrderInfoVO adds its `@Translate` properties.

## 6. Create a service and a unit test

* 1. The OrderInfoService interface

```java
package com.sqltoy.helloworld.service;

import org.sagacity.sqltoy.model.Page;
import com.sqltoy.helloworld.dto.OrderInfoVO;

public interface OrderInfoService {
	/**
	 * Create an order
	 * 
	 * @param orderInfoVO
	 */
	public void createOrderInfo(OrderInfoVO orderInfoVO);

	/**
	 * Paginated order search
	 * 
	 * @param pageModel
	 * @param queryMap
	 * @return
	 */
	public Page<OrderInfoVO> searchOrderInfo(Page pageModel, Map queryMap);
}
```

* 2. The OrderInfoServiceImpl implementation

```java
/**
 * Order service implementation
 * 
 * @author zhongxuchen
 * @date 2025/2/5
 */
@Service("orderInfoService")
public class OrderInfoServiceImpl implements OrderInfoService {
	// inject the built-in LightDao
	@Autowired
	LightDao lightDao;

	// all single-table operations are done in an object-oriented way, similar to JPA
	@Override
	@Transactional
	public void createOrderInfo(OrderInfoVO orderInfoVO) {
		// use the built-in dto<-->pojo mapping to create the entity
		OrderInfo orderInfoEntity = lightDao.convertType(orderInfoVO, OrderInfo.class);
		// save
		lightDao.save(orderInfoEntity);
	}

	// complex queries are defined in sql.xml
	@Override
	public Page<OrderInfoVO> searchOrderInfo(Page pageModel, Map queryMap) {
		String sql = """
				select * from SQLTOY_ORDER_INFO t
				where 1=1
				#[and t.status in (:statusAry)]
				#[and t.create_time>=:beginTime]
				#[and t.create_time<=:endTime]
				""";
		return lightDao.findPage(pageModel, sql, queryMap, OrderInfoVO.class);
	}

}
```

* 3. The unit test OrderInfoServiceTest (identical to the demo project, with assertions)

```java
@SpringBootTest
public class OrderInfoServiceTest {
	@Autowired
	OrderInfoService orderInfoService;

	@Autowired
	LightDao lightDao;

	@Test
	public void testCreateOrderInfo() {
		String productCode = "P-DEMO-" + System.nanoTime();
		OrderInfoVO orderInfoVO = new OrderInfoVO();
		orderInfoVO.setOrderType("PO");
		orderInfoVO.setOrganId("100007");
		orderInfoVO.setProductCode(productCode);
		orderInfoVO.setPrice(BigDecimal.valueOf(100));
		orderInfoVO.setQuantity(BigDecimal.valueOf(100));
		orderInfoVO.setTotalAmt(BigDecimal.valueOf(10000));
		orderInfoVO.setUom("KG");
		orderInfoVO.setStaffCode("S0001");
		orderInfoVO.setStatus(1);
		// with SqlToyUnifyFieldsHandler configured, audit fields are filled automatically:
		// orderInfoVO.setCreateBy("S0001");
		// orderInfoVO.setCreateTime(LocalDateTime.now());
		orderInfoService.createOrderInfo(orderInfoVO);

		// query it back: the primary key comes from NanoTimeIdGenerator (26 digits),
		// the audit fields from the unified-fields handler
		List<OrderInfo> saved = lightDao.findEntity(OrderInfo.class,
				EntityQuery.create().where("productCode=:pc").values(MapKit.map("pc", productCode)));
		assertEquals(1, saved.size());
		assertEquals(26, saved.get(0).getOrderId().length());
		assertEquals("system-auto", saved.get(0).getCreateBy());
	}

	@Test
	public void testUpdateOrderInfo() {
		// self-contained (no dependency on pre-existing rows): save an order first
		OrderInfo order = new OrderInfo().setOrderType("PO").setProductCode("P-UPD-" + System.nanoTime())
				.setUom("KG").setPrice(BigDecimal.valueOf(100)).setQuantity(BigDecimal.valueOf(100))
				.setTotalAmt(BigDecimal.valueOf(10000)).setStaffCode("S0001").setOrganId("100007").setStatus(1);
		lightDao.save(order);

		// elastic update: null fields on the entity are skipped, only assigned fields are written
		OrderInfo update = new OrderInfo().setOrderId(order.getOrderId());
		update.setQuantity(BigDecimal.valueOf(120));
		lightDao.update(update);

		OrderInfo reloaded = lightDao.load(new OrderInfo().setOrderId(order.getOrderId()));
		assertEquals(0, reloaded.getQuantity().compareTo(BigDecimal.valueOf(120)));
		// price was left null on the update entity — the elastic update does not touch it
		assertEquals(0, reloaded.getPrice().compareTo(BigDecimal.valueOf(100)));
	}

	@Test
	public void testSearchOrderInfo() {
		// dynamic-condition pagination: statusAry/beginTime apply, a null endTime is ignored
		Page<OrderInfoVO> pageModel = orderInfoService.searchOrderInfo(new Page(10, 1),
				MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
						LocalDateTime.parse("2024-10-17T00:00:01"), null));
		System.out.println(JSON.toJSONString(pageModel.getRows()));
		assertTrue(pageModel.getRecordCount() >= 3); // the seed data holds 3 status=1 orders
	}

}
```

## 7. Run and verify

```bash
git clone https://gitee.com/sagacity/sqltoy-helloworld.git
cd sqltoy-helloworld
mvn test
```

```text
Tests run: 7, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS
```

Besides the CRUD/pagination tests above, the demo project ships `TranslateTest` covering the four cache-translate usages (the xml `<translate>` tag, `QueryExecutor.translates`, `EntityQuery.translates` and the `@Translate` annotation on VO properties) — see [Cache Translate in Action](translates.md) and [Common-Field Auto-Fill](helloworld_improve.md).
