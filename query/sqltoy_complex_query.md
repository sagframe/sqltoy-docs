# 复杂查询与数据分析

sqltoy 提供一组**在内存中对结果集做二次计算**的分析能力：多维分组汇总、行转列/列转行、同比环比、树形排序逐层汇总、分组拼接等。

这些算法有两个突出价值：

1. **解放数据库压力**：行列转换、逐层汇总等计算如果交给数据库做，会产生巨额 CPU 与内存开销；sqltoy 在应用内存中单次线性处理，效率极高。
2. **完美跨库适配**：算法完全不依赖数据库方言，同一套 SQL 既能跑在 MySQL、Oracle 上，也能平滑迁移到达梦（DM）、高斯（GaussDB）、PostgreSQL 等国产/主流数据库。

所有分析能力既可以在 `*.sql.xml` 中用标签声明，也可以用 `QueryExecutor` 在 Java 代码中链式构建，二者完全等价。

> 下面统一以一张"水果销售记录表" `sqltoy_fruit_order` 为例演示。

---

## 一、多维分组汇总（summary）

### 1.1 应用场景

在财务报表或销售统计中，通常需要在表格底部或各分组末尾加上"小计""合计"或"平均值"。

- **传统痛点**：使用 SQL 的 `GROUP BY ROLLUP` 不仅繁琐，且 Oracle、MySQL、SQL Server 方言差异极大，后期极难维护。
- **sqltoy 方案**：SQL 只管查出基础明细，由 sqltoy 在内存中自动完成多维汇总与平均值计算。

### 1.2 XML 配置范例

```xml
<sql id="group_summary_case">
    <value><![CDATA[
        select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt
        from sqltoy_fruit_order t
        order by t.fruit_name,t.order_month
    ]]></value>
    <!-- sum-columns:求和列; average-columns:求平均列; reverse:true 表示汇总行置顶 -->
    <summary sum-columns="sale_count,sale_quantity,total_amt" reverse="true">
        <!-- global:全局总计; label-column:总计标签放在哪一列; sum-label:总计文字 -->
        <global label-column="fruit_name" sum-label="总计" />
        <!-- group:按列分组小计; group-column:分组依据列 -->
        <group group-column="fruit_name" label-column="fruit_name" sum-label="小计" />
    </summary>
</sql>
```

### 1.3 属性说明

`<summary>` 标签属性：

| 属性 | 说明 |
| --- | --- |
| `sum-columns` | 需求和的列，逗号分隔 |
| `average-columns` | 需求平均的列 |
| `average-radix-sizes` | 各平均列保留小数位，如 `1,3,2`；单值表示全部 |
| `average-rounding-modes` | 舍入模式：`HALF_UP`/`HALF_DOWN`/`ROUND_DOWN`/`ROUND_UP` |
| `average-skip-null` | 求平均时是否排除 null 值，默认 `false` |
| `sum-site` | 汇总行位置：`top`/`bottom`/`left`/`right`，默认 `top` |
| `reverse` | 数据是否反向排列，默认 `false` |
| `link-sign` | sum 与 average 同行展示时的拼接符，默认 ` / ` |
| `skip-single-row` | 单行数据是否也参与汇总，默认 `false` |
| `has-grouped` | 数据是否已完成分组组织，默认 `true` |

`<global>`（全局总计）：`label-column`（必填）、`sum-label`（必填）、`average-label`、`reverse`。

`<group>`（分组小计，可多个）：`group-column`（必填）、`label-column`（必填）、`sum-label`（必填）、`average-label`、`order-column`（分组排序列）、`order-with-sum`（默认 `true`）、`order-way`（`desc`/`asc`）。

### 1.4 效果

品类|销售月份|销售笔数|销售数量(吨)|销售金额(万元)
----|-------|-------|----------|------------
总计|       |   71  |    12600 |14900
小计|       |  36  | 5900   | 7500
苹果|2019年5月|12 | 2000|2400
苹果|2019年4月|11 | 1900|2600
苹果|2019年3月|13 | 2000|2500
小计|       | 35  | 6700|7400
香蕉|2019年5月|10 | 2000|2000
香蕉|2019年4月|12 | 2400|2700
香蕉|2019年3月|13 | 2300|2700

