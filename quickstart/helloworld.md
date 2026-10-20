# 学习sqltoy-orm的基本原则
* 不要带入mybatis(plus)等开源项目的使用惯性思维
* 用显式逻辑和直截了当的思维来看待和学习sqltoy-orm
* 看到一些跟以往项目模式有些许差异的地方，不要急于否定

# 快速搭建sqltoy项目的步骤

> 本文与演示项目 [sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld) 完全同步：该项目默认运行在 **H2 内存库**上（建表与种子数据自动加载），clone 后 `mvn test` 零安装即可运行（7 个演示用例全绿）。

## 1、创建一个springboot项目，并配置好数据源
* 参见:[sqltoy演示项目sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld)

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
* 数据库连接池使用hikari(可以根据自己情况自行选择)

```xml
<!-- spring自带的数据库连接池(版本由 spring-boot-starter-parent 管理) -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jdbc</artifactId>
</dependency>
<!-- 零安装内存库:演示项目默认跑在 H2 上 -->
<dependency>
    <groupId>com.h2database</groupId>
    <artifactId>h2</artifactId>
</dependency>
```

* 配置application.yml(H2 零安装形态,与演示项目一致)

```yml
spring:
    # 零安装:默认使用 H2 内存库,建表与种子数据由 spring.sql.init 自动加载(mock/h2/)
    datasource:
       name: dataSource
       type: com.zaxxer.hikari.HikariDataSource
       driver-class-name: org.h2.Driver
       username: sa
       password: ""
       isAutoCommit: false
       # 随机库名:每个 Spring 上下文独立,测试互不干扰
       url: jdbc:h2:mem:helloworld-${random.uuid};DB_CLOSE_DELAY=-1
    # 演示表结构 + 种子数据(H2 版 DDL 见第 3 步)
    sql:
       init:
         mode: always
         schema-locations: classpath:mock/h2/schema-h2.sql
         data-locations: classpath:mock/h2/data-h2.sql
    #将sqltoy 放于开始位置，避免很多开发者忽视了spring.sqltoy 开头，变成了sqltoy开头导致无法加载
    sqltoy:
       #非必选项，设置sql.xml文件存放路径(会自动向下扫描,多路径范例:classpath:com/sqltoy/helloworld,classpath:com/sqltoy/system
       sqlResourcesDir: classpath:com/sqltoy/helloworld
       # 默认为false，debug模式将打印执行sql,并自动检测sql文件更新并重新加载
       debug: true
```

* 切换 MySQL 等真实库:替换 datasource 段并把 `sql.init.mode` 改为 `never`(建表参照第 3 步的 MySQL DDL)

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

