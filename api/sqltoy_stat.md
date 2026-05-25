# sqltoy统计功能

## 提供行列转换、分组汇总、同比环比、树型排序汇总等

* 水果销售记录表

品类|销售月份|销售笔数|销售数量(吨)|销售金额(万元)
----|-------|-------|----------|------------
苹果|2019年5月|12 | 2000|2400
苹果|2019年4月|11 | 1900|2600
苹果|2019年3月|13 | 2000|2500
香蕉|2019年5月|10 | 2000|2000
香蕉|2019年4月|12 | 2400|2700
香蕉|2019年3月|13 | 2300|2700

### 1 行转列(列转行也支持)

```xml
<!-- 行转列 -->
<sql id="pivot_case">
	<value>
	<![CDATA[
	select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt 
	from sqltoy_fruit_order t
	order by t.fruit_name ,t.order_month
	]]>
	</value>
	<!-- 行转列,将order_month作为分类横向标题，从sale_count列到total_amt 三个指标旋转成行 -->
	<pivot start-column="sale_count" end-column="total_amt"	group-columns="fruit_name" category-columns="order_month" />
</sql>
```
* 效果

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
		<td>香蕉</td>
		<td>13</td>
		<td>2300</td>
		<td>2700</td>
		<td>12</td>
		<td>2400</td>
		<td>2700</td>
		<td>10</td>
		<td>2000</td>
		<td>2000</td>
	</tr>
		<tr>
		<td>苹果</td>
		<td>13</td>
		<td>2000</td>
		<td>2500</td>
		<td>11</td>
		<td>1900</td>
		<td>2600</td>
		<td>12</td>
		<td>2000</td>
		<td>2400</td>
	</tr>
	</tbody>
</table>


### 2 分组汇总、求平均(可任意层级)

```xml
<sql id="group_summary_case">
	<value>
		<![CDATA[
		select t.fruit_name,t.order_month,t.sale_count,t.sale_quantity,t.total_amt 
		from sqltoy_fruit_order t
		order by t.fruit_name ,t.order_month
		]]>
	</value>
	<!-- reverse 是否反向 -->	
	<summary columns="sale_count,sale_quantity,total_amt" reverse="true">
		<!-- 层级顺序保持从高到低 -->
		<global sum-label="总计" label-column="fruit_name" />
                <!-- order-column: 分组排序列(对同分组进行排序)，order-with-sum:默认为true，order-way:desc/asc -->
		<group group-column="fruit_name" sum-label="小计" label-column="fruit_name" />
	</summary>
</sql>
```

* 效果

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

### 3 先行转列再环比计算

```xml
<!-- 列与列环比演示 -->
<sql id="cols_relative_case">
	<value>
	<![CDATA[
		select t.fruit_name,t.order_month,t.sale_count,t.sale_amt,t.total_amt 
		from sqltoy_fruit_order t
		order by t.fruit_name ,t.order_month
	]]>
	</value>
	<!-- 数据旋转,行转列,将order_month 按列显示，每个月份下面有三个指标 -->
	<pivot start-column="sale_count" end-column="total_amt"	group-columns="fruit_name" category-columns="order_month" />
	<!-- 列与列之间进行环比计算 -->
	<cols-chain-relative group-size="3" relative-indexs="1,2" start-column="1" format="#.00%" />
</sql>
```

* 效果

<table>
<thead>
	<tr>
	<th rowspan="2" nowrap="nowrap">品类</th>
	<th colspan="5">2019年3月</th>
	<th colspan="5">2019年4月</th>
	<th colspan="5">2019年5月</th>
	</tr>
	<tr>
	    <th nowrap="nowrap">笔数</th><th nowrap="nowrap">数量</th><th nowrap="nowrap">比上月</th><th nowrap="nowrap">总金额</th><th nowrap="nowrap">比上月</th>
	    <th nowrap="nowrap">笔数</th><th nowrap="nowrap">数量</th><th nowrap="nowrap">比上月</th><th nowrap="nowrap">总金额</th><th nowrap="nowrap">比上月</th>
	    <th nowrap="nowrap">笔数</th><th nowrap="nowrap">数量</th><th nowrap="nowrap">比上月</th><th nowrap="nowrap">总金额</th><th nowrap="nowrap">比上月</th>
	</tr>
	</thead>
	<tbody>
	<tr>
		<td>香蕉</td>
		<td>13</td>
		<td>2300</td>
		<td></td>
		<td>2700</td>
		<td></td>
		<td>12</td>
		<td>2400</td>
		<td>4.30%</td>
		<td>2700</td>
		<td>0.00%</td>
		<td>10</td>
		<td>2000</td>
		<td>-16.70%</td>
		<td>2000</td>
		<td>-26.00%</td>
	</tr>
		<tr>
		<td>苹果</td>
		<td>13</td>
		<td>2000</td>
		<td></td>
		<td>2500</td>
		<td></td>
		<td>11</td>
		<td>1900</td>
		<td>-5.10%</td>
		<td>2600</td>
		<td>4.00%</td>
		<td>12</td>
		<td>2000</td>
		<td>5.20%</td>
		<td>2400</td>
		<td>-7.70%</td>
	</tr>
	</tbody>
</table>

### 4 树排序汇总

```xml
<!-- 树排序、汇总 -->
<sql id="treeTable_sort_sum">
	<value>
	<![CDATA[
	select t.area_code,t.pid_area,sale_cnt from sqltoy_area_sales t
	]]>
	</value>
	<!-- 组织树形上下归属结构，同时将底层节点值逐层汇总到父节点上，并且对同层级按照降序排列  -->
	<tree-sort id-column="area_code" pid-column="pid_area"	sum-columns="sale_cnt" level-order-column="sale_cnt" order-way="desc"/>
</sql>
```

* 效果

<table>
<thead>
	<tr>
	<th>地区</th>
	<th>归属地区</th>
	<th>销售量</th>
	</tr>
</thead>
<tbody>
	<tr>
	<td>上海</td>
	<td>中国</td>
	<td>300</td>
	</tr>
	<tr>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;松江</td>
	<td>上海</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;120</td>
	</tr>
 	<tr>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;杨浦</td>
	<td>上海</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;116</td>
	</tr>
 	<tr>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;浦东</td>
	<td>上海</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;64</td>
	</tr>
	<tr>
	<td>江苏</td>
	<td>中国</td>
	<td>270</td>
	</tr>
	<tr>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;南京</td>
	<td>江苏</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;110</td>
	</tr>
 	<tr>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;苏州</td>
	<td>江苏</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;90</td>
	</tr>
 	<tr>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;无锡</td>
	<td>江苏</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;70</td>
	</tr>
</tbody>
</table>
