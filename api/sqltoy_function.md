# sql函数扩展
* sqltoy提供了数据库函数自动适配功能，即在运行过程中将sql中的函数自动转换为适配当前数据库方言的函数

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
