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

### 1.1 函数适配完善（6.0.4）

**新增源函数 / 源形态识别：**

* `nvl2(a, b, c)`：oracle 源函数，非 oracle 系数据库自动转换为 `case when a is not null then b else c` 判空逻辑（oracle 系原生透传；参数个数不对时保留响亮报错）；
* `isnull(x)` 单参判空：mysql 的 isnull 返回 0/1 判空语义，此前被错转为要求 ≥2 参数的 nvl/coalesce/ifnull 导致目标库报参数个数错误，现已正确处理；
* `sys_timestamp`：oracle 源当前时间形态（可带精度参数），oracle 系原生透传，其余数据库转换为对应的当前时间函数（mysql 系保留 fsp 精度参数，sqlserver 精度形态用 `sysdatetime()`）；
* `strpos(str, sub)`：pg 系 / clickhouse 原生写法直接透传（参数序与 instr 一致），其余数据库转换为对应的 instr 实现；
* `substr(s, -n)` 负起点：两参负起点字面量转 `RIGHT(s, n)`（兼容 db2 等起点从 1 计的库）；三参负起点走 case 守卫形态（`start = 串长-n+1`，串长不足 n 时取 1，mysql 语义）；表达式起点无法判断时原样保留交目标库判定；hana 的负起点为 pg 语义会静默错值，同样收敛；
* `curdate()` / `CURRENT_DATE`：新增当前日期（零点）函数类——oracle 系统一转 `TRUNC(CURRENT_DATE)`（保留会话时区）、db2 关键字体 `CURRENT DATE`、sqlite 取本地时钟（其原生 CURRENT_DATE 为 UTC 墙钟，与业务时区不一致）。

**既有函数转换修正与增强：**

* `group_concat` / `listagg` / `string_agg` 转换增强：支持 `within group (order by …)` 尾部子句、参数内嵌 `order by`（如 pg 源 `string_agg(a, '-' order by b)`）、`DISTINCT` 前缀识别（clickhouse 的 groupArray 不支持 DISTINCT 与排序时显式响亮保留）；分隔符字面量内含 "order by" 文本不再被误判为排序子句；
* `datediff(month, …)` 跨库月差口径统一：MONTHS_BETWEEN 的 oracle 小数口径（日差按 1/31 天月折算）与各库语义分歧，不再作为源函数注册转换，统一按年月分量差计算；
* `to_char` → sqlserver 目标：以 FORMAT（2012+）承担，修复大写格式形态（如 `'YYYY-MM-DD HH24:MI:SS'`）与 .NET token 大小写敏感导致的错值，并归一带引号格式串的字面量保护；
* sqlite 目标的 now() / CURRENT_DATE / CURRENT_TIMESTAMP：统一取本地时钟（原生为 UTC 墙钟，东八区业务差 8 小时）。

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

### 2.1 `<sql>` 元素的 dialect 属性（6.0.3 新增）

单条 sql 可以通过 `dialect` 属性**声明按指定方言形态解析固化**（此前该属性不被解析而静默忽略）：

```xml
<!-- 声明本条 sql 按 kingbase 方言形态固化：加载时即按 kingbase 做函数/保留字转换 -->
<sql id="sqltoy_showcase_kingbase" dialect="kingbase">
	<value>
	<![CDATA[
	select ifnull(max(t.amount),0) from sqltoy_user_log t where t.user_id=:userId
	]]>
	</value>
</sql>
```

工作机制：

* **加载时**：按声明方言对 sql 做一次函数/保留字转换并固化解析标签（如上面的 `ifnull` 在 kingbase 固化为 `coalesce` 形态）；`count-sql` 与主 sql 使用同一生效方言；
* **执行时**：当前数据库方言与声明一致时，走"查询方言==解析标签"早退机制，**跳过函数替换**（零开销）；不一致时按既有惰性转换 + 缓存机制反向适配；
* **优先级**：`mql/eql 强制 mongo/es` > `元素 dialect 属性` > `全局方言`；`mql`/`eql` 不支持该属性；
* 属性值会经方言清单校验，未识别的方言 warn 提示并回退全局方言；
* 与 `realDialectFirst` 协同：`<sql id="x_kingbase" dialect="kingbase">` 被变体匹配命中时，加载已固化 kingbase 形态且标签相等，执行时连惰性转换都省略。

### 2.2 realDialectFirst：按真实方言优先匹配变体（6.0.3 新增）

sqltoy 判断方言依赖 JDBC 连接的 `productName`，部分场景（OceanBase 按 mysql 配置、代理数据库等）**配置方言与真实方言不一致**。开启本开关后，sqlId 方言变体的查找优先按连接探测的真实方言（`DBProfile.realDialect`）进行：

```properties
# 默认 false；真实方言变体不存在时回退原有配置方言查找链，真实方言与配置方言一致时行为不变
spring.sqltoy.realDialectFirst=true
```

* 例如全局 `dialect=mysql`、真实库为 kingbase：开启后调用 `sqlId` 会优先找 `sqlId_kingbase`，不存在再回退 `sqlId_mysql` → `sqlId`；
* 经真实方言变体匹配选中的 sql，其函数/保留字替换方言也跟随真实方言（未命中变体回退 base 的 sql 保持配置方言行为）；
* 仅作用于 sql 形态转换层（函数与保留字），分页等执行策略的数据库分派不受影响。

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

* 2) 全局 dialect 固化后，为真实数据库写的方言变体 sql 没有生效？
解答: 方言变体（`sqlId_dialect` / `dialect_sqlId`）默认按**配置方言**查找。若配置方言与连接的真实方言不一致（如 OB 按 mysql 配置而真实库为 oceanbase），6.0.3 起可开启 `spring.sqltoy.realDialectFirst=true`，变体查找与函数替换将优先跟随真实方言，参见 [2.2 realDialectFirst](#22-realdialectfirst按真实方言优先匹配变体603-新增)。
