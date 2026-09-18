# Dynamic SQL Guide

sqltoy's dynamic SQL design goal: **keep SQL clean and directly runnable in a database client**, while stripping out of the SQL the dynamic logic (such as `<if>`) that mybatis intermixes into it.

- SQL can be written in `*.sql.xml` files (recommended: easy to maintain, supports hot reloading), passed in directly from Java code, or supplied through the third-party lambda plugin (sqltoy-plus).
- For simple scenarios, use the explicit `lightDao` interfaces directly; for complex ones, organize parameters with `findByQuery`/`findPageByQuery` together with `QueryExecutor` or `EntityQuery`. All explicit interfaces are built on `QueryExecutor` underneath — understand it once and you can use them all flexibly.

---

## 1. How the `#[]` Condition Fragment Works

sqltoy uses `#[ ... ]` to mark a **dynamic condition fragment**. The core rules:

1. `#[ ... ]` marks the condition inside as dynamic; **required conditions do not need** `#[]`.
2. If **any parameter inside the fragment is null (or blank)**, the entire fragment is removed automatically.
3. **Multi-level nesting** is supported: `#[t.type=:type #[and t.amt>:amt and t.quantity>:quantity]]`.
4. When a required condition (without `#[]`) gets a null parameter, it is converted automatically to `is null` / `is not null`.
5. sqltoy enables `blank-to-null="true"` by default: blank strings are treated as null automatically.
6. `#` happens to be the comment marker in MySQL and similar databases, so **SQL containing `#[]` can be copied straight into a client and executed**, which makes debugging easy.

---

## 2. The XML Form

```xml
<!-- blank-to-null="true" is the default; equivalent to <sql id="show_case" blank-to-null="true"> -->
<sql id="show_case">
    <filters>
        <!-- Pre-normalize condition parameters via filters -->
        <eq params="status" value="-1" />
        <!-- Two ways to turn off blank-to-null:
             1. blank-to-null="false"
             2. Apply the blank tag once to any parameter (including nonexistent ones), which switches off the default automatically -->
        <blank params="anyParamNameIncludeNotExist"/>
    </filters>
    <value><![CDATA[
        select *
        from sqltoy_device_order_info t
        where
              -- when orderType is null it converts automatically to t.order_type is null
              t.order_type=:orderType
              and t.ORGAN_ID in (:authedOrganIds)
              #[and t.status=:status]
              #[and t.ORDER_ID=:orderId]
              #[and t.TRANS_DATE>=:beginAndEndDate[0]]
              #[and t.TRANS_DATE<:beginAndEndDate[1]]
              #[and (t.TECH_GROUP,t.PROD_GROUP) in (:techGroups,:prodGroups)]
    ]]></value>
</sql>
```

Common attributes of the `<sql>` tag: `id` (required), `type` (`search`/`insert`/`update`/`delete`; `select` is a legacy-compatible alias), `blank-to-null` (default `true`), `debug` (whether to output execution logs), `query-timeout` (query timeout in seconds), `dataSource` (specifies a data source name).

---

## 3. The Java Form (Anything XML Can Do, Code Can Do Too)

```java
String whereString = """
        orderType=:orderType
        and organId in (:authedOrganIds)
        #[and status=:status]
        #[and orderId=:orderId]
        #[and transDate>=:beginAndEndDate[0]]
        #[and transDate<:beginAndEndDate[1]]
        #[and (techGroup,prodGroup) in (:techGroups,:prodGroups)]
        """;
List result = lightDao.findEntity(DeviceOrderVO.class, EntityQuery.create()
        // .blankNotNull()  // turn off blank-to-null
        .where(whereString)
        .values(MapKit.keys("orderType", "authedOrganIds", "status", "orderId", "transDate")
                .values("PO", authedOrganIds, "1", "S0001", beginAndEndTime))
        .filters(new ParamsFilter("status").eq("-1")));
```

---

## 4. Complete Reference for the `filters` Parameter Filters

`<filters>` pre-normalizes condition parameters before the SQL executes (to-null conversion, type conversion, formatting, reverse cache matching, etc.) and is the core of sqltoy's dynamic SQL. In Java it corresponds to `ParamsFilter`, passed in via `.filters(...)`.

