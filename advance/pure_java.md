# 纯java项目如何使用

## sqltoy推荐在spring或solon 框架下运行，并未完全构建独立使用的框架体系，可结合AI自行优化扩展，下面提供给一个范例

* 步骤1:引入pom

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy</artifactId>
   <version>5.6.75</version>
</dependency>
```

* java代码，注册DataSource、构建SqlToyContext、lightDao

```java
public void doDB() {
	try {
		//构建sqlToyContext
		SqlToyContext sqlToyContext = new SqlToyContext();
		sqlToyContext.setSqlResourcesDir("classpath:sqltoy/demo.sql.xml");
		sqlToyContext.initialize();
		Map<String, String> map = new HashMap<>();
		map.put(DruidDataSourceFactory.PROP_URL, "jdbc:mysql://192.168.56.101:3306/java20");
		// 设置驱动Driver
		map.put(DruidDataSourceFactory.PROP_DRIVERCLASSNAME, "com.mysql.jdbc.Driver");
		// 设置用户名
		map.put(DruidDataSourceFactory.PROP_USERNAME, "root");
		// 设置密码
		map.put(DruidDataSourceFactory.PROP_PASSWORD, "123456");
		// 创建数据源
		DataSource dataSource = DruidDataSourceFactory.createDataSource(map);
		sqlToyContext.setDefaultDataSource(dataSource);
		// 框架默认提供了DefaultLightDaoImpl实现
		LightDao lightDao = new DefaultLightDaoImpl(sqlToyContext);
		// 非事务
		// lightDao.find("select * from staff_info where status=:status",
		// MapKit.map("status", "1"), StaffInfo.class);
		// 这里都是示意，请按实际逻辑编写
		Object result = DBTransUtils.doTrans(lightDao.getDataSource(), () -> {
			// 这里可以
			lightDao.updateByQuery(StaffInfo.class,
					EntityUpdate.create().set("sexType", "F").where("staffId=?").values("S0001"));
			return lightDao.find("select * from staff_info where status=:status", MapKit.map("status", "1"),
					StaffInfo.class);
		});
	} catch (Exception e) {

	}
}
```
