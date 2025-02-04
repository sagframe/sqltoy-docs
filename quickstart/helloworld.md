# 学习sqltoy-orm的基本原则
* 不要带入mybatis(plus)等开源项目的使用惯性思维
* 用显式逻辑和直截了当的思维来看待和学习sqltoy,orm是常规技术，简洁、实用、可维护是重点
* 看到一些跟以往项目模式有些许差异的地方，不要急于否定

# 快速搭建sqltoy项目的步骤

## 1、创建一个springboot项目，并配置好数据源
* 参见:[sqltoy演示项目sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld)

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

## 2、引入sqltoy的jar，在pom.xml中引入sqltoy-orm-spring-starter
* pom.xml配置

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-spring-starter</artifactId>
	<!-- 推荐使用最新正式版本 -->
	<version>5.6.38</version>
</dependency>
```

## 3、创建表:sqltoy_order_info

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
## 3、通过sqltoy的maven插件quickvo生成POJO、DTO

* pom.xml中加入quickvo-maven-plugin通过数据库表生成pojo/dto
```xml
<plugin>
	<groupId>com.sagframe</groupId>
	<artifactId>quickvo-maven-plugin</artifactId>
	<version>1.0.5</version>
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

* 在src/main/resources下面创建quickvo.xml

## 5、执行quickvo，生产pojo


## 6、创建一个service和单元测试类