> **Design philosophy — pre-normalization**: this is where sqltoy's simplicity comes from — filters trim condition parameters into shape before they enter the SQL, **keeping interference with the SQL body itself to a minimum**. `#[]` retains only one intrinsic form — "if the parameter has a value, splice it in" — while all other condition logic (setting null, formatting, splitting/merging) is moved up front into filters, so the SQL always keeps an intuitive, concise, native structure.

### 4.1 To-Null Filters (set the parameter to null when the condition is met, thereby removing the corresponding `#[]` fragment)

| Tag | Attributes | Description |
| --- | --- | --- |
| `<blank>` | `params` (default `*`), `excludes` | Converts the parameter to null if it is blank |
| `<eq>` | `params`, `value`, `excludes` | Converts the parameter to null if it equals the given value (a match on any value within an array converts) |
| `<neq>` | `params`, `value` | Converts the parameter to null if it does not equal the given value |
| `<gt>` / `<gte>` | `params`, `value` | Converts to null if the parameter is greater than / greater than or equal to the given value |
| `<lt>` / `<lte>` | `params`, `value` | Converts to null if the parameter is less than / less than or equal to the given value |
| `<between>` | `params`, `start-value`, `end-value`, `excludes` | Converts to null if the parameter falls within the range |

### 4.2 LIKE Fuzzy-Match Handling

| Tag | Attributes | Description |
| --- | --- | --- |
| `<l-like>` | `params`, `append-str` | Appends `%` on the right when the parameter is non-blank (i.e. `xxx%`) |
| `<r-like>` | `params`, `append-str` | Prepends `%` on the left when the parameter is non-blank (i.e. `%xxx`) |
| `<escapeLike>` | `params` | Escapes special characters in like parameters |

### 4.3 Type Conversion and Formatting

| Tag | Attributes | Description |
| --- | --- | --- |
| `<to-number>` | `params`, `data-type` (decimal/integer/double/float/long) | Converts the parameter to a numeric type |
| `<to-array>` | `params`, `data-type` (string/decimal/...) | Converts the parameter to an array (a single value becomes an array of length 1) |
| `<to-string>` | `params`, `add-quote` (none/single/double) | Converts the parameter to a string, optionally quoted |
| `<to-date>` | `params`, `format`, `type`, `increment-time`, `increment-unit` | Converts to a date; `format` supports `yyyy-MM-dd`, `FIRST_OF_MONTH`, `LAST_OF_YEAR`, `FIRST_OF_WEEK`, etc.; `increment-time` accepts dynamic parameters such as `${incrementDays}` |
| `<split>` | `params`, `split-sign` (default `,`), `data-type` | Splits a concatenated string into an array (commonly used for in conditions) |
| `<default>` | `params`, `value`, `data-type`, `split-sign`, `is-array` | Sets a default value for the parameter; `value` supports expressions such as `sysdate()-2d`, `first_of_month` |
| `<replace>` | `params`, `regex`, `value`, `is-first` | Regex replacement on the parameter |
| `<to-in-arg>` | `params`, `single-quote` (default true) | Concatenates an array into a single string used as the value of an `in (:args)` condition |
| `<remove-null>` | `params`, `remove-blank` (default true) | Removes null or blank entries from arrays/collections |
| `<date-format>` | `params`, `format` | Formats a date parameter (rarely used) |

### 4.4 Advanced Filters

| Tag | Attributes | Description |
| --- | --- | --- |
| `<primary>` | `param`, `excludes` | **Primary parameter**: e.g. when an order number has a value it signals a precise query; apart from permission conditions excluded via `excludes`, no other conditions participate in filtering |
| `<exclusive>` | `param`, `set-params`, `compare-type`, `compare-values`, `set-value` | Mutually exclusive parameter handling |
| `<clone>` | `param`, `as-param` | Copies a parameter's value and stores it as another parameter |
| `<cache-arg>` | `param`, `cache-name`, `cache-key-index`, `cache-mapping-indexes`, `cache-mapping-max`, `alias-name`, `unmatched-return-self`, etc. | **Reverse cache matching**: matches a name into an array of corresponding codes (e.g. inputting "Zhang Ming" matches out the array of employee IDs containing that name) which then participates in the query, replacing inefficient like. May contain the `<filter cache-index compare-param compare-type split-sign>` child tag |
| `<custom-handler>` | `params`, `type` | Custom data handler |
| `<valid-sqlInjection>` | `params`, `level` (STRICT_WORD/RELAXED_WORD/SQL_KEYWORD) | SQL injection parameter validation |

