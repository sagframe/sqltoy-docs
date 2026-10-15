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

* functionConverts=default in sqltoy includes the following functions (28 in total since 6.0.5)

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

### 1.1 Function adaptation improvements (6.0.4)

**New source functions / source forms recognized:**

* `nvl2(a, b, c)`: an Oracle source function; non-Oracle databases automatically convert it to `case when a is not null then b else c` null-check logic (passed through natively on the Oracle family; argument-count mismatch keeps the loud error);
* `isnull(x)` single-argument null check: MySQL's isnull returns a 0/1 flag; it was previously converted to nvl/coalesce/ifnull (all requiring ≥2 arguments) and failed with an argument-count error on target databases — now handled correctly;
* `sys_timestamp`: the Oracle source form of current time (precision argument supported); passed through natively on the Oracle family, converted to the corresponding current-time function elsewhere (mysql family keeps the fsp precision argument, sqlserver uses `sysdatetime()`);
* `strpos(str, sub)`: native on the PostgreSQL family / ClickHouse and passed through directly (argument order matches instr); converted to the corresponding instr implementation on other databases;
* `substr(s, -n)` negative offset: the two-argument literal form becomes `RIGHT(s, n)` (compatible with db2-style 1-based positions); the three-argument form uses a case guard (`start = length-n+1`, falling back to 1 when the string is shorter — mysql semantics); expression start positions are left as-is for the target database to judge; HANA's negative offset follows pg semantics (silently wrong values) and is normalized the same way;
* `curdate()` / `CURRENT_DATE`: new current-date (midnight) function class — the Oracle family becomes `TRUNC(CURRENT_DATE)` (session timezone preserved), db2 uses the `CURRENT DATE` keyword form, sqlite uses the local clock (its native CURRENT_DATE is a UTC wall clock, inconsistent with business timezones).

**Fixes and enhancements to existing conversions:**