> **工程实践：推荐把 `*.sql.xml` 放在代码目录（而非 resources）**，与 VO 同模块存放。好处：① 开发者在自己模块下就能完成 sql 编写与维护，减少目录切换；② 便于整个模块连同 sql 一起剥离复用，向产品化模块演进。这需要在 pom.xml 中把 java 目录下的 xml 纳入资源打包：

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
			<!-- H2 建表/种子数据脚本 -->
			<include>**/*.sql</include>
		</includes>
	</resource>
</resources>
```

## 2、在pom.xml中引入sqltoy-orm-spring-starter
* springboot场景

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-spring-starter</artifactId>
	<!-- JDK8 请使用 5.6.96.jre8（jre8 最终版本，同样支持 quickvo-maven-plugin 插件） -->
	<version>6.0.8</version>
</dependency>
<!-- 使用缓存翻译(见《缓存翻译使用》)需要缓存实现,sqltoy 默认支持 ehcache(runtime 作用域,打包进 boot jar) -->
<dependency>
	<groupId>org.ehcache</groupId>
	<artifactId>ehcache</artifactId>
	<scope>runtime</scope>
</dependency>
```
* solon场景

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-solon-plugin</artifactId>
	<!-- JDK8 请使用 5.6.96.jre8（jre8 最终版本，同样支持 quickvo-maven-plugin 插件） -->
	<version>6.0.8</version>
</dependency>
```

## 3、创建表:sqltoy_order_info

* H2 零安装形态:DDL 放在 `src/main/resources/mock/h2/schema-h2.sql`,由 `spring.sql.init` 启动时自动执行(演示项目还包含缓存翻译用的机构表/字典表及种子数据 `data-h2.sql`):

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
COMMENT ON TABLE SQLTOY_ORDER_INFO IS 'sqltoy订单信息演示表';
COMMENT ON COLUMN SQLTOY_ORDER_INFO.ORDER_ID IS '订单编号';
-- ... 其余列注释见演示项目 schema-h2.sql
```

* MySQL 等真实库形态:

```sql
DROP TABLE IF EXISTS SQLTOY_ORDER_INFO;
CREATE TABLE SQLTOY_ORDER_INFO(
    `ORDER_ID` VARCHAR(32) NOT NULL  COMMENT '订单编号' ,
    `ORDER_TYPE` VARCHAR(32)   COMMENT '订单类别' ,
    `PRODUCT_CODE` VARCHAR(32)   COMMENT '商品代码' ,
    `UOM` VARCHAR(30)   COMMENT '计量单位' ,
    `PRICE` DECIMAL(24,6)   COMMENT '价格' ,
    `QUANTITY` DECIMAL(24,6)   COMMENT '数量' ,
    `TOTAL_AMT` DECIMAL(24,6)   COMMENT '订单总金额' ,
    `STAFF_CODE` VARCHAR(32)   COMMENT '销售员' ,
    `ORGAN_ID` VARCHAR(32)   COMMENT '销售部门' ,
    `STATUS` INT   COMMENT '订单状态' ,
    `CREATE_BY` VARCHAR(32)   COMMENT '创建人' ,
    `CREATE_TIME` DATETIME   COMMENT '创建时间' ,
    `UPDATE_BY` VARCHAR(32)   COMMENT '更新人' ,
    `UPDATE_TIME` DATETIME   COMMENT '更新时间' ,
    PRIMARY KEY (ORDER_ID)
)  COMMENT = 'sqltoy订单信息演示表';

```

## 4、配置sqltoy生成pojo、dto的maven插件quickvo-maven-plugin

* pom.xml中加入quickvo-maven-plugin

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
		<!-- H2 驱动:quickvo 经 INIT=RUNSCRIPT 自举内存表结构,零安装即可逆向生成 -->
		<dependency>
			<groupId>com.h2database</groupId>
			<artifactId>h2</artifactId>
			<version>2.4.240</version>
		</dependency>
		<!-- 对着真实库生成时补对应驱动,如 mysql -->
		<dependency>
			<groupId>com.mysql</groupId>
			<artifactId>mysql-connector-j</artifactId>
			<version>${mysql.version}</version>
		</dependency>
	</dependencies>
</plugin>
```

* 在src/main/resources下面创建quickvo.xml(与演示项目一致,H2 自举形态)
  有关quickvo.xml的配置，详细请参见:[quickvo-maven-plugin](https://gitee.com/sagacity/maven-quickvo-plugin)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagacity.com/schema/quickvo"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.sagacity.com/schema/quickvo https://sagframe.github.io/schema/quickvo.xsd">
	<property name="project.version" value="1.0.0" />
	<property name="project.name" value="sqltoy-helloworld" />
	<!-- 定义项目的默认包路径 -->
	<property name="project.package" value="com.sqltoy.helloworld" />

	<!-- 默认指向内存 H2:url 中的 INIT=RUNSCRIPT 在连接建立时用 mock/h2/schema-h2.sql 建表。
	     对着自己的真实库生成时:改 url/driver/schema/username/password(也可用 <property file>
	     引入 application.yml 后以 ${spring.datasource.url} 引用) -->
	<datasource name="helloworld" url="jdbc:h2:mem:quickvogen;INIT=RUNSCRIPT FROM 'src/main/resources/mock/h2/schema-h2.sql'"
		driver="org.h2.Driver" schema="PUBLIC" catalog="" username="sa" password="" />

	<!-- dist 定义生成的java代码存放路径,相对于pom中baseDir -->
	<tasks dist="src/main/java" encoding="UTF-8">
		<!-- 可以设置多个任务便于将pojo生成到不同包路径下 -->
		<task datasource="helloworld" author="zhongxuchen"	include="^SQLTOY_\w+" active="true">
			<entity package="${project.package}.entity" substr="Sqltoy"	name="#{subName}" lombok-chain="true" />
			<vo package="${project.package}.dto" lombok-chain="true" substr="Sqltoy" name="#{subName}VO" />
		</task>
	</tasks>

	<!-- 类型映射:H2 的 TIMESTAMP 默认生成 java.sql.Timestamp,映射为 LocalDateTime
	     与公共字段赋值处理器(SqlToyUnifyFieldsHandler 赋 LocalDateTime 值)保持一致 -->
	<type-mapping>
		<sql-type native-types="TIMESTAMP" jdbc-type="TIMESTAMP" java-type="java.time.LocalDateTime" />
	</type-mapping>
</quickvo>
```

## 5、执行quickvo，生成pojo和dto
* 在项目根路径下执行:mvn quickvo:quickvo
* 在src/main/java/目录下com.sqltoy.helloworld.dto包下面会生成OrderInfoVO.java
* 在src/main/java/目录下com.sqltoy.helloworld.entity包下面会生成OrderInfo.java  
  会包含:@Entity、@Id、@Column 等描述对象跟数据库表关系的注解

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_order_info",comment="sqltoy订单信息演示表",pk_constraint="PRIMARY")
public class OrderInfo implements Serializable {
	
	/**
	 * 
	 */
	private static final long serialVersionUID = 7200696852961513069L;