> **Reverse cache matching (cache-arg)** is a signature sqltoy capability; see [Cache Translate in Action](../quickstart/translates.md) and [Large-Scale Cache (FIFO)](../translate/sqltoy_FIFO_translate.md).

---

## 5. Complete `<sql>` Specification Quick Reference

Below is a `<sql>` element listing **all available child tags** (validated against `sqltoy.xsd`). This is a "full landscape" reference — **in practice, just pick what you need; the vast majority of SQL only needs `<value>` plus a handful of tags** (see the minimal example at the end of this section). Note that some tags are mutually exclusive (e.g. `pivot` and `unpivot`).

```xml
<?xml version="1.0" encoding="utf-8"?>
<sqltoy xmlns="http://www.sagframe.com/schema/sqltoy"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy https://sagframe.github.io/schema/sqltoy.xsd">
<!--
  id: recommended to name as moduleName+functionName to avoid duplicates across modules
  type: search/insert/update/delete (select is a legacy-compatible alias, same as search)
  debug: whether to output execution logs for this sql (defaults to the global debug value)
  blank-to-null: whether blank strings are converted to null, default true; once <blank params="specificParam"/> appears in filters, the default is switched off automatically
  query-timeout: statement timeout for a single sql (seconds)
  dataSource: specify a data source name (special scenarios)
-->
<sql id="sqltoy_sql_specs" type="search" debug="false" blank-to-null="true">
    <!-- sql description for readability and maintenance; not executed; must be used together with <value> -->
    <remarks>Staff information query demo</remarks>

    <!-- ===== filters: pre-normalizes the parameter values participating in query/execution (see section 4 of this page) ===== -->
    <filters>
        <!-- Most common: eq, to-date; most elegant: cache-arg; most powerful: primary -->
        <!-- Converts the parameter to null when it equals the given value (e.g. a dropdown "All" sends -1 so the condition is not applied) -->
        <eq params="organType" value="-1" />
        <!-- Date conversion: format can be a custom pattern like yyyy-MM-dd, or FIRST_OF_MONTH/LAST_OF_MONTH/FIRST_OF_YEAR/LAST_OF_YEAR/FIRST_OF_WEEK/LAST_OF_WEEK;
             increment-time adds/subtracts time, increment-unit defaults to days -->
        <to-date params="beginDate" format="yyyy-MM-dd" increment-time="1" increment-unit="days"/>
        <!-- Copies a parameter value into a new parameter (often combined with to-date to build a date range from a single date) -->
        <clone param="beginDate" as-param="endDate"/>
        <to-number params="amt" data-type="decimal" />
        <!-- Convert to string; add-quote: none/single/double -->
        <to-string params="staffName" add-quote="single" />
        <!-- Escape special characters in like parameters -->
        <escapeLike params="staffName"/>
        <!-- Prepend/append % (skipped if the parameter already contains %) -->
        <l-like params="staffName"/>
        <r-like params="staffName"/>
        <!-- Reverse cache matching: matches names via like into the corresponding codes used as conditions, enabling precise queries -->
        <cache-arg param="staffName" cache-name="staffCache" alias-name="staffIds" prior-match-equal="false">
            <!-- Filters the cache, e.g. by personally authorized organizations or active status; cache-index refers to which cache column -->
            <filter compare-param="1" cache-index="4"/>
        </cache-arg>
        <!-- Primary parameter: e.g. when an order number is entered precisely, all conditions except the permission conditions excluded via excludes are set to null -->
        <primary param="orderId" excludes="organIds" />
        <!-- Concatenates an array into an in-condition string wrapped in single quotes -->
        <to-in-arg params="organIds" />
        <!-- Formats a date into a string (combine with to-number to get numeric months like 202112) -->
        <date-format params="bizMonth" format="yyyyMM"/>
        <!-- Blank to null (all blanks are converted to null by default; usually no configuration needed) -->
        <blank params="*" excludes="staffName" />
        <!-- Converts to null when the range/magnitude comparison is satisfied -->
        <between params="amt" start-value="0" end-value="9999" excludes="" />
        <lte params="" value="" />
        <lt params="" value="" />
        <gte params="" value="" />
        <gt params="" value="" />
        <!-- Removes null or blank entries from arrays/collections -->
        <remove-null params="organIds" remove-blank="true"/>
        <!-- Character replacement (regex replaces all occurrences by default; is-first=true replaces only the first) -->
        <replace params="" regex="" value="" is-first="false" />
        <!-- Default values: sysdate()-1d (d=days/h=hours/w=weeks/m=months/y=years); first_of_month-3d/first_of_year/last_of_month... -->
        <default params="beginDate" data-type="localDate" value="sysdate()-1d" />
        <!-- Exclusive parameter: when a parameter holds a specific value, other parameters are set to specific values -->
        <exclusive param="" compare-type="eq" compare-values="" set-params="" set-value="" />
        <!-- Custom parameter handler (implement FilterHandler, configured via spring.sqltoy.customFilterHandler) -->
        <custom-handler params="" type=""/>
    </filters>

    <!-- ===== Cache Translate: code→name, supports A,B concatenated translation (split-sign/link-sign) ===== -->
    <!-- uncached-template: supplementary display when no match is found; ${value} stands for the original key value, e.g. [${value} undefined] -->
    <translate cache="dictCache" cache-type="POST_TYPE" columns="POST_TYPE" cache-indexs="1" uncached-template="" />

    <!-- ===== Security: masking and decryption ===== -->
    <!-- Masking type: tel/name/id-card/bank-card/address/email/public-account/discrete-rate/other -->
    <secure-mask columns="telNo" type="tel" head-size="3" tail-size="4" mask-code="*" mask-rate="50" />
    <!-- Decrypts encrypted stored fields at query time -->
    <secure-decrypt columns="idCard"/>

    <!-- ===== Database/Table sharding ===== -->
    <sharding-datasource strategy="multiDataBase" />
    <sharding-table tables="sys_order" strategy="hisRealTable" params="beginDate" />

    <!-- ===== Pagination Optimize: caches count results for identical conditions ===== -->
    <!-- alive-max: how many sets of counts for different conditions are kept per sql; alive-seconds: survival seconds; parallel: whether count and the data query run in parallel -->
    <page-optimize alive-max="100" alive-seconds="600" parallel="false" />

    <!-- ===== Result-set formatting ===== -->
    <date-format columns="createTime" format="yyyy-MM-dd HH:mm:ss" />
    <!-- Number formats: #,###.00, capital (Chinese uppercase), capital-rmb (uppercase RMB amount), capital-en; supports rounding-mode/locale/currency -->
    <number-format columns="totalAmt" format="capital-rmb" />

    <!-- ===== Tree sorting, sorting within levels, level-by-level aggregation ===== -->
    <tree-sort id-column="organ_id" pid-column="organ_pid" sum-columns="staff_cnt" level-order-column="staff_cnt" order-way="desc">
        <!-- Rows with status 0 are excluded from aggregation -->
        <sum-filter column="status" compare-type="neq" compare-values="0"/>
    </tree-sort>

    <!-- ===== SQL body (required) ===== -->
    <value>
    <![CDATA[
    -- comments can be written directly in the sql
    select t1.*,t2.ORGAN_NAME from
    @fast(select * from sys_staff_info t
          where #[t.sexType=:sexType]
            #[and t.JOIN_DATE>:beginDate]
            #[and t.STAFF_NAME like :staffName]
            -- @if() for logical decisions
            #[@if(:isVirtual==true||:isVirtual==0) and t.IS_VIRTUAL=1]
          ) t1,sys_organ_info t2
     where t1.ORGAN_ID=t2.ORGAN_ID
    ]]>
    </value>

    <!-- Custom count statement (only effective for pagination; sqltoy already optimizes count intelligently — hand-write it only in extreme performance scenarios) -->
    <count-sql><![CDATA[]]></count-sql>

    <!-- ===== Result-set analysis algorithms ===== -->
    <!-- Grouped totals/averages -->
    <summary sum-columns="staff_cnt" average-columns="amt" average-radix-sizes="2" reverse="false" sum-site="left" average-skip-null="false">
        <global sum-label="Total" label-column="organ_name" />
        <!-- order-column: sort column within groups; order-with-sum defaults to true; order-way desc/asc -->
        <group sum-label="Subtotal" label-column="organ_name" group-column="organ_id" order-column="staff_cnt"/>
    </summary>
    <!-- Grouped concatenation (replaces group_concat/WM_CONCAT): id-columns are the grouping columns, columns are the concatenated columns (required), result-type can be ARRAY/LIST/SET -->
    <link id-columns="organ_id" columns="staff_name" sign="," distinct="true"/>
    <!-- Rows to columns (mutually exclusive with unpivot) -->
    <pivot category-columns="order_month" group-columns="fruit_name" start-column="sale_count" end-column="total_amt" default-value="0" />
    <!-- Columns to rows: columns-to-rows format "column:label,column:label" -->
    <unpivot columns-to-rows="chinese_score:Chinese,math_score:Math" new-columns-labels="subject_name,score_value" />
    <!-- Column chain-relative (horizontal comparison among same-type columns): group-size is the number of metrics per group, relative-indexs are the indexes of the metrics being compared, start-column is the starting column -->
    <cols-chain-relative group-size="3" relative-indexs="1,2" start-column="1" format="#.00%" />
    <!-- Row chain-relative (vertical comparison across rows): group-column is the grouping column, relative-columns are the columns being compared -->
    <rows-chain-relative group-column="sale_date" relative-columns="sales_amt" format="#.00%" reduce-one="true" multiply="100" insert="true" />
</sql>
</sqltoy>
```