---

## 二、动态行转列（pivot）

### 2.1 应用场景

将数据库中的"窄表"（多条行记录）转换成前端展示的"宽表"（多列）。例如把"月份、产品、销量"的行数据，横向展开为"产品、3月销量、4月销量、5月销量"。

- **传统痛点**：数据库 `PIVOT` 语法无法应对"动态不固定列"，一旦月份或产品类型动态变化，纯 SQL 就会失效。
- **sqltoy 方案**：结合核心算法完美支持纯动态集合行转列，几行声明即可搞定。

### 2.2 XML 配置范例

```xml
<sql id="pivot_case">
    <value><![CDATA[
        select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt
        from sqltoy_fruit_order t
        order by t.fruit_name,t.order_month
    ]]></value>
    <!-- group-columns:行分组列; category-columns:横向分类列;
         start-column~end-column:参与旋转的指标列区间(从 sale_count 到 total_amt 共3列) -->
    <pivot group-columns="fruit_name" category-columns="order_month"
           start-column="sale_count" end-column="total_amt" />
</sql>
```

`<pivot>` 属性：`group-columns`（必填）、`category-columns`（必填）、`start-column`（必填）、`end-column`（必填）、`category-sql`（用 SQL 动态产生分类列）、`default-value`、`default-type`。

> [!TIP]
> 符合默认规整标准的纯集合行转列，可直接简写 `<pivot/>`，无需冗长属性。

### 2.3 效果

<table>
<thead>
    <tr>
        <th rowspan="2">品类</th>
        <th colspan="3">2019年3月</th>
        <th colspan="3">2019年4月</th>
        <th colspan="3">2019年5月</th>
    </tr>
    <tr>
        <th>笔数</th><th>数量</th><th>总金额</th>
        <th>笔数</th><th>数量</th><th>总金额</th>
        <th>笔数</th><th>数量</th><th>总金额</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>香蕉</td><td>13</td><td>2300</td><td>2700</td><td>12</td><td>2400</td><td>2700</td><td>10</td><td>2000</td><td>2000</td>
    </tr>
    <tr>
        <td>苹果</td><td>13</td><td>2000</td><td>2500</td><td>11</td><td>1900</td><td>2600</td><td>12</td><td>2000</td><td>2400</td>
    </tr>
</tbody>
</table>

---

## 三、列转行（unpivot）

### 3.1 应用场景

与 `pivot` 相反。导入的 Excel 原始数据常是宽表（如：学号、语文成绩、数学成绩、英语成绩），为便于清洗、入库或细粒度分析，需要转换为窄表（学号、科目、成绩）。

### 3.2 XML 配置范例

```xml
<sql id="sys_student_score_unpivot">
    <value><![CDATA[
        select t.student_no,t.chinese_score,t.math_score,t.english_score
        from sys_student_score t
    ]]></value>
    <!-- columns-to-rows: "列名:指标名称" 逗号分隔; new-columns-labels: 新产生的两列标题 -->
    <unpivot columns-to-rows="chinese_score:语文,math_score:数学,english_score:英语"
             new-columns-labels="subject_name,score_value" />
</sql>
```

`<unpivot>` 属性：`columns-to-rows`（必填，格式 `col1:指标名称1,col2:指标名称2`）、`new-columns-labels`（必填，为新产生的 2 列设定标题，便于映射到 VO 属性，如 `indexName,indexValue`）。

---

## 四、同比与环比计算

### 4.1 应用场景

数据分析看板（BI）中，纯粹展示销售额不够，往往需要展示**环比增长率**（本月比上月）或**同比增长率**。sqltoy 提供 `<cols-chain-relative>`（列环比，水平方向同类列比较）与 `<rows-chain-relative>`（行环比，垂直方向行间比较）两个标签，自动计算并输出百分比/千分比。

### 4.2 列环比（先行转列再环比）

