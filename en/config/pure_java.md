# Pure Java Usage

## sqltoy is recommended to run within the Spring or Solon framework; a fully standalone framework for independent (non-Spring) usage has not been completely built, and you can optimize and extend it on your own with AI. An example is provided below

* Step 1: Add the pom dependency

```xml
<dependency>
	<groupId>com.sagframe</groupId>
	<artifactId>sagacity-sqltoy</artifactId>
   <version>6.0.1</version>
</dependency>
```

* Java code: register the DataSource, build the SqlToyContext and lightDao

```java
public void doDB() {
	try {
		// Build the sqlToyContext
		SqlToyContext sqlToyContext = new SqlToyContext();
		sqlToyContext.setSqlResourcesDir("classpath:sqltoy/demo.sql.xml");
		sqlToyContext.initialize();
		Map<String, String> map = new HashMap<>();
		map.put(DruidDataSourceFactory.PROP_URL, "jdbc:mysql://192.168.56.101:3306/java20");
		// Set the driver
		map.put(DruidDataSourceFactory.PROP_DRIVERCLASSNAME, "com.mysql.jdbc.Driver");
		// Set the username
		map.put(DruidDataSourceFactory.PROP_USERNAME, "root");
		// Set the password
		map.put(DruidDataSourceFactory.PROP_PASSWORD, "123456");
		// Create the data source
		DataSource dataSource = DruidDataSourceFactory.createDataSource(map);
		sqlToyContext.setDefaultDataSource(dataSource);
		// The framework provides the DefaultLightDaoImpl implementation by default
		LightDao lightDao = new DefaultLightDaoImpl(sqlToyContext);
		// Non-transactional
		// lightDao.find("select * from staff_info where status=:status",
		// MapKit.map("status", "1"), StaffInfo.class);
		// All of this is illustrative; write it according to your actual logic
		Object result = DBTransUtils.doTrans(lightDao.getDataSource(), () -> {
			// Here you can
			lightDao.updateByQuery(StaffInfo.class,
					EntityUpdate.create().set("sexType", "F").where("staffId=?").values("S0001"));
			return lightDao.find("select * from staff_info where status=:status", MapKit.map("status", "1"),
					StaffInfo.class);
		});
	} catch (Exception e) {

	}
}
```