### Child Tag Quick Reference

| Child tag | Purpose | See |
| --- | --- | --- |
| `<remarks>` | sql description (not executed) | This page |
| `<filters>` | Condition parameter pre-normalization (to-null / type conversion / reverse cache matching, etc.) | Section 4 of this page |
| `<translate>` | Cache Translate (code→name) | [Cache Translate in Action](../quickstart/translates.md) |
| `<secure-mask>` / `<secure-decrypt>` | Result-set masking / field decryption | [Data Masking & Encryption](../enterprise/sqltoy_security.md) |
| `<sharding-datasource>` / `<sharding-table>` | Database / table sharding strategies | [Sharding](../enterprise/sqltoy_sharding.md) |
| `<page-optimize>` / `<count-sql>` | Pagination count cache optimization / custom count | [Pagination Optimize](pagination.md) |
| `<date-format>` / `<number-format>` | Result-set date / number formatting | This page |
| `<summary>` | Grouped totals / averages | [Complex Query & Analytics](sqltoy_complex_query.md) |
| `<pivot>` / `<unpivot>` | Rows to columns / columns to rows | [Complex Query & Analytics](sqltoy_complex_query.md) |
| `<cols-chain-relative>` / `<rows-chain-relative>` | Column / row period-over-period comparison | [Complex Query & Analytics](sqltoy_complex_query.md) |
| `<tree-sort>` | Tree sorting and level-by-level aggregation | [Complex Query & Analytics](sqltoy_complex_query.md) |
| `<link>` | Grouped concatenation (replaces group_concat) | [Complex Query & Analytics](sqltoy_complex_query.md) |
| `<value>` | SQL body (required); supports `#[]`, `@if`, `@fast`, etc. | This page / [Tags & Expressions](../appendix/tags.md) |

