# 传统spring项目配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd"
	default-autowire="byName" default-lazy-init="true">
	<!-- 配置辅助sql处理工具用于sql查询条件的处理 -->
	<bean id="sqlToyContext" name="sqlToyContext" class="org.sagacity.sqltoy.SqlToyContext" init-method="initialize"
		destroy-method="destroy">
		<!-- 指定sql.xml 文件的路径实现目录的递归查找,可以用逗号分隔配置多个路径，非必须属性 -->
		<property name="sqlResourcesDir" value="classpath:com/sinochem" />
		<!-- 针对不同数据库函数进行转换,非必须属性 -->
		<property name="functionConverts" value="default" />
		<!-- 统一公共字段赋值,原理:只做补漏，开发者已经设置了值不会被覆盖,当没有被赋值时才会起作用 -->
		<property name="unifyFieldsHandler">
			<bean class="com.sinochem.ubmp.sqltoy.SqltoyUnifyFieldsHandler" />
		</property>
		<!-- 缓存翻译管理器,非必须属性(仅当不使用缓存翻译) -->
		<property name="translateConfig" value="classpath:sqltoy-translate.xml" />
		<!-- 默认值为:false -->
		<property name="debug" value="${sqltoy.debug}" />
		<!-- 默认值为:200,提供sqltoy批量更新的batch量 -->
		<property name="batchSize" value="${sqltoy.batchSize}" />
		<!-- 默认值为:100000,设置分页查询最大的提取数据记录量,防止恶意提取数据造成系统内存压力以及保障数据安全 -->
		<property name="pageFetchSizeLimit" value="50000" />
		<!-- 默认dataSource -->
		<property name="defaultDataSource" ref="dataSource" />
		<!-- sql执行时长超过多少毫秒则打印该sql -->
		<property name="printSqlTimeoutMillis" value="2000" />
		<!-- 应用启动后多久再进行检测 -->
		<property name="delayCheckSeconds" value="300" />
		<property name="breakWhenSqlRepeat" value="false"/>
		<property name="overPageToFirst" value="true"/>
		<!-- 关键2个配置: appContext 和 connectionFactory -->
		<property name="appContext">
			<bean class="org.sagacity.sqltoy.integration.impl.SpringAppContext"/>
		</property>
		<property name="connectionFactory">
			<bean class="org.sagacity.sqltoy.integration.impl.SpringConnectionFactory"/>
		</property>
	</bean>
	
	<!-- 定义lazyDao和lightDao,可以根据实际使用选择性定义  -->
	<bean id="sqlToyLazyDao" name="sqlToyLazyDao"
		class="org.sagacity.sqltoy.dao.impl.SqlToyLazyDaoImpl" />
	<bean id="lightDao" name="lightDao"
		class="org.sagacity.sqltoy.dao.impl.LightDaoImpl" />
	<bean id="sqlToyCRUDService" name="sqlToyCRUDService"
		class="org.sagacity.sqltoy.service.impl.SqlToyCRUDServiceImpl" />
</beans>
```
