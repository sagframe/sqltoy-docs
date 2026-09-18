# 动态 SQL 编写规范

sqltoy 的动态 SQL 设计目标：**让 SQL 保持整洁、可直接在数据库客户端运行**，同时把 mybatis 中夹杂在 SQL 里的 `<if>` 等动态逻辑剥离出来。

- SQL 可以写在 `*.sql.xml` 中（推荐，便于维护、支持热加载），也可以直接在 Java 代码中传入，还支持第三方 lambda 插件（sqltoy-plus）。
- 简单场景直接用 `lightDao` 的显式接口；复杂场景用 `findByQuery`/`findPageByQuery` 配合 `QueryExecutor` 或 `EntityQuery` 组织参数。所有显式接口底层都基于 `QueryExecutor`，理解它即可灵活运用。

---

## 一、`#[]` 条件片段原理

sqltoy 用 `#[ ... ]` 标记一段**动态条件片段**，核心规则：

1. `#[ ... ]` 表示其中的条件是动态的；**必要条件不用加** `#[]`。
2. 片段内只要**有一个参数为 null（或空白）**，整个片段就被自动剔除。
3. 支持**多层嵌套**：`#[t.type=:type #[and t.amt>:amt and t.quantity>:quantity]]`。
4. 必要条件（未加 `#[]`）当参数为 null 时，会自动转成 `is null` / `is not null`。
5. sqltoy 默认隐藏了 `blank-to-null="true"`：空白字符串自动按 null 处理。
6. `#` 恰好是 MySQL 等数据库的注释符，所以**带 `#[]` 的 SQL 可以直接复制到客户端执行**，便于调试。

---

## 二、XML 形态

```xml
<!-- 默认即 blank-to-null="true"，等价于 <sql id="show_case" blank-to-null="true"> -->
<sql id="show_case">
    <filters>
        <!-- 通过 filters 对条件参数做前置规整处理 -->
        <eq params="status" value="-1" />
        <!-- 关闭 blank-to-null 的两种做法：
             1、blank-to-null="false"
             2、用 blank 标签对任意参数(包括不存在的)处理一次，即自动关闭默认设置 -->
        <blank params="anyParamNameIncludeNotExist"/>
    </filters>
    <value><![CDATA[
        select *
        from sqltoy_device_order_info t
        where
              -- orderType 为 null 时自动转成 t.order_type is null
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

`<sql>` 标签常用属性：`id`（必填）、`type`（`search`/`insert`/`update`/`delete`，`select` 为历史兼容写法）、`blank-to-null`（默认 `true`）、`debug`（是否输出执行日志）、`query-timeout`（查询超时秒数）、`dataSource`（指定数据源名称）。

---

## 三、Java 形态（XML 能做的代码里也能做）

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
        // .blankNotNull()  // 关闭 blank-to-null
        .where(whereString)
        .values(MapKit.keys("orderType", "authedOrganIds", "status", "orderId", "transDate")
                .values("PO", authedOrganIds, "1", "S0001", beginAndEndTime))
        .filters(new ParamsFilter("status").eq("-1")));
```

---

## 四、filters 参数过滤器完整参考

`<filters>` 用于在 SQL 执行前对条件参数做规整（转 null、类型转换、格式化、缓存反向匹配等），是 sqltoy 动态 SQL 的核心。Java 中对应 `ParamsFilter`，通过 `.filters(...)` 传入。

> **设计哲学——前置规整**：sqltoy 简洁之道的原理就在这里——通过 filters 在进入 SQL 前把条件参数修整到位，**保持对 SQL 内容体最小的干扰**。`#[]` 只保留"参数有值就拼进去"这一种本征形态，其余条件逻辑（置 null、格式化、拆分合并）全部前置到 filters 完成，SQL 因此能始终维持直观、简洁的原生结构。

### 4.1 转 null 类（满足条件则把参数置 null，从而剔除对应 `#[]` 片段）