### Minimal Everyday Example

Don't be intimidated by the "full landscape" above — everyday SQL is usually just this simple. For example, suppose the page has a gender dropdown whose "All" option carries `value="-1"`; an `eq` filter turns `-1` into null, and that condition automatically drops out of the query:

```html
<select name="sexType">
    <option value="-1">All</option>
    <option value="F">Female</option>
    <option value="M">Male</option>
</select>
```

```xml
<sql id="sys_staff_find">
    <filters>
        <!-- When sexType=-1 (All) it converts to null and the whole #[and t.sex_type=:sexType] fragment is removed -->
        <eq params="sexType" value="-1" />
    </filters>
    <translate cache="dictCache" cache-type="POST_TYPE" columns="postType" />
    <value><![CDATA[
        select * from sys_staff_info t
        where 1=1
        #[and t.sex_type=:sexType]
        #[and t.staff_name like :staffName]
    ]]></value>
</sql>
```

## 6. Related Advanced Syntax

- Macro directives such as `@if()`/`@elseif()`/`@else`, `@fast`, `@blank()`, `@value()`, `@loop()`/`@secure-loop()`, `@include(sqlId)`, `@include(:scriptParam)` are covered in [Tags & Expressions](../appendix/tags.md).
- More practical patterns (dynamic `@include`, configuration-driven SQL integration, slow SQL statistics, etc.) are covered in [SQL Showcase](sql_showcase.md).
- Query APIs (findOne/find/findPage/findTop/findRandom/getValue/isUnique, etc.) are covered in [Query API](sqltoy_query.md).