```xml
<sql id="cols_relative_case">
    <value><![CDATA[
        select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt
        from sqltoy_fruit_order t
        order by t.fruit_name,t.order_month
    ]]></value>
    <!-- 先行转列：每个月份下有 笔数/数量/总金额 三个指标 -->
    <pivot group-columns="fruit_name" category-columns="order_month"
           start-column="sale_count" end-column="total_amt" />
    <!-- 列与列之间环比：group-size=3 表示每组3个指标; relative-indexs=1,2 表示对第2、3个指标做环比; start-column=1 从第1列开始 -->
    <cols-chain-relative group-size="3" relative-indexs="1,2" start-column="1" format="#.00%" />
</sql>
```

`<cols-chain-relative>` 属性：`group-size`（必填）、`relative-indexs`（必填）、`start-column`（必填）、`end-column`（负数表示倒数第几列）、`reduce-one`（是否减 1，`(B-A)/A` 否则 `B/A`）、`multiply`（`1` 小数 / `100` 百分比 / `1000` 千分比）、`radix-size`（保留小数位，默认 3）、`rounding-mode`、`format`（`#.00%` / `#.00‰`）、`defaultValue`（首组无对比值时的默认值）。

效果（节选）：

<table>
<thead>
    <tr>
        <th rowspan="2">品类</th>
        <th colspan="5">2019年3月</th>
        <th colspan="5">2019年4月</th>
        <th colspan="5">2019年5月</th>
    </tr>
    <tr>
        <th>笔数</th><th>数量</th><th>比上月</th><th>总金额</th><th>比上月</th>
        <th>笔数</th><th>数量</th><th>比上月</th><th>总金额</th><th>比上月</th>
        <th>笔数</th><th>数量</th><th>比上月</th><th>总金额</th><th>比上月</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>香蕉</td><td>13</td><td>2300</td><td></td><td>2700</td><td></td>
        <td>12</td><td>2400</td><td>4.30%</td><td>2700</td><td>0.00%</td>
        <td>10</td><td>2000</td><td>-16.70%</td><td>2000</td><td>-26.00%</td>
    </tr>
    <tr>
        <td>苹果</td><td>13</td><td>2000</td><td></td><td>2500</td><td></td>
        <td>11</td><td>1900</td><td>-5.10%</td><td>2600</td><td>4.00%</td>
        <td>12</td><td>2000</td><td>5.20%</td><td>2400</td><td>-7.70%</td>
    </tr>
</tbody>
</table>

### 4.3 行环比

```xml
<sql id="sales_rows_relative">
    <value><![CDATA[
        select t.sale_date,t.sales_amt from sales_table t order by t.sale_date asc
    ]]></value>
    <!-- group-column:分组列(无分组可写 -1); relative-columns:参与比较的列; insert:true 表示环比值独立新增一列 -->
    <rows-chain-relative group-column="sale_date" relative-columns="sales_amt"
                         format="#.00%" reduce-one="true" multiply="100" insert="true" />
</sql>
```

`<rows-chain-relative>` 属性：`group-column`（必填，可写列名或数字索引，单一类型比较无分组可写 `-1`）、`relative-columns`（必填）、`relative-indexs`、`start-row`、`end-row`（负数表示倒数第几行）、`reduce-one`、`reverse`（默认 `true`）、`multiply`、`radix-size`、`rounding-mode`、`format`、`insert`（默认 `true`，环比值是否自动新增列）、`defaultValue`。

---

## 五、树形排序与逐层汇总（tree-sort）

### 5.1 应用场景

面对层级关系的树形表（组织架构、科目分类、行政区划），前端通常要求按树的深度与血缘顺序排列（总公司 → 华东分公司 → 上海办事处 …），并且**上层节点自动汇总所有子孙节点的数据**。

### 5.2 XML 配置范例

```xml
<sql id="treeTable_sort_sum">
    <value><![CDATA[
        select t.area_code,t.pid_area,sale_cnt from sqltoy_area_sales t
    ]]></value>
    <!-- 组织树形上下归属结构，将底层节点值逐层汇总到父节点，并对同层级按 sale_cnt 降序排列 -->
    <tree-sort id-column="area_code" pid-column="pid_area" sum-columns="sale_cnt"
               level-order-column="sale_cnt" order-way="desc" />
</sql>
```

