# Traditional Spring Setup

* Add the sqltoy dependency; it is still recommended to include sagacity-sqltoy-spring-starter

```xml
<!-- springboot  -->
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy-spring-starter</artifactId>
	<!-- For JDK8, use 5.6.95.jre8 (final version) -->
	<version>6.0.1</version>
</dependency>
```

* Define the sqltoy context and lightDao as beans based on Spring XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans.xsd"
	default-autowire="byName" default-lazy-init="true">
	<!-- Define the sqltoy context -->
	<bean id="sqlToyContext" name="sqlToyContext" class="org.sagacity.sqltoy.SqlToyContext" init-method="initialize"
		destroy-method="destroy">
		<!-- Path to the sql.xml files; directories are searched recursively, and multiple paths can be separated by commas; optional property -->
		<property name="sqlResourcesDir" value="classpath:com/company/project" />
		<!-- Converts functions across different databases; optional property -->
		<property name="functionConverts" value="default" />
		<!-- Unified field assignment; principle: it only fills in missing values — values already set by developers are never overwritten; it takes effect only when no value has been assigned -->
		<property name="unifyFieldsHandler">
			<!-- Illustrative example here -->
			<bean class="com.company.framework.sqltoy.SqltoyUnifyFieldsHandler" />
		</property>
		<!-- Cache translate manager, optional property (not needed only when cache translation is not used) -->
		<property name="translateConfig" value="classpath:sqltoy-translate.xml" />
		<!-- Default value: false -->
		<property name="debug" value="${sqltoy.debug}" />
		<!-- Default value: 200; the batch size used by sqltoy batch updates -->
		<property name="batchSize" value="${sqltoy.batchSize}" />
		<!-- Default value: 100000; sets the maximum number of records a paginated query may fetch, preventing malicious data extraction from putting pressure on system memory and safeguarding data security -->
		<property name="pageFetchSizeLimit" value="50000" />
		<!-- Default dataSource -->
		<property name="defaultDataSource" ref="dataSource" />
		<!-- Print the SQL if its execution time exceeds this many milliseconds -->
		<property name="printSqlTimeoutMillis" value="2000" />
		<!-- How long after application startup the check is performed -->
		<property name="delayCheckSeconds" value="300" />
		<property name="breakWhenSqlRepeat" value="false"/>
		<property name="overPageToFirst" value="true"/>
		<!-- The two key configurations: appContext and connectionFactory -->
		<property name="appContext">
			<bean class="org.sagacity.sqltoy.integration.impl.SpringAppContext"/>
		</property>
		<property name="connectionFactory">
			<bean class="org.sagacity.sqltoy.integration.impl.SpringConnectionFactory"/>
		</property>
	</bean>
	
	<!-- Define lightDao: it is recommended to use LightDao uniformly as the entry point for object operations -->
	<bean id="lightDao" name="lightDao"
		class="org.sagacity.sqltoy.dao.impl.LightDaoImpl" />
	<bean id="sqlToyCRUDService" name="sqlToyCRUDService"
		class="org.sagacity.sqltoy.service.impl.SqlToyCRUDServiceImpl" />
</beans>
```

* Concrete usage

```java
@Autowired
private LightDao lightDao; 

public void createOrgan(OrganInfo organInfo){
	lightDao.save(organInfo);
}
```
