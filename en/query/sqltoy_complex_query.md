# Complex Query & Analytics

sqltoy provides a set of analytics capabilities that **perform secondary computations on result sets in memory**: multi-dimensional group summary, pivot/unpivot, YoY & MoM comparisons, tree sort with layer-by-layer rollup, group concatenation, and more.

These algorithms deliver two standout benefits:

1. **Offloads the database**: computations such as row-column conversion and layer-by-layer rollup would cause huge CPU and memory overhead if done by the database; sqltoy processes them in a single linear pass in application memory with extremely high efficiency.
2. **Perfect cross-database compatibility**: the algorithms do not depend on any database dialect at all. The same SQL runs on MySQL and Oracle and migrates smoothly to domestic and mainstream databases such as Dameng (DM), GaussDB, and PostgreSQL.

All analytics features can be declared with tags in `*.sql.xml` or built fluently in Java with `QueryExecutor`; the two approaches are fully equivalent.

> The examples below all use a fruit sales record table `sqltoy_fruit_order` for demonstration.

---

## 1. Multi-Dimensional Group Summary (summary)

### 1.1 Use Case

In financial reports or sales statistics, subtotals, grand totals, or averages are usually appended at the bottom of the table or at the end of each group.

- **Traditional pain point**: SQL `GROUP BY ROLLUP` is not only cumbersome to write, its dialects also differ greatly across Oracle, MySQL, and SQL Server, making it extremely hard to maintain.
- **The sqltoy way**: the SQL only fetches the base detail rows, while sqltoy automatically completes multi-dimensional summarization and average calculation in memory.

### 1.2 XML Configuration Example

```xml
<sql id="group_summary_case">
    <value><![CDATA[
        select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt
        from sqltoy_fruit_order t
        order by t.fruit_name,t.order_month
    ]]></value>
    <!-- sum-columns: columns to sum; average-columns: columns to average; reverse:true puts summary rows on top -->
    <summary sum-columns="sale_count,sale_quantity,total_amt" reverse="true">
        <!-- global: grand total; label-column: which column holds the total label; sum-label: total label text -->
        <global label-column="fruit_name" sum-label="Total" />
        <!-- group: subtotal per group; group-column: the grouping column -->
        <group group-column="fruit_name" label-column="fruit_name" sum-label="Subtotal" />
    </summary>
</sql>
```

### 1.3 Attributes

`<summary>` tag attributes:

| Attribute | Description |
| --- | --- |
| `sum-columns` | Columns to sum, comma-separated |
| `average-columns` | Columns to average |
| `average-radix-sizes` | Decimal places kept for each average column, e.g. `1,3,2`; a single value applies to all |
| `average-rounding-modes` | Rounding modes: `HALF_UP`/`HALF_DOWN`/`ROUND_DOWN`/`ROUND_UP` |
| `average-skip-null` | Whether to exclude null values when averaging, default `false` |
| `sum-site` | Position of the summary row: `top`/`bottom`/`left`/`right`, default `top` |
| `reverse` | Whether the data is arranged in reverse order, default `false` |
| `link-sign` | Concatenation symbol when sum and average are shown in the same row, default ` / ` |
| `skip-single-row` | Whether single-row data also participates in summarization, default `false` |
| `has-grouped` | Whether the data has already been grouped and organized, default `true` |

`<global>` (grand total): `label-column` (required), `sum-label` (required), `average-label`, `reverse`.

`<group>` (group subtotal, multiple allowed): `group-column` (required), `label-column` (required), `sum-label` (required), `average-label`, `order-column` (column used to order the groups), `order-with-sum` (default `true`), `order-way` (`desc`/`asc`).

### 1.4 Effect

Category|Sale Month|Sales Count|Sale Quantity (tons)|Sale Amount (10K CNY)
----|-------|-------|----------|------------
Total|       |   71  |    12600 |14900
Subtotal|       |  36  | 5900   | 7500
Apple|2019-05|12 | 2000|2400
Apple|2019-04|11 | 1900|2600
Apple|2019-03|13 | 2000|2500
Subtotal|       | 35  | 6700|7400
Banana|2019-05|10 | 2000|2000
Banana|2019-04|12 | 2400|2700
Banana|2019-03|13 | 2300|2700

