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

* sqltoy中functionConverts=default包含以下函数（6.0.5 起共 28 个）

```java
org.sagacity.sqltoy.plugins.function.impl.SubStr
org.sagacity.sqltoy.plugins.function.impl.Trim
org.sagacity.sqltoy.plugins.function.impl.Instr
org.sagacity.sqltoy.plugins.function.impl.Concat
org.sagacity.sqltoy.plugins.function.impl.ConcatWs
org.sagacity.sqltoy.plugins.function.impl.Nvl
org.sagacity.sqltoy.plugins.function.impl.DateFormat
org.sagacity.sqltoy.plugins.function.impl.Now
org.sagacity.sqltoy.plugins.function.impl.CurrentDate
org.sagacity.sqltoy.plugins.function.impl.Length
org.sagacity.sqltoy.plugins.function.impl.ToChar
org.sagacity.sqltoy.plugins.function.impl.If
org.sagacity.sqltoy.plugins.function.impl.GroupConcat
org.sagacity.sqltoy.plugins.function.impl.ToNumber
org.sagacity.sqltoy.plugins.function.impl.ToDate
org.sagacity.sqltoy.plugins.function.impl.DateDiff
org.sagacity.sqltoy.plugins.function.impl.Decode
org.sagacity.sqltoy.plugins.function.impl.FindInSet
org.sagacity.sqltoy.plugins.function.impl.Uuid
org.sagacity.sqltoy.plugins.function.impl.YearMonthDay
org.sagacity.sqltoy.plugins.function.impl.LastDay
org.sagacity.sqltoy.plugins.function.impl.AddMonths
org.sagacity.sqltoy.plugins.function.impl.DateAdd
org.sagacity.sqltoy.plugins.function.impl.LeftRight
org.sagacity.sqltoy.plugins.function.impl.Pad
org.sagacity.sqltoy.plugins.function.impl.Extract
org.sagacity.sqltoy.plugins.function.impl.DateTrunc
org.sagacity.sqltoy.plugins.function.impl.Mod
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

### 1.2 函数适配完善（6.0.5）

**新增函数类（11 个，均默认注册进 `default`）：**

* `find_in_set(str, strlist)`：mysql 系原生透传，其余库以"首尾补逗号 + instr 精确子串定位"改写（避免 `1` 命中 `11` 的误判）；
* `uuid()` 唯一 id 生成：归一 `uuid`/`guid`/`newid`/`sys_guid`/`random_uuid`/`gen_random_uuid`/`uuid_generate_v4` 等多种源拼写，按目标库转换（mysql 用 `uuid()`、oracle 系用 `sys_guid()`、pg 系用 `gen_random_uuid()`、sqlserver 用 `newid()` 等）；
* `year`/`month`/`day`（含 `hour`/`minute`/`second` 等）日期时间分量提取；
* `last_day`/`eomonth` 当月最后一天；
* `add_months` 月份加减（月末钳制）；
* `date_add`/`date_sub`/`dateadd`/`adddate`/`subdate` 日期区间加减族；
* `left(str, n)`/`right(str, n)` 前缀后缀取串；
* `lpad`/`rpad` 定长填充；
* `extract`/`date_part` 分量提取（ANSI 与 pg 写法）；
* `trunc`/`date_trunc` 日期截断族（oracle 的 `trunc(x[, unit])` 与 pg 的 `date_trunc(unit, x)` 双源形态）；
* `mod(a, b)` 取模（18 环境实测仅 sqlserver 无 mod 函数，转 `%` 运算符）。

**既有函数源拼写扩充：**

* `instr`：补 `locate`/`posstr`（mysql 与 db2 用户写法）；
* `length`：补 `character_length`（ANSI 写法）/`octet_length`（pg 字节写法）；
* `now`：补 `current_timestamp` 关键字源拼写（标准 SQL 写法）；
* `if`：补 `iif`（sqlserver 2012+/sqlite 3.32+ 原生）；
* `substr`：补 `mid`（mysql 同义词写法）；
* `to_date`：补 `str_to_date`（mysql 用户写法）。

**新增数据库的函数适配（配合 6.0.5 新增瀚高 HighGo）：**

* 瀚高 HighGo（PG12 内核 + oracle 兼容层）：无 `uuid()`/`gen_random_uuid()` 但有 `sys_guid()`、`last_day`/`add_months`/`trunc` 原生、无 `listagg` 而 `string_agg` 原生，由函数适配器的 HIGHGO 分支承担。

> 上述新增/扩充函数均经多数据库真库探针验证；无法安全转换的形态（如目标库不支持的聚合排序）保持"响亮保留"，原样交由目标库报错，避免静默错值。

### 1.3 自行扩展函数适配（开发者侧，无需框架改动）

内置的 28 个函数覆盖的是**跨库写法存在差异**的常见函数。项目里遇到框架没适配的函数——数据库私有函数、行业专用函数、某个库新引入的函数——**由项目开发者自行扩展即可，不需要等框架层面支持**：实现 `IFunction` 并通过 `functionConverts` 挂载，与内置函数走的是完全同一套机制。

**契约（`org.sagacity.sqltoy.plugins.function.IFunction`）**

| 方法 | 作用 | 返回约定 |
|---|---|---|
| `dialects()` | 声明本函数适配哪些方言 | `ALL`（即空串）表示全部方言；否则用逗号或分号分隔**精确枚举**方言名 |
| `regex()` | 匹配 SQL 中的函数调用 | `Pattern`，用于定位待改写的函数 |
| `wrap(dialect, functionName, hasArgs, args...)` | 产出目标方言的 SQL | 返回改写后的片段；返回 `IGNORE`（即 null）表示**原样透传** |
| `wrapArgs(functionName, args...)` | 受保护的便捷方法 | 按“函数名不变、仅重新拼接参数”这一最常见形态生成结果 |

**最小示例：只有 SQL Server 需要改写，其余库原生透传**（内置 `Mod` 的实现）

```java
public class Mod extends IFunction {
	// 开头的 \W 防止把 ltrim( 之类误命中成 trim(，(?i) 保证大小写不敏感
	private static Pattern regex = Pattern.compile("(?i)\\Wmod\\(");

