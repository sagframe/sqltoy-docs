#  sql数据库方言自适配和函数扩展
## 1. sqltoy提供了数据库函数自动适配功能，即在运行过程中将sql中的函数自动转换为适配当前数据库方言的函数

```properties
# 开启sqltoy默认的函数自适配转换函数
spring.sqltoy.functionConverts=default
```
* 如果对个别函数实现要进行替换,比如NVL类名称保持一致即实现了自定义实现对default中的替换

```properties
# 自定义函数来实现替换Nvl
spring.sqltoy.functionConverts=default,com.yourpackage.Nvl
```

* 你也可以关闭default，完全自行定义开启哪些函数或加载自定义的函数

```properties
# 启用框架自带Nvl、Instr
spring.sqltoy.functionConverts=Nvl,Instr
# 启用自定义Nvl、Instr
# spring.sqltoy.functionConverts=com.yourpackage.Nvl,com.yourpackage.Instr
```

* sqltoy中functionConverts=default包含以下函数

```java
org.sagacity.sqltoy.plugins.function.impl.Concat
org.sagacity.sqltoy.plugins.function.impl.ConcatWs
org.sagacity.sqltoy.plugins.function.impl.DateFormat
org.sagacity.sqltoy.plugins.function.impl.Decode
org.sagacity.sqltoy.plugins.function.impl.GroupConcat
org.sagacity.sqltoy.plugins.function.impl.If
org.sagacity.sqltoy.plugins.function.impl.Instr
org.sagacity.sqltoy.plugins.function.impl.Length
org.sagacity.sqltoy.plugins.function.impl.Now
org.sagacity.sqltoy.plugins.function.impl.Nvl
org.sagacity.sqltoy.plugins.function.impl.SubStr
org.sagacity.sqltoy.plugins.function.impl.ToChar
org.sagacity.sqltoy.plugins.function.impl.ToDate
org.sagacity.sqltoy.plugins.function.impl.Trim
```

* 函数实现接口

```java
org.sagacity.sqltoy.plugins.function.IFunction
```

* Trim函数实现示例

```java
public class Trim extends IFunction {
	private static Pattern regex = Pattern.compile("(?i)\\Wtrim\\(");

	/*
	 * (non-Javadoc)
	 * 
	 * @see org.sagacity.sqltoy.config.function.IFunction#dialects()
	 */
	@Override
	public String dialects() {
		return ALL;
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see org.sagacity.sqltoy.config.function.IFunction#regex()
	 */
	@Override
	public Pattern regex() {
		return regex;
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see org.sagacity.sqltoy.config.function.IFunction#wrap(int,
	 * java.lang.String[])
	 */
	@Override
	public String wrap(int dialect, String functionName, boolean hasArgs, String... args) {
		if (args == null || args.length == 0) {
			return super.IGNORE;
		}
		if (dialect == DBType.SQLSERVER) {
			return "rtrim(ltrim(" + args[0] + "))";
		}
		if (dialect == DBType.H2) {
			return "trim(both ' ' from " + args[0] + ")";
		}
		// 其他数据库保持trim(field) 模式
		return super.IGNORE;
	}
}
```

## 2. 通过sqlId+dialect模式
* 可针对特定数据库写sql,sqltoy根据数据库类型获取实际执行sql,顺序为: dialect_sqlId->sqlId_dialect->sqlId， 如数据库为mysql,调用sqlId:sqltoy_showcase,则实际执行:sqltoy_showcase_mysql


```xml
<sql id="sqltoy_showcase">
	<value>
	<![CDATA[
	select * from sqltoy_user_log t 
	where t.user_id=:userId 
	]]>
	</value>
</sql>
<!-- sqlId_数据库方言(小写) -->
<sql id="sqltoy_showcase_mysql">
	<value>
	<![CDATA[
	select * from sqltoy_user_log t 
	where t.user_id=:userId 
	]]>
	</value>
</sql>
```

## 3. 如何同时测试多种数据库环境
* sqltoy提供了spring.sqltoy.redoDataSources参数，来设置查询语句重复执行的数据库

```properties
# 如在mysql场景下同时测试其他类型数据库，验证sql适配不同数据库，主要用于产品化软件
spring.sqltoy.redoDataSources[0]=pgdb
```

## 4. 常见问题
* 1) 为什么我的kingbase、polardb、oceanbase这些数据库使用mysql或postgresql数据库模式，还有大量错误？
解答: 因为sqltoy获取数据库方言是通过jdbc connection获取当前productName来判断数据库类型，并不能完全准确获取数据库的方言模式，所以要通过2种方式之一来解决
### 方式一: 单一数据库场景下直接设置当前数据库方言

```properties
spring.sqltoy.dialect=mysql
```

### 方式二: 多数据库场景下，将识别不准确的alias到正确的数据库方言上
* spring.sqltoy.dialectMap 是Map<String,String>类型,当前dialect可用SELECT version()或类似语句查询(具体是什么问AI)

```properties
spring.sqltoy.dialectMap.kingbase=mysql
```

* dialectMap 映射原理，帮助你设置正确的Map key,key indexOf productName

```java
// 针对框架未支持的数据库，通过dialectMap的key进行匹配映射到响应的方言上
for (Map.Entry<String, String> entry : dialectMap.entrySet()) {
	if (StringUtil.indexOfIgnoreCase(dbDialect, entry.getKey()) != -1) {
		dilectName = entry.getValue().toLowerCase();
		break;
	}
}
```