* `group_concat` / `listagg` / `string_agg` conversion enhancements: supports the `within group (order by …)` trailing clause, embedded `order by` inside arguments (e.g. pg source `string_agg(a, '-' order by b)`), and `DISTINCT` prefix recognition (explicit loud passthrough where ClickHouse's groupArray does not support them); an "order by" text inside a separator literal is no longer misread as an order-by clause;
* `datediff(month, …)` unified month-difference semantics: MONTHS_BETWEEN's Oracle fractional basis (day difference divided by a 1/31-day month) diverges across databases and is no longer registered as a source form — the year/month component difference is used uniformly;
* `to_char` → sqlserver target: carried by FORMAT (2012+), fixing wrong output for uppercase format forms (e.g. `'YYYY-MM-DD HH24:MI:SS'`) caused by .NET token case-sensitivity, plus quoted-format literal protection;
* sqlite targets for now() / CURRENT_DATE / CURRENT_TIMESTAMP: uniformly use the local clock (the native forms are UTC wall clocks, 8 hours off for UTC+8 business logic).

### 1.2 Function adaptation improvements (6.0.5)

**New function classes (11, all registered into `default`):**

* `find_in_set(str, strlist)`: native on the MySQL family; elsewhere rewritten as "wrap with commas + exact substring positioning via instr" (so `1` does not match `11`);
* `uuid()` unique-id generation: unifies source spellings `uuid`/`guid`/`newid`/`sys_guid`/`random_uuid`/`gen_random_uuid`/`uuid_generate_v4`, converted per target (mysql `uuid()`, oracle family `sys_guid()`, pg family `gen_random_uuid()`, sqlserver `newid()`, etc.);
* `year`/`month`/`day` (plus `hour`/`minute`/`second`, ...) date-time component extraction;
* `last_day`/`eomonth` last day of the month;
* `add_months` month arithmetic (month-end clamping);
* `date_add`/`date_sub`/`dateadd`/`adddate`/`subdate` date-interval arithmetic family;
* `left(str, n)`/`right(str, n)` prefix/suffix extraction;
* `lpad`/`rpad` fixed-length padding;
* `extract`/`date_part` component extraction (ANSI and pg forms);
* `trunc`/`date_trunc` date-truncation family (oracle `trunc(x[, unit])` and pg `date_trunc(unit, x)` dual source forms);
* `mod(a, b)` modulo (real-DB probing across 18 environments shows only sqlserver lacks mod — converted to the `%` operator).

**Source-spelling expansion for existing functions:**

* `instr`: added `locate`/`posstr` (mysql and db2 user forms);
* `length`: added `character_length` (ANSI) / `octet_length` (pg byte form);
* `now`: added the `current_timestamp` keyword source form (standard SQL);
* `if`: added `iif` (native on sqlserver 2012+/sqlite 3.32+);
* `substr`: added `mid` (mysql synonym);
* `to_date`: added `str_to_date` (mysql user form).

**Function adaptation for the new database (HighGo added in 6.0.5):**

* HighGo (PG12 kernel + Oracle compatibility layer): no `uuid()`/`gen_random_uuid()` but has `sys_guid()`; `last_day`/`add_months`/`trunc` are native; no `listagg` but `string_agg` is native — carried by the HIGHGO branch of the function adapters.

> All the above additions/expansions are verified by real-database probing across multiple databases; forms that cannot be converted safely (e.g. aggregate ordering unsupported by the target) are kept "loud" — passed through as-is for the target database to error on, avoiding silent wrong values.

### 1.3 Extending function adaptation yourself (application side, no framework change needed)

The 28 built-in functions cover the common ones **whose syntax differs across databases**. When your project meets a function the framework does not adapt — a database-private function, a domain-specific one, or something a database added recently — **extend it yourself; there is no need to wait for framework support**. Implement `IFunction` and mount it via `functionConverts`; it then runs through exactly the same mechanism as the built-ins.

**The contract (`org.sagacity.sqltoy.plugins.function.IFunction`)**

| Method | Purpose | Return convention |
|---|---|---|
| `dialects()` | declares which dialects this function adapts | `ALL` (the empty string) means every dialect; otherwise a comma- or semicolon-separated **exact enumeration** of dialect names |
| `regex()` | matches the function call in the SQL | a `Pattern` used to locate the function to rewrite |
| `wrap(dialect, functionName, hasArgs, args...)` | produces the SQL for the target dialect | return the rewritten fragment; return `IGNORE` (null) to **pass through unchanged** |
| `wrapArgs(functionName, args...)` | protected convenience helper | builds the result for the most common shape: same function name, arguments re-joined |

**Minimal example: only SQL Server needs rewriting, every other database passes through** (the built-in `Mod`)

```java
public class Mod extends IFunction {
	// the leading \W prevents matching trim( inside ltrim(, and (?i) makes it case-insensitive
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
		// sqlserver has no mod function (verified against a real server); the % operator carries it.
		// every other database supports mod natively, so pass through
		if (dialect == DBType.SQLSERVER) {
			return "(" + args[0].trim() + " % " + args[1].trim() + ")";
		}
		return super.IGNORE;
	}
}
```

**Points that matter**

1. `regex()` should start with `\W` and end with `\(`, e.g. `(?i)\Wmod\(`. The leading `\W` prevents substring false positives; `(?i)` makes it case-insensitive.
2. `dialects()` is matched by **splitting on commas/semicolons and comparing each item exactly**, not by substring containment — containment is biased in both directions (declaring `oracle11` would be hit by the current dialect `oracle`, and declaring `oracle` would fail to match the dialect `oracle11`). A custom function must therefore explicitly enumerate the dialect names it adapts.
3. Matching runs against the SQL **with literals masked**, so the same text appearing inside a string constant is never rewritten by mistake.
4. `args` in `wrap` are the already-split argument expressions as written, possibly with surrounding whitespace — `trim()` them before concatenating.
5. **Only the function-call form can be rewritten.** Operator forms (SQL Server's `a % b`, Oracle's `a || b`) are not function calls, so the regex framework cannot capture them and they are out of scope — write the function form in cross-database SQL (`mod(a,b)`, `concat(a,b)`) for the best portability.
6. In most cases `wrap` should return `IGNORE` for databases that already support the function natively, and rewrite only the dialects that genuinely differ. Rewriting indiscriminately breaks native behavior.

**Overriding a built-in implementation**

`functionConverts` de-duplicates by function name, and the built-ins expanded from `default` are loaded **after** the custom entries, so a custom implementation with the same name overrides the built-in one:

```properties
# your own Nvl overrides the built-in Nvl; the rest of the built-ins stay active
spring.sqltoy.functionConverts=default,com.yourpackage.Nvl
```

Short class names (`Nvl`, `Instr`) resolve only inside the framework's own impl package — use fully qualified names for custom implementations.

**Advanced: trailing-clause hooks**

For a few functions the dialect difference is not inside the parentheses but in the clause immediately following the closing paren — e.g. an aggregate's `within group (order by ...)`, or the boolean convention in `find_in_set(x,y) > 0`. Three optional hooks cover this:

- `suffixPattern()`: the pattern for the trailing clause; it must start with `\s*` to absorb the separating whitespace and end with `\(*`. Returning null (the default) means this function does not consume a trailing clause.
- `suffixNeedsParen()`: true (default) consumes the whole clause by balanced parentheses; false consumes exactly what the pattern matched, for bare operator clauses such as `>0` / `=0`.
- `wrapWithSuffix(dialect, functionName, suffix, args...)`: the entry point when the suffix pattern hits; `suffix` is the clause as written (including leading whitespace). Returning `IGNORE` keeps the clause verbatim.

**When not to extend a function, and use a dialect sqlId instead**

If the difference is not "the same function written differently" but **a structurally different statement** (pagination syntax, recursive CTE form, upsert semantics, window-function support), function rewriting cannot solve it — use the `sqlId_dialect` / `dialect_sqlId` variants or the `<sql dialect="xxx">` attribute instead; see section 2.

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

## 3. Virtual-table macro @virtualTable() (new in 6.0.6)

For "select constant-row union real-query" SQL (dictionary dropdown fallback rows, fixed report total rows, etc.), databases differ in their support for "select of constant rows (without FROM)": oracle/db2/hana require a pseudo-table, while mysql/pg/sqlserver etc. natively support FROM-less select (writing `from dual` actually errors there). Since 6.0.6, write the `@virtualTable()` macro where the pseudo-table belongs — sqltoy expands it per dialect at SQL parse time (processed before function/reserved-word conversion and solidified with SqlToyConfig), so one SQL works across all databases. Taking an xml configuration as an example:

```xml
<sql id="sys_tenant_options">
	<value>
	<![CDATA[
		select '0' tenant_id,'Global' tenant_name @virtualTable()
		union
		select s.tenant_id,s.tenant_name
		from sys_tenant_info s
		where s.status=1
	]]>
	</value>
</sql>
```

The SQL actually executed on different databases:

```sql
-- oracle / oracle11 / dm (Dameng) / oceanbase: expanded to from dual
select '0' tenant_id,'Global' tenant_name from dual
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1

-- db2: expanded to from sysibm.sysdummy1
select '0' tenant_id,'Global' tenant_name from sysibm.sysdummy1
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1

-- hana: expanded to from dummy
select '0' tenant_id,'Global' tenant_name from dummy
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1

-- mysql / postgresql / sqlserver etc.: macro stripped (FROM-less select is native)
select '0' tenant_id,'Global' tenant_name
union
select s.tenant_id,s.tenant_name from sys_tenant_info s where s.status=1
```

Dialect expansion reference:

| Database | Macro expansion |
| --- | --- |
| oracle / oracle11 / dm (Dameng) / oceanbase | `from dual` |
| db2 | `from sysibm.sysdummy1` |
| hana | `from dummy` |
| mysql family (mysql/tidb/doris/starrocks), pg family (postgresql/gaussdb/mogdb/openGauss/stardb/vastbase/oscar/kingbase/highgo), sqlserver, sqlite, h2, clickhouse, impala, tdengine | Stripped (FROM-less select is native) |

Notes:

* Compatible aliases `@dual()` / `@dummyTable()` — all three names are equivalent, case-insensitive, and tolerant of spaces inside the parentheses;
* May appear multiple times in one SQL, each expanded independently per dialect (one per constant select);
* Works in xml-configured SQL, `@Sql` annotation SQL and code SQL (`findBySql` etc.) alike (unified parse pipeline);
* Expansion happens at parse time and is solidified with SqlToyConfig (same timing as function/reserved-word conversion), zero runtime overhead; SQL without the macro is completely unaffected (plain SQL containing `@` such as `email like 'a@%'` is not touched);
* The pseudo-table mapping shares the same source as the pseudo-tables used by the framework's merge-statement generation (each Dialect's VIRTUAL_TABLE constant);
* With `realDialectFirst`, the macro is expanded and solidified by the "parse dialect" — the runtime lazy-conversion layer does not re-expand it.

## 4. How to test against multiple database environments at the same time
* sqltoy provides the spring.sqltoy.redoDataSources parameter to set the databases on which queries are repeatedly executed

```properties
# e.g., while on a mysql setup, test other types of databases at the same time to verify that the SQL adapts to different databases; mainly used for productized software
spring.sqltoy.redoDataSources[0]=pgdb
```

## 5. FAQ
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