	@Override
	public String dialects() {
		return ALL;
	}

	@Override
	public Pattern regex() {
		return regex;
	}

	@Override
	public String wrap(int dialect, String functionName, boolean hasArgs, String... args) {
		if (args == null || args.length < 2) {
			return super.IGNORE;
		}
		// sqlserver 无 mod 函数(真库实测)，由 % 运算符承担；其余全库原生透传
		if (dialect == DBType.SQLSERVER) {
			return "(" + args[0].trim() + " % " + args[1].trim() + ")";
		}
		return super.IGNORE;
	}
}
```

**必须注意的几点**

1. `regex()` 要以 `\W` 开头、以 `\(` 结尾，如 `(?i)\Wmod\(`。开头的 `\W` 防止子串误命中，`(?i)` 保证大小写不敏感。
2. `dialects()` 是**按逗号/分号切分后逐项精确比对**，不是子串包含匹配——子串匹配有双向偏差（声明 `oracle11` 会被当前方言 `oracle` 误命中，声明 `oracle` 又匹配不上方言 `oracle11`）。所以自定义函数必须显式枚举要适配的方言名。
3. 匹配是在**字面量掩码后的 SQL** 上进行的，因此字符串常量里出现的同名文本不会被误改写。
4. `wrap` 的 `args` 是已切分好的参数表达式原文，可能带空白，拼接前建议 `trim()`。
5. **只能改写函数名形态**。运算符写法（如 SQL Server 的 `a % b`、Oracle 的 `a || b`）不是函数调用，正则框架捕获不到，因此不在适配范围内——跨库 SQL 请统一写函数形态（`mod(a,b)`、`concat(a,b)`），可移植性最好。
6. 绝大多数情况下 `wrap` 应当对“本来就原生支持该函数的库”返回 `IGNORE`，只改写真正有差异的方言。无差别改写会破坏原生行为。

**覆盖内置实现**

`functionConverts` 按函数名去重，且 `default` 展开的内置函数**排在自定义之后加载**，因此自定义的同名实现会覆盖内置的：

```properties
# 用自己的 Nvl 覆盖内置 Nvl，其余内置函数照常生效
spring.sqltoy.functionConverts=default,com.yourpackage.Nvl
```

类名简写（`Nvl`、`Instr`）只在框架自带的 impl 包内解析，自定义实现请写全限定类名。

**进阶：尾部子句钩子**

少数函数的方言差异不在括号内，而在闭括号之后紧邻的附属子句上，例如聚合的 `within group (order by ...)`、`find_in_set(x,y) > 0` 这类布尔口径。这类场景用三个可选钩子：

- `suffixPattern()`：尾部子句的匹配 pattern，须以 `\s*` 开头承担间隔空白、以 `\(*` 结尾；返回 null（默认）表示本函数不消费尾部子句
- `suffixNeedsParen()`：true（默认）按平衡括号消费整个子句；false 按 pattern 命中长度消费，用于 `>0`/`=0` 这类裸操作符子句
- `wrapWithSuffix(dialect, functionName, suffix, args...)`：命中后的处理入口，`suffix` 是子句原文（含前导空白）；返回 `IGNORE` 表示连同子句原样保留

**什么时候不该扩展函数，而该用方言 sqlId**

如果差异不是“同一个函数换个写法”，而是**整条 SQL 的结构不同**（分页语法、递归 CTE 写法、upsert 语义、窗口函数支持度），函数改写解决不了，应当用 `sqlId_dialect` / `dialect_sqlId` 变体或 `<sql dialect="xxx">` 属性，见第 2 节。

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

## 3. 虚表宏 @virtualTable()（6.0.6 新增）

"select 常量行 union 真实查询"类 sql（字典下拉兜底行、报表固定合计行等）在各数据库对"select 常量行（不带 from）"的支持不一致：oracle/db2/hana 必须挂伪表，mysql/pg/sqlserver 等原生支持无 from 的 select（写 `from dual` 反而语法错）。6.0.6 起在需要伪表的位置写 `@virtualTable()` 宏，sqltoy 在 sql 解析期按方言自动展开（在函数/保留字转换前处理，随 SqlToyConfig 固化），一条 sql 全库通用。以 xml 配置为例：

```xml
<sql id="sys_tenant_options">
	<value>
	<![CDATA[
		select '0' tenant_id,'全局公共' tenant_name @virtualTable()
		union
		select s.tenant_id,s.tenant_name
		from sys_tenant_info s
		where s.status=1
	]]>
	</value>
</sql>
```

不同数据库上实际执行的 sql：

```sql
-- oracle / oracle11 / dm(达梦) / oceanbase：展开为 from dual
select '0' tenant_id,'全局公共' tenant_name from dual
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1

-- db2：展开为 from sysibm.sysdummy1
select '0' tenant_id,'全局公共' tenant_name from sysibm.sysdummy1
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1

-- hana：展开为 from dummy
select '0' tenant_id,'全局公共' tenant_name from dummy
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1

-- mysql / postgresql / sqlserver 等：宏被剔除（原生支持无 from 的 select）
select '0' tenant_id,'全局公共' tenant_name
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1
```

方言展开对照：

| 数据库 | 宏展开结果 |
| --- | --- |
| oracle / oracle11 / dm（达梦） / oceanbase | `from dual` |
| db2 | `from sysibm.sysdummy1` |
| hana | `from dummy` |
| mysql 系（mysql/tidb/doris/starrocks）、pg 系（postgresql/gaussdb/mogdb/openGauss/stardb/vastbase/oscar/kingbase/highgo）、sqlserver、sqlite、h2、clickhouse、impala、tdengine | 直接剔除（原生支持无 from 的 select） |

使用说明：

* 兼容别名 `@dual()` / `@dummyTable()`，三名等价、大小写不敏感、括号内空白容错；
* 同一条 sql 可出现多次，每处独立按方言展开（每个常量 select 各写一个）；
* xml 配置 sql、`@Sql` 注解 sql、代码 sql（`findBySql` 等）同样有效（统一解析管线）；
* 展开发生在解析期并随 SqlToyConfig 固化（与函数/保留字转换同一时机），运行期零开销；不含宏的 sql 零影响（含 `@` 的普通 sql 如 `email like 'a@%'` 不受影响）；
* 伪表映射与框架生成 merge 语句所用伪表同源（各 Dialect 的 VIRTUAL_TABLE 常量），行为一致；
* `realDialectFirst` 场景下宏按"解析方言"展开固化，运行期惰性转换层不再重复展开宏。

## 4. 如何同时测试多种数据库环境
* sqltoy提供了spring.sqltoy.redoDataSources参数，来设置查询语句重复执行的数据库

```properties
# 如在mysql场景下同时测试其他类型数据库，验证sql适配不同数据库，主要用于产品化软件
spring.sqltoy.redoDataSources[0]=pgdb
```

## 5. 常见问题
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
