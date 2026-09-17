# POJO生成表结构DDL
* sqltoy支持项目启动时根据POJO实体生成ddl脚本并在数据库中执行

```yml
spring:
	sqltoy:
		#指定扫描POJO包路径，可以指定一个顶层包会自动递归扫描，也可以指定比较底层的包
		packagesToScan:
			- com.example.modules.commons.entity
			- com.example.modules.system.entity
		autoDDL: true
		#dialectDDLGenerator: com.xxx 自定义扩展实现类
```

* 通过代码生成整个项目POJO对应的数据库脚本

```java
@Test
public void testCreateSqlFile() {
	// 指定POJO所在的包路径
	String[] scanPackages = new String[] { "org.sagacity.sqltoy.demo.domain" };
	try {
		/**
		 * @param scanPackages
		 * @param saveFile            脚本存放文件
		 * @param upperOrLower        upper|lower 脚本表名、字段名是否统一转大写或小写
		 * @param dbType              数据库类型，用DBType.xx 提供
		 * @param schema              针对sqlserver需要提供(其他数据库可为null)，项目启动时会根据connection获取schema
		 * @param dialectDDLGenerator 自己指定ddl创建器,如果是：mysql、oracle、pg、sqlserver等数据库无需扩展，传递null即可
		 */
		DDLFactory.createSqlFile(scanPackages, "D://sqltoy.sql", "upper", DBType.MYSQL, null, null);
	} catch (Exception e) {
		// TODO Auto-generated catch block
		e.printStackTrace();
	}
}
```