| 标签 | 属性 | 说明 |
| --- | --- | --- |
| `<blank>` | `params`(默认`*`)、`excludes` | 参数为空白则转 null |
| `<eq>` | `params`、`value`、`excludes` | 参数等于给定值则转 null（数组中任一值匹配即转） |
| `<neq>` | `params`、`value` | 参数不等于给定值则转 null |
| `<gt>` / `<gte>` | `params`、`value` | 参数大于 / 大于等于给定值则转 null |
| `<lt>` / `<lte>` | `params`、`value` | 参数小于 / 小于等于给定值则转 null |
| `<between>` | `params`、`start-value`、`end-value`、`excludes` | 参数在区间内则转 null |

### 4.2 like 模糊查询处理

| 标签 | 属性 | 说明 |
| --- | --- | --- |
| `<l-like>` | `params`、`append-str` | 参数非空时右边补 `%`（即 `xxx%`） |
| `<r-like>` | `params`、`append-str` | 参数非空时左边补 `%`（即 `%xxx`） |
| `<escapeLike>` | `params` | 对 like 参数中的特殊符号转义 |

### 4.3 类型转换与格式化

| 标签 | 属性 | 说明 |
| --- | --- | --- |
| `<to-number>` | `params`、`data-type`(decimal/integer/double/float/long) | 参数转数字类型 |
| `<to-array>` | `params`、`data-type`(string/decimal/...) | 参数转数组（单值转为长度 1 的数组） |
| `<to-string>` | `params`、`add-quote`(none/single/double) | 参数转字符串，可加引号 |
| `<to-date>` | `params`、`format`、`type`、`increment-time`、`increment-unit` | 转日期；`format` 支持 `yyyy-MM-dd`、`FIRST_OF_MONTH`、`LAST_OF_YEAR`、`FIRST_OF_WEEK` 等；`increment-time` 可写 `${incrementDays}` 动态参数 |
| `<split>` | `params`、`split-sign`(默认`,`)、`data-type` | 把拼接字符串切割成数组（常用于 in 条件） |
| `<default>` | `params`、`value`、`data-type`、`split-sign`、`is-array` | 设置参数默认值，`value` 支持 `sysdate()-2d`、`first_of_month` 等表达式 |
| `<replace>` | `params`、`regex`、`value`、`is-first` | 对参数做正则替换 |
| `<to-in-arg>` | `params`、`single-quote`(默认true) | 将数组拼接成单个字符串作为 `in (:args)` 条件值 |
| `<remove-null>` | `params`、`remove-blank`(默认true) | 剔除数组/集合中为 null 或空白的值 |
| `<date-format>` | `params`、`format` | 对日期参数格式化（较少用） |

### 4.4 高级过滤器

| 标签 | 属性 | 说明 |
| --- | --- | --- |
| `<primary>` | `param`、`excludes` | **首要参数**：如订单编号有值时表示精准查询，除 `excludes` 排除的权限条件外，其他条件不再参与过滤 |
| `<exclusive>` | `param`、`set-params`、`compare-type`、`compare-values`、`set-value` | 互斥参数处理 |
| `<clone>` | `param`、`as-param` | 复制一个参数的值另存为另一个参数 |
| `<cache-arg>` | `param`、`cache-name`、`cache-key-index`、`cache-mapping-indexes`、`cache-mapping-max`、`alias-name`、`unmatched-return-self` 等 | **缓存反向匹配**：用名称匹配出对应代码数组（如输入"张明"匹配出包含该姓名的工号数组）再参与查询，替代低效 like。可含 `<filter cache-index compare-param compare-type split-sign>` 子标签 |
| `<custom-handler>` | `params`、`type` | 自定义数据处理器 |
| `<valid-sqlInjection>` | `params`、`level`(STRICT_WORD/RELAXED_WORD/SQL_KEYWORD) | SQL 注入参数校验 |

> **缓存反向匹配（cache-arg）** 是 sqltoy 的特色能力，详见[缓存翻译使用](../quickstart/translates.md)与[超大规模主数据缓存](../translate/sqltoy_FIFO_translate.md)。

---

## 五、完整 `<sql>` 规范速查