---

## 2. Dynamic Pivot

### 2.1 Use Case

Converts a "narrow table" in the database (multiple row records) into a "wide table" for front-end display (multiple columns). For example, row data of "month, product, sales volume" is expanded horizontally into "product, March sales, April sales, May sales".

- **Traditional pain point**: the database `PIVOT` syntax cannot cope with dynamic, non-fixed columns; once months or product types change dynamically, pure SQL breaks down.
- **The sqltoy way**: combining its core algorithms, sqltoy perfectly supports fully dynamic pivot with just a few declarative lines.

### 2.2 XML Configuration Example

```xml
<sql id="pivot_case">
    <value><![CDATA[
        select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt
        from sqltoy_fruit_order t
        order by t.fruit_name,t.order_month
    ]]></value>
    <!-- group-columns: row grouping columns; category-columns: horizontal category columns;
         start-column~end-column: range of metric columns to rotate (3 columns from sale_count to total_amt) -->
    <pivot group-columns="fruit_name" category-columns="order_month"
           start-column="sale_count" end-column="total_amt" />
</sql>
```

`<pivot>` attributes: `group-columns` (required), `category-columns` (required), `start-column` (required), `end-column` (required), `category-sql` (generate the category columns dynamically via SQL), `default-value`, `default-type`.

> [!TIP]
> For a plain pivot that meets the default regular criteria, you can simply write `<pivot/>` without the lengthy attributes.

### 2.3 Effect

<table>
<thead>
    <tr>
        <th rowspan="2">Category</th>
        <th colspan="3">2019-03</th>
        <th colspan="3">2019-04</th>
        <th colspan="3">2019-05</th>
    </tr>
    <tr>
        <th>Count</th><th>Quantity</th><th>Total Amount</th>
        <th>Count</th><th>Quantity</th><th>Total Amount</th>
        <th>Count</th><th>Quantity</th><th>Total Amount</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>Banana</td><td>13</td><td>2300</td><td>2700</td><td>12</td><td>2400</td><td>2700</td><td>10</td><td>2000</td><td>2000</td>
    </tr>
    <tr>
        <td>Apple</td><td>13</td><td>2000</td><td>2500</td><td>11</td><td>1900</td><td>2600</td><td>12</td><td>2000</td><td>2400</td>
    </tr>
</tbody>
</table>

---

## 3. Unpivot

### 3.1 Use Case

The opposite of `pivot`. Raw data imported from Excel is often a wide table (e.g. student ID, Chinese score, math score, English score); for easier cleansing, loading, or fine-grained analysis, it needs to be converted into a narrow table (student ID, subject, score).

### 3.2 XML Configuration Example

```xml
<sql id="sys_student_score_unpivot">
    <value><![CDATA[
        select t.student_no,t.chinese_score,t.math_score,t.english_score
        from sys_student_score t
    ]]></value>
    <!-- columns-to-rows: "column name:metric name", comma separated; new-columns-labels: headers of the two newly created columns -->
    <unpivot columns-to-rows="chinese_score:Chinese,math_score:Math,english_score:English"
             new-columns-labels="subject_name,score_value" />
</sql>
```

`<unpivot>` attributes: `columns-to-rows` (required, format `col1:metricName1,col2:metricName2`), `new-columns-labels` (required, sets the headers of the 2 newly created columns so they can be mapped to VO properties, e.g. `indexName,indexValue`).

---

## 4. YoY and MoM Calculations

### 4.1 Use Case

In BI dashboards, merely displaying sales figures is not enough; you often need to show the **MoM growth rate** (this month vs. last month) or the **YoY growth rate**. sqltoy provides two tags — `<cols-chain-relative>` (column-level MoM, horizontal comparison among like columns) and `<rows-chain-relative>` (row-level MoM, vertical comparison between rows) — which compute and output percentage/per-mille values automatically.

### 4.2 Column-Level MoM (pivot first, then ratio)