`<tree-sort>` 属性：`id-column`（必填）、`pid-column`（必填）、`sum-columns`（逐层汇总列）、`level-order-column`（每层内部排序依据列）、`order-way`（`desc`/`asc`，默认 `desc`）。还可包含子标签 `<sum-filter column="..." compare-type="eq|neq|gt|gte|lt|lte|between|in|out" compare-values="..."/>` 过滤哪些节点参与汇总。

### 5.3 效果

<table>
<thead>
    <tr><th>地区</th><th>归属地区</th><th>销售量</th></tr>
</thead>
<tbody>
    <tr><td>上海</td><td>中国</td><td>300</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;松江</td><td>上海</td><td>&nbsp;&nbsp;&nbsp;&nbsp;120</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;杨浦</td><td>上海</td><td>&nbsp;&nbsp;&nbsp;&nbsp;116</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;浦东</td><td>上海</td><td>&nbsp;&nbsp;&nbsp;&nbsp;64</td></tr>
    <tr><td>江苏</td><td>中国</td><td>270</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;南京</td><td>江苏</td><td>&nbsp;&nbsp;&nbsp;&nbsp;110</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;苏州</td><td>江苏</td><td>&nbsp;&nbsp;&nbsp;&nbsp;90</td></tr>
    <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;无锡</td><td>江苏</td><td>&nbsp;&nbsp;&nbsp;&nbsp;70</td></tr>
</tbody>
</table>

---

## 六、分组拼接（link，代替 group_concat）

`group_concat`/`listagg`/`string_agg` 在各数据库写法不一，sqltoy 用 `<link>` 标签在内存中完成分组拼接，实现跨库一致。

```xml
<sql id="organ_staff_link">
    <value><![CDATA[
        select t.organ_id,t.staff_name from sqltoy_staff_info t order by t.organ_id
    ]]></value>
    <!-- id-columns:分组列; columns:被拼接列; sign:连接符; distinct:是否去重 -->
    <link id-columns="organ_id" columns="staff_name" sign="," distinct="true" />
</sql>
```

`<link>` 属性：`columns`（必填，可多列如 `staff_id,staff_name`）、`id-columns`（分组列，可多列，注意 SQL 做好排序）、`sign`（连接符，默认逗号）、`distinct`（默认 `false`）、`result-type`（`ARRAY`/`LIST`/`SET`，仅适用单字段，将结果以集合而非拼接字符串呈现）。

---

## 七、Java 代码方式（QueryExecutor）

上述所有 XML 分析标签都有对应的 `QueryExecutor` 链式方法，可在代码中动态构建：`summary()`、`pivot()`、`unpivot()`、`colsChainRatio()`、`rowsChainRatio()`、`treeSort()`、`groupConcat()`，以及格式化 `numFmt()`/`dateFmt()`、脱敏 `secureMask()` 等。

```java
@Autowired
private LightDao lightDao;

public void getComplexReport() {
    QueryResult result = lightDao.findByQuery(
        new QueryExecutor("group_summary_case")
            .names("startDate").values(LocalDate.now().minusMonths(3))
            // 分组汇总：等价于 XML 的 <summary>
            .summary(new Summary()
                .sumColumns("sale_count", "sale_quantity", "total_amt")
                .reverse(true)
                .summaryGroups(new SummaryGroup("fruit_name")
                    .labelColumn("fruit_name").sumTitle("小计")))
            // 列环比：等价于 <cols-chain-relative>
            .colsChainRatio(new ColsChainRatio()
                .groupSize(3).relativeIndexs(1, 2).startColumn("1").format("#.00%"))
            // 数字/日期格式化
            .numFmt("#,###.00", RoundingMode.HALF_UP, "total_amt")
            .dateFmt("yyyy-MM-dd", "order_month")
    );

    List rows = result.getRows();          // 规整计算后的最终结果集
    long executeTime = result.getExecuteTime(); // SQL 执行时长
}
```

> 树形汇总、分组拼接同理：`.treeSort(new TreeSort().idColumn("area_code").pidColumn("pid_area").sumColumns("sale_cnt").levelOrderColumn("sale_cnt").orderWay("desc"))`、`.groupConcat(new GroupConcat().group("organ_id").concat("staff_name").separator(",").distinct(true))`。