下面罗列了一个 `<sql>` 元素**所有可用的子标签**（已对照 `sqltoy.xsd` 校验）。这是一份"功能全景"参考——**实际编写时按需选取即可，绝大多数 SQL 只需要 `<value>` 加少量标签**（见本节末尾的最小示例）。注意部分标签互斥（如 `pivot` 与 `unpivot`）。

```xml
<?xml version="1.0" encoding="utf-8"?>
<sqltoy xmlns="http://www.sagframe.com/schema/sqltoy"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy http://www.sagframe.com/schema/sqltoy/sqltoy.xsd">
<!--
  id: 建议 moduleName+functionName 命名，避免不同模块重复
  type: search/insert/update/delete（select 为历史兼容写法，等同 search）
  debug: 是否输出该 sql 执行日志（默认取全局 debug 值）
  blank-to-null: 空白字符串是否转 null，默认 true；filters 中一旦出现 <blank params="具体参数"/> 即自动关闭默认
  query-timeout: 单条 sql 的 statement 超时时长（秒）
  dataSource: 指定数据源名称（特殊场景）
-->
<sql id="sqltoy_sql_specs" type="search" debug="false" blank-to-null="true">
    <!-- sql 功能说明，便于阅读维护，不参与执行，须配合 <value> 使用 -->
    <remarks>员工信息查询演示</remarks>

    <!-- ===== filters：对参与查询/执行的参数值做规整处理（详见本页第四节）===== -->
    <filters>
        <!-- 最常用：eq、to-date；精妙：cache-arg；强大：primary -->
        <!-- 参数等于给定值则转 null（如下拉框"全部"传 -1 时不过滤该条件） -->
        <eq params="organType" value="-1" />
        <!-- 转日期：format 可为 yyyy-MM-dd 等自定义格式，或 FIRST_OF_MONTH/LAST_OF_MONTH/FIRST_OF_YEAR/LAST_OF_YEAR/FIRST_OF_WEEK/LAST_OF_WEEK；
             increment-time 加减时间，increment-unit 默认 days -->
        <to-date params="beginDate" format="yyyy-MM-dd" increment-time="1" increment-unit="days"/>
        <!-- 复制参数值另存为新参数（常与 to-date 配合，由单日期构造日期范围） -->
        <clone param="beginDate" as-param="endDate"/>
        <to-number params="amt" data-type="decimal" />
        <!-- 转字符串，add-quote: none/single/double -->
        <to-string params="staffName" add-quote="single" />
        <!-- 对 like 参数中的特殊符号转义 -->
        <escapeLike params="staffName"/>
        <!-- 左边/右边补 %（参数已含 % 则不处理） -->
        <l-like params="staffName"/>
        <r-like params="staffName"/>
        <!-- 缓存反向匹配：用名称 like 匹配出对应编码作为条件，实现精准查询 -->
        <cache-arg param="staffName" cache-name="staffCache" alias-name="staffIds" prior-match-equal="false">
            <!-- 对缓存做过滤，如个人授权机构、生效状态等；cache-index 对应缓存第几列 -->
            <filter compare-param="1" cache-index="4"/>
        </cache-arg>
        <!-- 首要参数：如精准输入订单编号时，除 excludes 排除的权限条件外其他条件全部置 null -->
        <primary param="orderId" excludes="organIds" />
        <!-- 将数组拼接成 in 条件字符串并加单引号 -->
        <to-in-arg params="organIds" />
        <!-- 日期格式化为字符串（可结合 to-number 得到 202112 这类数字月份） -->
        <date-format params="bizMonth" format="yyyyMM"/>
        <!-- 空白转 null（默认所有空白自动转 null，一般无需配置） -->
        <blank params="*" excludes="staffName" />
        <!-- 区间/大小比较满足则转 null -->
        <between params="amt" start-value="0" end-value="9999" excludes="" />
        <lte params="" value="" />
        <lt params="" value="" />
        <gte params="" value="" />
        <gt params="" value="" />
        <!-- 剔除数组/集合中的 null 或空白 -->
        <remove-null params="organIds" remove-blank="true"/>
        <!-- 字符替换（默认正则全部替换，is-first=true 只替换首个） -->
        <replace params="" regex="" value="" is-first="false" />
        <!-- 默认值：sysdate()-1d（d天/h小时/w周/m月/y年）；first_of_month-3d/first_of_year/last_of_month... -->
        <default params="beginDate" data-type="localDate" value="sysdate()-1d" />
        <!-- 排他参数：某参数为特定值时，将其他参数设为特定值 -->
        <exclusive param="" compare-type="eq" compare-values="" set-params="" set-value="" />
        <!-- 自定义参数处理器（实现 FilterHandler，经 spring.sqltoy.customFilterHandler 配置） -->
        <custom-handler params="" type=""/>
    </filters>

    <!-- ===== 缓存翻译：码值→名称，支持 A,B 拼接翻译（split-sign/link-sign）===== -->
    <!-- uncached-template 未匹配时的补充显示，${value} 表示原 key 值，如 [${value}未定义] -->
    <translate cache="dictCache" cache-type="POST_TYPE" columns="POST_TYPE" cache-indexs="1" uncached-template="" />

    <!-- ===== 安全：脱敏与解密 ===== -->
    <!-- 脱敏 type: tel/name/id-card/bank-card/address/email/public-account/discrete-rate/other -->
    <secure-mask columns="telNo" type="tel" head-size="3" tail-size="4" mask-code="*" mask-rate="50" />
    <!-- 对加密存储的字段查询时解密 -->
    <secure-decrypt columns="idCard"/>

    <!-- ===== 分库分表 ===== -->
    <sharding-datasource strategy="multiDataBase" />
    <sharding-table tables="sys_order" strategy="hisRealTable" params="beginDate" />

    <!-- ===== 分页优化：缓存相同条件的 count 结果 ===== -->
    <!-- alive-max: 同一 sql 保留多少组不同条件的 count；alive-seconds: 存活秒数；parallel: 是否并行 count 与数据查询 -->
    <page-optimize alive-max="100" alive-seconds="600" parallel="false" />

    <!-- ===== 结果集格式化 ===== -->
    <date-format columns="createTime" format="yyyy-MM-dd HH:mm:ss" />
    <!-- 数字格式：#,###.00、capital(中文大写)、capital-rmb(大写金额)、capital-en；可配 rounding-mode/locale/currency -->
    <number-format columns="totalAmt" format="capital-rmb" />

    <!-- ===== 树形排序、层级内排序、逐层汇总 ===== -->
    <tree-sort id-column="organ_id" pid-column="organ_pid" sum-columns="staff_cnt" level-order-column="staff_cnt" order-way="desc">
        <!-- 状态为 0 的不参与汇总 -->
        <sum-filter column="status" compare-type="neq" compare-values="0"/>
    </tree-sort>

    <!-- ===== SQL 正文（必填）===== -->
    <value>
    <![CDATA[
    -- sql 中可以直接写注释
    select t1.*,t2.ORGAN_NAME from
    @fast(select * from sys_staff_info t
          where #[t.sexType=:sexType]
            #[and t.JOIN_DATE>:beginDate]
            #[and t.STAFF_NAME like :staffName]
            -- @if() 做逻辑判断
            #[@if(:isVirtual==true||:isVirtual==0) and t.IS_VIRTUAL=1]
          ) t1,sys_organ_info t2
     where t1.ORGAN_ID=t2.ORGAN_ID
    ]]>
    </value>

    <!-- 自定义 count 语句（仅分页有效；sqltoy 已智能优化 count，极端性能场景才需手写） -->
    <count-sql><![CDATA[]]></count-sql>

    <!-- ===== 结果集分析算法 ===== -->
    <!-- 分组汇总/求平均 -->
    <summary sum-columns="staff_cnt" average-columns="amt" average-radix-sizes="2" reverse="false" sum-site="left" average-skip-null="false">
        <global sum-label="总计" label-column="organ_name" />
        <!-- order-column 分组排序列，order-with-sum 默认 true，order-way desc/asc -->
        <group sum-label="小计" label-column="organ_name" group-column="organ_id" order-column="staff_cnt"/>
    </summary>
    <!-- 分组拼接（代替 group_concat/WM_CONCAT）：id-columns 分组列，columns 被拼接列(必填)，result-type 可为 ARRAY/LIST/SET -->
    <link id-columns="organ_id" columns="staff_name" sign="," distinct="true"/>
    <!-- 行转列（与 unpivot 互斥） -->
    <pivot category-columns="order_month" group-columns="fruit_name" start-column="sale_count" end-column="total_amt" default-value="0" />
    <!-- 列转行：columns-to-rows 格式 "列:名称,列:名称" -->
    <unpivot columns-to-rows="chinese_score:语文,math_score:数学" new-columns-labels="subject_name,score_value" />
    <!-- 列环比（水平同类列比较）：group-size 每组指标数，relative-indexs 参与比较的指标序号，start-column 起始列 -->
    <cols-chain-relative group-size="3" relative-indexs="1,2" start-column="1" format="#.00%" />
    <!-- 行环比（垂直行间比较）：group-column 分组列，relative-columns 参与比较的列 -->
    <rows-chain-relative group-column="sale_date" relative-columns="sales_amt" format="#.00%" reduce-one="true" multiply="100" insert="true" />
</sql>
</sqltoy>
```