```xml
<sql id="cols_relative_case">
    <value><![CDATA[
        select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt
        from sqltoy_fruit_order t
        order by t.fruit_name,t.order_month
    ]]></value>
    <!-- pivot first: each month has three metrics: count/quantity/total amount -->
    <pivot group-columns="fruit_name" category-columns="order_month"
           start-column="sale_count" end-column="total_amt" />
    <!-- ratio between columns: group-size=3 means 3 metrics per group; relative-indexs=1,2 means computing
         the MoM ratio for the 2nd and 3rd metrics; start-column=1 starts from the 1st column -->
    <cols-chain-relative group-size="3" relative-indexs="1,2" start-column="1" format="#.00%" />
</sql>
```

`<cols-chain-relative>` attributes: `group-size` (required), `relative-indexs` (required), `start-column` (required), `end-column` (negative values count from the end), `reduce-one` (whether to subtract 1: `(B-A)/A` instead of `B/A`), `multiply` (`1` decimal / `100` percent / `1000` per-mille), `radix-size` (decimal places kept, default 3), `rounding-mode`, `format` (`#.00%` / `#.00‰`), `defaultValue` (default value for the first group where no comparison value exists).

Effect (excerpt):

<table>
<thead>
    <tr>
        <th rowspan="2">Category</th>
        <th colspan="5">2019-03</th>
        <th colspan="5">2019-04</th>
        <th colspan="5">2019-05</th>
    </tr>
    <tr>
        <th>Count</th><th>Quantity</th><th>vs. Last Month</th><th>Total Amount</th><th>vs. Last Month</th>
        <th>Count</th><th>Quantity</th><th>vs. Last Month</th><th>Total Amount</th><th>vs. Last Month</th>
        <th>Count</th><th>Quantity</th><th>vs. Last Month</th><th>Total Amount</th><th>vs. Last Month</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>Banana</td><td>13</td><td>2300</td><td></td><td>2700</td><td></td>
        <td>12</td><td>2400</td><td>4.30%</td><td>2700</td><td>0.00%</td>
        <td>10</td><td>2000</td><td>-16.70%</td><td>2000</td><td>-26.00%</td>
    </tr>
    <tr>
        <td>Apple</td><td>13</td><td>2000</td><td></td><td>2500</td><td></td>
        <td>11</td><td>1900</td><td>-5.10%</td><td>2600</td><td>4.00%</td>
        <td>12</td><td>2000</td><td>5.20%</td><td>2400</td><td>-7.70%</td>
    </tr>
</tbody>
</table>

### 4.3 Row-Level MoM

```xml
<sql id="sales_rows_relative">
    <value><![CDATA[
        select t.sale_date,t.sales_amt from sales_table t order by t.sale_date asc
    ]]></value>
    <!-- group-column: grouping column (use -1 if there is no grouping); relative-columns: columns to compare;
         insert:true means the MoM value is added as a separate new column -->
    <rows-chain-relative group-column="sale_date" relative-columns="sales_amt"
                         format="#.00%" reduce-one="true" multiply="100" insert="true" />
</sql>
```

`<rows-chain-relative>` attributes: `group-column` (required, a column name or numeric index; use `-1` for a single-type comparison without grouping), `relative-columns` (required), `relative-indexs`, `start-row`, `end-row` (negative values count from the end), `reduce-one`, `reverse` (default `true`), `multiply`, `radix-size`, `rounding-mode`, `format`, `insert` (default `true`, whether the MoM value automatically adds a new column), `defaultValue`.

---

## 5. Tree Sort & Rollup (tree-sort)

### 5.1 Use Case

For tree tables with hierarchical relationships (organization structures, account categories, administrative divisions), the front end usually requires rows to be ordered by tree depth and lineage (Head Office → East China Branch → Shanghai Office ...), and **parent nodes automatically roll up the data of all their descendant nodes**.

### 5.2 XML Configuration Example

```xml
<sql id="treeTable_sort_sum">
    <value><![CDATA[
        select t.area_code,t.pid_area,sale_cnt from sqltoy_area_sales t
    ]]></value>
    <!-- builds the tree hierarchy, rolls up child node values layer by layer to parent nodes,
         and orders nodes within the same level by sale_cnt descending -->
    <tree-sort id-column="area_code" pid-column="pid_area" sum-columns="sale_cnt"
               level-order-column="sale_cnt" order-way="desc" />
</sql>
```

