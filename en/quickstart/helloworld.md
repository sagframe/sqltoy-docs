# Principles for learning sqltoy-orm
* Do not carry over habits from MyBatis(-Plus) or similar frameworks
* Think in explicit logic and straightforward patterns
* When you see something slightly different from what you know, don't rush to reject it

# Steps to build a sqltoy project

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
<!-- Spring's built-in database connection pool -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
    <version>4.1.0</version>
</dependency>

```
* Configure application.yml

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
    sqltoy:
       # Optional: where the sql.xml files live (scanned recursively; multiple paths example: classpath:com/sqltoy/helloworld,classpath:com/sqltoy/system
       sqlResourcesDir: classpath:com/sqltoy/helloworld
       # Defaults to false; in debug mode executed SQL is printed and sql files are watched and reloaded on change
       debug: true
  
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
	</resource>
</resources>
```

## 2. Add sqltoy-orm-spring-starter in pom.xml
* Spring Boot

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-spring-starter</artifactId>
	<!-- For JDK 8 use 5.6.95.jre8 (final) -->
	<version>6.0.2</version>
</dependency>
```
* Solon

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-solon-plugin</artifactId>
	<!-- For JDK 8 use 5.6.95.jre8 (final) -->
	<version>6.0.2</version>
</dependency>
```
## 3. Create the table: sqltoy_order_info

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
	<version>2.0.0</version>
	<configuration>
		<configFile>./src/main/resources/quickvo.xml</configFile>
		<baseDir>${project.basedir}</baseDir>
	</configuration>
	<dependencies>
		<dependency>
			<groupId>com.mysql</groupId>
			<artifactId>mysql-connector-j</artifactId>
			<version>${mysql.version}</version>
		</dependency>
	</dependencies>
</plugin>
```

* Create quickvo.xml under src/main/resources
  For the full quickvo.xml reference see: [quickvo-maven-plugin](https://gitee.com/sagacity/maven-quickvo-plugin)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.sagframe.com/schema/quickvo https://sagframe.github.io/schema/quickvo.xsd">
	<!-- db config file -->
	<property file="src/main/resources/application.yml" />
	<property name="project.version" value="1.0.0" />
	<property name="project.name" value="sqltoy-helloworld" />
	<!-- default package of the project -->
	<property name="project.package" value="com.sqltoy.helloworld" />
	<!-- database definition; literal values also work here -->
	<datasource name="helloworld" url="${spring.datasource.url}"
		driver="com.mysql.cj.jdbc.Driver" schema="${spring.datasource.username}"
		username="${spring.datasource.username}" password="${spring.datasource.password}" />
	<!-- dist: where generated java code goes, relative to baseDir in the pom -->
	<tasks dist="src/main/java" encoding="UTF-8">
		<!-- multiple tasks are allowed to generate POJOs into different packages -->
		<task datasource="helloworld" author="zhongxuchen"	include="^SQLTOY_\w+" active="true">
			<entity package="${project.package}.entity" substr="Sqltoy"	name="#{subName}" lombok-chain="true" />
			<vo package="${project.package}.dto" lombok-chain="true" substr="Sqltoy" name="#{subName}VO" />
		</task>
	</tasks>
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

	// ... remaining fields omitted for brevity (price, quantity, totalAmt, staffCode, organId, status, audit fields)
/*---end-auto-generate-don't-update-this-area--*/
}
```

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

* 3. The unit test OrderInfoServiceTest

```java
@SpringBootTest
public class OrderInfoServiceTest {
	@Autowired
	OrderInfoService orderInfoService;

	@Test
	public void testCreateOrderInfo() {
		OrderInfoVO orderInfoVO = new OrderInfoVO();
		orderInfoVO.setOrderType("PO");
		orderInfoVO.setOrganId("T001");
		orderInfoVO.setProductCode("P0001");
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
	}

	@Test
	public void testSearchOrderInfo() {
		Page pageModel = orderInfoService.searchOrderInfo(new Page(10, 1),
				MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
						LocalDateTime.parse("2024-10-17T00:00:01"), null));
		System.err.println(JSON.toJSONString(pageModel));
	}

}
```
