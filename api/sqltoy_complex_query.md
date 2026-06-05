# 复杂查询统计

## 一、 多维分组汇总（Summary）

### 1.1 应用场景

在财务报表或销售统计中，我们通常需要在表格底部或各分组末尾加上“小计”、“合计”或“平均值” 。

* **传统痛点**：使用 SQL 的 `GROUP BY ROLLUP` 语法不仅繁琐，且不同数据库（Oracle、MySQL、SQL Server）的方言差异极大，后期极难维护。
* 
**SqlToy 方案**：SQL 只管查出基础明细数据，由 SqlToy 在内存中通过高能算法自动完成多维汇总与平均值计算 。



### 1.2 XML 配置范例

```xml
<sql id="sys_sales_summary_report">
    <value>
        <![CDATA[
        select t.region_name, t.product_type, t.sales_cnt, t.sales_amt 
        from sys_sales_data t
        where t.status = 1
        #[and t.order_date >= :startDate]
        ]]>
    </value>
    <summary>
        <global-total label="总计" average-label="总平均"/>
        <group group-columns="region_name" label="小计" average-label="平均"/>
    </summary>
</sql>

```

---

## 二、 动态行转列（Pivot）

### 1.2 应用场景

将数据库中的“窄表”（多条行记录）转换成前端表格中展示的“宽表”（多列展示）。例如：将“月份、产品、销量”的行数据，转换为横向展开的“产品、1月销量、2月销量...12月销量” 。

* **传统痛点**：数据库的 `PIVOT` 语法无法直接应对“动态不固定列”，一旦月份或者产品类型是动态变化的，传统的纯 SQL 就会彻底失效。
* 
**SqlToy 方案**：结合核心算法，完美支持纯粹的动态集合行转列，只需几行声明即可搞定 。



### 2.2 XML 配置范例

```xml
<sql id="sys_product_sales_pivot">
    <value>
        <![CDATA[
        select t.product_name, t.sale_month, t.sale_count
        from sys_product_sales t
        where t.sale_year = :saleYear
        ]]>
    </value>
    <pivot category-columns="product_name" pivot-column="sale_month" start-column="sale_count"/>
</sql>

```

> 
> **💡 特殊场景提示**：如果是纯粹的集合行转列，在符合默认规整标准时，直接在配置中简写 `<pivot/>` 即可，无需配置冗长属性 。
> 
> 

---

## 三、 列转行（Unpivot）

### 3.1 应用场景

与 `Pivot` 相反，有时导入的 Excel 原始数据是宽表（如：学号、语文成绩、数学成绩、英语成绩），为了方便清洗、入库或进行细粒度分析，需要将其转换为窄表（学号、科目、成绩） 。

### 3.2 XML 配置范例

```xml
<sql id="sys_student_score_unpivot">
    <value>
        <![CDATA[
        select t.student_no, t.chinese_score, t.math_score, t.english_score
        from sys_student_score t
        ]]>
    </value>
    <unpivot unpivot-columns="chinese_score,math_score,english_score" 
             append-columns="subject_name, score_value"/>
</sql>

```

---

## 四、 行/列同比与环比计算

### 4.1 应用场景

在做数据分析看板（BI）时，纯粹展示销售额是不够的，往往需要展示**环比增长率**（本月比上月增长多少）或**同比增长率**（今年1月比去年1月增长多少） 。

* 
**SqlToy 方案**：提供了 `<cols-relative>`（列同环比）与 `<rows-relative>`（行同环比）标签，支持自动计算并输出百分比或千分比格式 。



### 4.2 列同环比配置（XML 示例）

主要针对单组内存在多个连续指标（如：1月销量、1月销售额、2月销量、2月销售额...）进行横向环比 。

```xml
<sql id="sales_cols_relative">
    <value><![CDATA[ select t.product_name, t.m1_amt, t.m2_amt, t.m3_amt from sales_table t ]]></value>
    <cols-relative group-size="1" 
                   relative-indexs="0" 
                   start-column="1" 
                   format="#.00%" 
                   multiply="100" 
                   reduce-one="true"/>
</sql>

```

### 4.3 行同环比配置（XML 示例）