`<tree-sort>` attributes: `id-column` (required), `pid-column` (required), `sum-columns` (columns rolled up layer by layer), `level-order-column` (column used for ordering within each level), `order-way` (`desc`/`asc`, default `desc`). It can also contain the child tag `<sum-filter column="..." compare-type="eq|neq|gt|gte|lt|lte|between|in|out" compare-values="..."/>` to filter which nodes participate in the rollup.

### 5.3 Effect

<table>
<thead>
    <tr><th>Region</th><th>Parent Region</th><th>Sales Quantity</th></tr>
</thead>
<tbody>
    <tr><td>Shanghai</td><td>China</td><td>300</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Songjiang</td><td>Shanghai</td><td>&nbsp;&nbsp;&nbsp;&nbsp;120</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Yangpu</td><td>Shanghai</td><td>&nbsp;&nbsp;&nbsp;&nbsp;116</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Pudong</td><td>Shanghai</td><td>&nbsp;&nbsp;&nbsp;&nbsp;64</td></tr>
    <tr><td>Jiangsu</td><td>China</td><td>270</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Nanjing</td><td>Jiangsu</td><td>&nbsp;&nbsp;&nbsp;&nbsp;110</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Suzhou</td><td>Jiangsu</td><td>&nbsp;&nbsp;&nbsp;&nbsp;90</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;Wuxi</td><td>Jiangsu</td><td>&nbsp;&nbsp;&nbsp;&nbsp;70</td></tr>
</tbody>
</table>

---

## 6. Group Concatenation (link, replacing group_concat)

`group_concat`/`listagg`/`string_agg` are written differently across databases; sqltoy performs group concatenation in memory with the `<link>` tag, achieving consistent behavior across databases.

```xml
<sql id="organ_staff_link">
    <value><![CDATA[
        select t.organ_id,t.staff_name from sqltoy_staff_info t order by t.organ_id
    ]]></value>
    <!-- id-columns: grouping columns; columns: columns to concatenate; sign: separator; distinct: deduplicate or not -->
    <link id-columns="organ_id" columns="staff_name" sign="," distinct="true" />
</sql>
```

`<link>` attributes: `columns` (required, multiple columns allowed, e.g. `staff_id,staff_name`), `id-columns` (grouping columns, multiple allowed; make sure the SQL sorts properly), `sign` (separator, default comma), `distinct` (default `false`), `result-type` (`ARRAY`/`LIST`/`SET`, only applicable to a single field, presenting the result as a collection instead of a concatenated string).

---

## 7. Java API (QueryExecutor)

All of the XML analytics tags above have corresponding `QueryExecutor` fluent methods that can be built dynamically in code: `summary()`, `pivot()`, `unpivot()`, `colsChainRatio()`, `rowsChainRatio()`, `treeSort()`, `groupConcat()`, plus formatting `numFmt()`/`dateFmt()`, masking `secureMask()`, and more.

```java
@Autowired
private LightDao lightDao;

public void getComplexReport() {
    QueryResult result = lightDao.findByQuery(
        new QueryExecutor("group_summary_case")
            .names("startDate").values(LocalDate.now().minusMonths(3))
            // group summary: equivalent to the XML <summary>
            .summary(new Summary()
                .sumColumns("sale_count", "sale_quantity", "total_amt")
                .reverse(true)
                .summaryGroups(new SummaryGroup("fruit_name")
                    .labelColumn("fruit_name").sumTitle("Subtotal")))
            // column-level MoM: equivalent to <cols-chain-relative>
            .colsChainRatio(new ColsChainRatio()
                .groupSize(3).relativeIndexs(1, 2).startColumn("1").format("#.00%"))
            // number/date formatting
            .numFmt("#,###.00", RoundingMode.HALF_UP, "total_amt")
            .dateFmt("yyyy-MM-dd", "order_month")
    );

    List rows = result.getRows();          // final result set after the in-memory computation
    long executeTime = result.getExecuteTime(); // SQL execution time
}
```

> Tree rollup and group concatenation work the same way: `.treeSort(new TreeSort().idColumn("area_code").pidColumn("pid_area").sumColumns("sale_cnt").levelOrderColumn("sale_cnt").orderWay("desc"))`, `.groupConcat(new GroupConcat().group("organ_id").concat("staff_name").separator(",").distinct(true))`.