### 子标签速查表

| 子标签 | 作用 | 详见 |
| --- | --- | --- |
| `<remarks>` | sql 功能说明（不执行） | 本页 |
| `<filters>` | 条件参数规整（转 null / 类型转换 / 缓存反向匹配等） | 本页第四节 |
| `<translate>` | 缓存翻译（码值→名称） | [缓存翻译使用](../quickstart/translates.md) |
| `<secure-mask>` / `<secure-decrypt>` | 结果集脱敏 / 字段解密 | [数据脱敏与加解密](../enterprise/sqltoy_security.md) |
| `<sharding-datasource>` / `<sharding-table>` | 分库 / 分表策略 | [分库分表](../enterprise/sqltoy_sharding.md) |
| `<page-optimize>` / `<count-sql>` | 分页 count 缓存优化 / 自定义 count | [分页优化](pagination.md) |
| `<date-format>` / `<number-format>` | 结果集日期 / 数字格式化 | 本页 |
| `<summary>` | 分组汇总 / 求平均 | [复杂查询与数据分析](sqltoy_complex_query.md) |
| `<pivot>` / `<unpivot>` | 行转列 / 列转行 | [复杂查询与数据分析](sqltoy_complex_query.md) |
| `<cols-chain-relative>` / `<rows-chain-relative>` | 列 / 行同比环比 | [复杂查询与数据分析](sqltoy_complex_query.md) |
| `<tree-sort>` | 树形排序与逐层汇总 | [复杂查询与数据分析](sqltoy_complex_query.md) |
| `<link>` | 分组拼接（代替 group_concat） | [复杂查询与数据分析](sqltoy_complex_query.md) |
| `<value>` | SQL 正文（必填），支持 `#[]`、`@if`、`@fast` 等 | 本页 / [标签参考](../appendix/tags.md) |

### 常规最小示例

别被上面的"全景"吓到——日常 SQL 通常就这么简单。例如页面有一个性别下拉框，"全部"选项 `value="-1"`，用 `eq` 过滤器把 `-1` 转成 null，该条件即自动不参与查询：

```html
<select name="sexType">
    <option value="-1">全部</option>
    <option value="F">女性</option>
    <option value="M">男性</option>
</select>
```

```xml
<sql id="sys_staff_find">
    <filters>
        <!-- sexType=-1（全部）时转 null，#[and t.sex_type=:sexType] 整段被剔除 -->
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

## 六、相关高级语法

- `@if()`/`@elseif()`/`@else`、`@fast`、`@blank()`、`@value()`、`@loop()`/`@secure-loop()`、`@include(sqlId)`、`@include(:scriptParam)` 等宏指令，见[补充说明：标签与表达式参考](../appendix/tags.md)。
- 更多实战写法（动态 `@include`、配置驱动 SQL 集成、慢 SQL 统计等）见[常见 SQL 案例](sql_showcase.md)。
- 查询 API（findOne/find/findPage/findTop/findRandom/getValue/isUnique 等）见[常规查询 API](sqltoy_query.md)。