/*---begin-auto-generate-don't-update-this-area--*/	

	/**
	 * 订单编号
	 */
	@Id(strategy="generator",generator="org.sagacity.sqltoy.plugins.id.impl.NanoTimeIdGenerator")
	@Column(name="ORDER_ID",comment="订单编号",length=32L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String orderId;

	/**
	 * 订单类别
	 */
	@Column(name="ORDER_TYPE",comment="订单类别",length=32L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=true)
	private String orderType;

	// ... 其余字段省略(price/quantity/totalAmt/staffCode/organId/status 及审计字段,
	//     createTime/updateTime 经 type-mapping 生成为 LocalDateTime)
/*---end-auto-generate-don't-update-this-area--*/
}
```

> `begin-auto-generate` 与 `end-auto-generate` 之间的内容由 quickvo 自动生成,重新生成会覆盖;扩展属性/方法(如 VO 上的 `@Translate` 翻译属性)请写在区间之外——演示项目的 OrderInfoVO 正是这样扩展的。

## 6、创建一个service和单元测试类

* 1、创建OrderInfoService接口

```java
package com.sqltoy.helloworld.service;

import org.sagacity.sqltoy.model.Page;
import com.sqltoy.helloworld.dto.OrderInfoVO;

public interface OrderInfoService {
	/**
	 * 创建订单
	 * 
	 * @param orderInfoVO
	 */
	public void createOrderInfo(OrderInfoVO orderInfoVO);

	/**
	 * 分页查询订单信息
	 * 
	 * @param pageModel
	 * @param queryMap
	 * @return
	 */
	public Page<OrderInfoVO> searchOrderInfo(Page pageModel, Map queryMap);
}
```

* 2、编写OrderInfoService实现类OrderInfoServiceImpl

```java
/**
 * 订单服务逻辑实现
 * 
 * @author zhongxuchen
 * @date 2025/2/5
 */
@Service("orderInfoService")
public class OrderInfoServiceImpl implements OrderInfoService {
	// 注入sqltoy框架自带的LightDao
	@Autowired
	LightDao lightDao;

	// 所有单表操作对象化完成，类似jpa
	@Override
	@Transactional
	public void createOrderInfo(OrderInfoVO orderInfoVO) {
		// 调用框架自带的dto<-->pojo 映射方法创建Entity实例
		OrderInfo orderInfoEntity = lightDao.convertType(orderInfoVO, OrderInfo.class);
		// 调用save完成保存
		lightDao.save(orderInfoEntity);
	}

	// 复杂查询通过sql.xml 定义具体sql内容
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

* 3、编写单元测试类OrderInfoServiceTest(与演示项目一致,含断言)

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
		// 定义SqlToyUnifyFieldsHandler公共字段赋值后，就无需设置
		// orderInfoVO.setCreateBy("S0001");
		// orderInfoVO.setCreateTime(LocalDateTime.now());
		orderInfoService.createOrderInfo(orderInfoVO);

		// 查回验证:主键由 NanoTimeIdGenerator 生成(26位),审计字段自动填充
		List<OrderInfo> saved = lightDao.findEntity(OrderInfo.class,
				EntityQuery.create().where("productCode=:pc").values(MapKit.map("pc", productCode)));
		assertEquals(1, saved.size());
		assertEquals(26, saved.get(0).getOrderId().length());
		assertEquals("system-auto", saved.get(0).getCreateBy());
	}

	@Test
	public void testUpdateOrderInfo() {
		// 自建自更(不依赖库中既有数据):先保存一张订单
		OrderInfo order = new OrderInfo().setOrderType("PO").setProductCode("P-UPD-" + System.nanoTime())
				.setUom("KG").setPrice(BigDecimal.valueOf(100)).setQuantity(BigDecimal.valueOf(100))
				.setTotalAmt(BigDecimal.valueOf(10000)).setStaffCode("S0001").setOrganId("100007").setStatus(1);
		lightDao.save(order);

		// 弹性 update:实体上为 null 的字段被跳过,只更新已赋值字段
		OrderInfo update = new OrderInfo().setOrderId(order.getOrderId());
		update.setQuantity(BigDecimal.valueOf(120));
		lightDao.update(update);

		OrderInfo reloaded = lightDao.load(new OrderInfo().setOrderId(order.getOrderId()));
		assertEquals(0, reloaded.getQuantity().compareTo(BigDecimal.valueOf(120)));
		// price 未赋值(null)——弹性更新不碰它,原值保留
		assertEquals(0, reloaded.getPrice().compareTo(BigDecimal.valueOf(100)));
	}

	@Test
	public void testSearchOrderInfo() {
		// xml 式动态条件分页:statusAry/beginTime 生效,endTime 为 null 自动忽略
		Page<OrderInfoVO> pageModel = orderInfoService.searchOrderInfo(new Page(10, 1),
				MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
						LocalDateTime.parse("2024-10-17T00:00:01"), null));
		System.out.println(JSON.toJSONString(pageModel.getRows()));
		assertTrue(pageModel.getRecordCount() >= 3); // 种子数据含 3 张 status=1 的订单
	}

}
```

## 7、运行验证

```bash
git clone https://gitee.com/sagacity/sqltoy-helloworld.git
cd sqltoy-helloworld
mvn test
```

```text
Tests run: 7, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS
```

除本文的 CRUD/分页用例外,演示项目还包含缓存翻译四种用法的 `TranslateTest`(xml `<translate>` 标签、`QueryExecutor.translates`、`EntityQuery.translates`、VO 属性 `@Translate` 注解),详见[缓存翻译使用](translates.md)与[公共字段赋值](helloworld_improve.md)。
