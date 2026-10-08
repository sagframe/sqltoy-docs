# Dialect Adaptation & Functions
## 1. sqltoy provides automatic database function adaptation, i.e., at runtime the functions in SQL are automatically converted to functions that fit the current database dialect

```properties
# enable sqltoy's default function auto-adaptation conversion
spring.sqltoy.functionConverts=default
```
* To replace individual function implementations, e.g., for NVL, keeping the class name the same implements your own custom implementation replacing the one in default

```properties
# use a custom function implementation to replace Nvl
spring.sqltoy.functionConverts=default,com.yourpackage.Nvl
```

* You can also turn off default and fully decide yourself which functions to enable or load custom functions

```properties
# enable the built-in Nvl, Instr
spring.sqltoy.functionConverts=Nvl,Instr
# enable custom Nvl, Instr
# spring.sqltoy.functionConverts=com.yourpackage.Nvl,com.yourpackage.Instr
```

* functionConverts=default in sqltoy includes the following functions

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

* Function implementation interface

```java
org.sagacity.sqltoy.plugins.function.IFunction
```

* Trim function implementation example

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
		// other databases keep the trim(field) pattern
		return super.IGNORE;
	}
}
```

### 1.1 Source-form coverage of function adaptation (improved in 6.0.4)

The default function conversion keeps improving its recognition of **source function forms** and cross-database conversion. New in 6.0.4:

* `nvl2(a, b, c)`: an Oracle source function; non-Oracle databases automatically convert it to `case when a is not null then b else c` null-check logic
* `sys_timestamp`: the Oracle source form of current time (precision argument supported); passed through natively on the Oracle family and converted for other databases
* `strpos(str, sub)`: native on the PostgreSQL family / ClickHouse and passed through directly (argument order matches instr); converted to the corresponding instr implementation on other databases
* `substr(s, -n)`: unified cross-database handling of the negative-offset form (last N characters)

## 2. The sqlId+dialect pattern
* You can write SQL for specific databases; sqltoy picks the SQL that is actually executed based on the database type, in the order: dialect_sqlId->sqlId_dialect->sqlId. For example, if the database is mysql and sqlId: sqltoy_showcase is called, the SQL actually executed is: sqltoy_showcase_mysql


```xml
<sql id="sqltoy_showcase">
	<value>
	<![CDATA[
	select * from sqltoy_user_log t 
	where t.user_id=:userId 
	]]>
	</value>
</sql>
<!-- sqlId_dialect (lowercase) -->
<sql id="sqltoy_showcase_mysql">
	<value>
	<![CDATA[
	select * from sqltoy_user_log t 
	where t.user_id=:userId 
	]]>
	</value>
</sql>
```

### 2.1 The `dialect` attribute of the `<sql>` element (new in 6.0.3)

A single sql can declare — via the `dialect` attribute — that it is **parsed and solidified in a specified dialect form** (previously this attribute was silently ignored):

```xml
<!-- Declare that this sql is solidified in the kingbase dialect form: at load time function/reserved-word conversion is done once against kingbase -->
<sql id="sqltoy_showcase_kingbase" dialect="kingbase">
	<value>
	<![CDATA[
	select ifnull(max(t.amount),0) from sqltoy_user_log t where t.user_id=:userId
	]]>
	</value>
</sql>
```

How it works:

* **At load time**: function/reserved-word conversion is performed once against the declared dialect and the parse label is solidified (e.g. `ifnull` above is solidified into its `coalesce` form for kingbase); `count-sql` uses the same effective dialect as the main sql;
* **At execution time**: when the current database dialect equals the declaration, the "query dialect == parse label" early-exit path is taken and **function replacement is skipped** (zero overhead); otherwise lazy conversion + caching adapts it as before;
* **Priority**: `mql/eql forced to mongo/es` > `element dialect attribute` > `global dialect`; `mql`/`eql` do not support the attribute;
* The attribute value is validated against the dialect list; an unrecognized dialect triggers a warning and falls back to the global dialect;
* Working with `realDialectFirst`: when `<sql id="x_kingbase" dialect="kingbase">` is matched via variant lookup, the kingbase form is already solidified and the labels are equal — even the lazy conversion is skipped at execution time.

### 2.2 realDialectFirst: prefer the real dialect for variant lookup (new in 6.0.3)

sqltoy determines the dialect from the JDBC connection's `productName`; in some scenarios (OceanBase configured as mysql, proxied databases, etc.) the **configured dialect differs from the real one**. With this switch enabled, sqlId dialect-variant lookup first follows the real dialect detected from the connection (`DBProfile.realDialect`):

```properties
# default false; when the real-dialect variant does not exist, the original configured-dialect lookup chain is used as fallback;
# behavior is unchanged when the real dialect equals the configured one
spring.sqltoy.realDialectFirst=true
```

* Example: global `dialect=mysql` while the real database is kingbase — when enabled, calling `sqlId` first looks for `sqlId_kingbase`, then falls back to `sqlId_mysql` → `sqlId`;
* For sqls selected via real-dialect variant matching, function/reserved-word replacement also follows the real dialect (sqls that fall back to the base keep the configured-dialect behavior);
* Only the sql form-conversion layer (functions and reserved words) is affected; execution-strategy dispatch such as pagination is not.

## 3. How to test against multiple database environments at the same time
* sqltoy provides the spring.sqltoy.redoDataSources parameter to set the databases on which queries are repeatedly executed

```properties
# e.g., while on a mysql setup, test other types of databases at the same time to verify that the SQL adapts to different databases; mainly used for productized software
spring.sqltoy.redoDataSources[0]=pgdb
```

## 4. FAQ
* 1) Why do my kingbase, polardb, oceanbase and similar databases still produce lots of errors when using the mysql or postgresql database mode?
Answer: because sqltoy determines the database type from the productName obtained through the JDBC connection, it cannot always accurately determine the database's dialect mode. Therefore, resolve this with one of the following two approaches
### Option 1: In a single-database scenario, set the current database dialect directly

```properties
spring.sqltoy.dialect=mysql
```

### Option 2: In multi-database scenarios, alias incorrectly identified products to the correct database dialect
* spring.sqltoy.dialectMap is of type Map<String,String>; the current dialect can be queried with SELECT version() or a similar statement (ask AI for the exact statement)

```properties
spring.sqltoy.dialectMap.kingbase=mysql
```

* How the dialectMap mapping works, to help you set correct Map keys: the key is matched via indexOf against the productName

```java
// For databases not supported by the framework, match via the dialectMap keys to map to the corresponding dialect
for (Map.Entry<String, String> entry : dialectMap.entrySet()) {
	if (StringUtil.indexOfIgnoreCase(dbDialect, entry.getKey()) != -1) {
		dilectName = entry.getValue().toLowerCase();
		break;
	}
}
```

* 2) After solidifying the global dialect, my dialect-variant sql written for the real database does not take effect?
Answer: dialect variants (`sqlId_dialect` / `dialect_sqlId`) are looked up by the **configured dialect** by default. If the configured dialect differs from the connection's real dialect (e.g. OceanBase configured as mysql while the real database is oceanbase), since 6.0.3 you can enable `spring.sqltoy.realDialectFirst=true` — variant lookup and function replacement will then follow the real dialect first; see [2.2 realDialectFirst](#22-realdialectfirst-prefer-the-real-dialect-for-variant-lookup-new-in-603).