主要针对多行记录（如：第1行是2026-01，第2行是2026-02）进行纵向同环比 。

```xml
<sql id="sales_rows_relative">
    <value><![CDATA[ select t.sale_date, t.sales_amt from sales_table t order by t.sale_date asc ]]></value>
    <rows-relative group-column="sale_date" 
                   relative-columns="sales_amt" 
                   format="#.00%" 
                   reduce-one="true" 
                   multiply="100" 
                   insert="true"/>
</sql>

```

🛠️ 关键属性解析 ：

* 
`format`：格式化输出，支持百分比 (`#.00%`)、千分比 (`#.00‰`) 。


* 
`reduce-one="true"`：是否减 1。减 1 表示显示**增长量/增长率**；若设置为 `false` 则代表直接显示数值的**对比基数** 。


* 
`insert="true"`：表示同环比的值会独立**新增一列**存放 。



---

## 五、 树形表结构排序与逐层汇总（Tree-Sort）

### 5.1 应用场景

在面对具有层级关系的树形表结构（如：公司组织架构、科目分类、行政区划）时，前端通常要求按照树的深度和血缘关系顺序排列（如：总公司 -> 华东分公司 -> 上海办事处 -> 华南分公司...），并且需要**上层节点自动汇总所有子孙节点的数据** 。

### 5.2 解决方案

SqlToy 支持在持久层通过辅助字段（如节点路径 `NODE_ROUTE`）快速跨库检索树形表 ，并可以通过配置极其强大的 `<tree-sort>` 标签，直接在内存中完成**树形重排**与**全级联逐层汇总（Sum）** ！

```xml
<sql id="sys_organ_tree_report">
    <value>
        <![CDATA[
        select t.organ_id, t.organ_pid, t.organ_name, t.budget_amt
        from sys_organ_info t
        ]]>
    </value>
    <tree-sort id-column="organ_id" 
               pid-column="organ_pid" 
               sum-columns="budget_amt" 
               sum-site="top"/>
</sql>

```

---

## 🚀 进阶：如何使用 Java 代码（QueryExecutor）实现？

很多开发者会问：**这些复杂统计功能必须写在 XML 里吗？** **答案是：不需要！** 

本质上，SqlToy 内部所有查询最终都会转化为 `QueryExecutor` 来执行 。上述所有动态处理规则（Filters 过滤、Translates 翻译、Summary 汇总、Pivot、同环比、脱敏等）全部可以在 Java 代码中动态构建和替代 ！

### Java 链式代码调用范例

```java
@Autowired
private LightDao lightDao; [cite_start]// 引入统一操作接口LightDao [cite: 200, 215]

public void getComplexReport() {
    Page<SalesVO> pageModel = new Page<>();
    
    // 利用 QueryExecutor 实现高灵活性查询
    QueryResult result = lightDao.findByQuery(
        new QueryExecutor("sys_sales_summary_report")
            .names("startDate")
            .values(LocalDate.now().minusMonths(3))
            [cite_start]// 1. 动态在代码中追加缓存翻译 [cite: 299]
            .translates(new Translate("productTypeCache").setColumn("product_type").setProp("productTypeName"))
            [cite_start]// 2. 动态进行数字/日期格式化 [cite: 299]
            .numFmt(new NumFmt("sales_amt", "#,###.00"))
            [cite_start]// 3. 动态追加安全数据脱敏 [cite: 299]
            .secureMask("customer_phone", SecureMask.PHONE)
    );
    
    List<SalesVO> rows = result.getRows(); [cite_start]// 获取规整计算后的最终结果集 [cite: 299]
    long executeTime = result.getExecuteTime(); [cite_start]// 监控SQL执行时长 [cite: 299]
}

```

---

1. **解放数据库压力**：像行列转换、树形逐层汇总等计算，如果直接交给数据库做，会产生巨额的 CPU 和内存开销。SqlToy 依托应用服务器内存进行单次线性处理，效率极高 。


2. **完美实现跨库适配**：由于同环比、树汇总的算法完全不依赖数据库方言，您的同一套 SQL 既能完美跑在 MySQL 8.0 上，也能平滑迁移到国产达梦（DM）、高斯（GaussDB）或 PostgreSQL 上 ！
