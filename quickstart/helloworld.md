# 学习sqltoy-orm的基本原则
* 不要带入mybatis(plus)等开源项目的使用惯性思维
* 用显式逻辑和直截了当的思维来看待和学习sqltoy,orm是常规技术，简洁、实用、可维护是重点
* 看到一些跟以往项目模式有些许差异的地方，不要急于否定

# 快速搭建sqltoy项目的步骤

## 1、创建一个springboot项目，并配置好数据源


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
## 3、pom中加入quickvo-maven-plugin通过数据库表生成pojo/dto
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
## 4、创建表:sqltoy_order_info
## 5、执行quickvo，生产pojo


## 6、创建一个service和单元测试类