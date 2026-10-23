# 动态 SQL 编写规范

sqltoy 的动态 SQL 设计目标：**让 SQL 保持整洁、可直接在数据库客户端运行**，同时把 mybatis 中夹杂在 SQL 里的 `<if>` 等动态逻辑剥离出来。

- SQL 可以写在 `*.sql.xml` 中（推荐，便于维护、支持热加载），也可以直接在 Java 代码中传入；条件查询还可用 [Lambda 条件体系](lambda_query.md)（6.0.8 起内置，原第三方 sqltoy-plus 已并入核心）。
- 简单场景直接用 `lightDao` 的显式接口；复杂场景用 `findByQuery`/`findPageByQuery` 配合 `QueryExecutor` 或 `EntityQuery` 组织参数。所有显式接口底层都基于 `QueryExecutor`，理解它即可灵活运用。

---

## 一、`#[]` 条件片段原理

sqltoy 用 `#[ ... ]` 标记一段**动态条件片段**，核心规则：

1. `#[ ... ]` 表示其中的条件是动态的；**必要条件不用加** `#[]`。
2. 片段内只要**有一个参数为 null（或空白）**，整个片段就被自动剔除。
3. 支持**多层嵌套**：`#[t.type=:type #[and t.amt>:amt and t.quantity>:quantity]]`。
   - **剔除规则逐层独立**：每一层 `#[...]` 只看自己这一层的直接参数。内层参数为 null 时仅剔除内层，外层与括号照常保留：

     ```sql
     where t.type=:type #[and (t.amt>:amt #[or t.qty>:qty])]
     -- amt=100、qty=null → where t.type=:type and (t.amt>:amt)
     -- amt=100、qty=5    → where t.type=:type and (t.amt>:amt or t.qty>:qty)
     ```

   - **外层的直接参数为 null 时，整个外层片段连同内层一起剔除**（内层参数有值也救不回）。因此嵌套天然表达**主从/层级条件**：外层是内层参与运算的前提。三层及以上同理，逐层递归：

     ```sql
     where #[t.a=:a #[and t.b=:b #[and t.c=:c]]]
     -- b 为 null → where t.a=?
     ```

   - **参数用法与单层完全一致**，以下形态在嵌套层内同样适用：命名参数 `:paramName`；数组下标取值，同一数组的元素可分别引用（如 `:starEndTime[0]` 与 `:starEndTime[1]` 组成时间区间）；元组多参数 `(t.tech_group,t.prod_group) in (:techGroups,:prodGroups)`；集合自动展开 `t.id in (:ids)`（数组/集合展开为多占位符）。同名参数可在多层重复出现，各层各自判空、互不影响。
   - **括号分组与多成员**：`and ( ... )` 括号组内的多个 `#[...]` 成员各自独立判空剔除（如 `#[and ( #[t.a=:a] or #[t.b=:b] )]`）——任一成员自身参数有值即保留该成员，全部为 null 时整组剔除；成员剔除后括号内残留的悬挂 `and`/`or` 连接符由框架自动清理（6.0.7 起，左括号后、右括号前的悬挂连接符一律剔除，`( order by ... )` 这类以 or 开头的合法关键字不受影响），无需手工规避。
4. 必要条件（未加 `#[]`）当参数为 null 时，会自动转成 `is null` / `is not null`。
5. sqltoy 默认隐藏了 `blank-to-null="true"`：空白字符串自动按 null 处理。
6. `#` 恰好是 MySQL 等数据库的注释符，所以**带 `#[]` 的 SQL 可以直接复制到客户端执行**，便于调试。

---

## 二、XML 形态

> [!TIP]
> `*.sql.xml` 的 XSD schema 指向与 IDE 补全配置见 [XML Schema 配置指引](../config/xml_schemas.md)。

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

`<sql>` 标签常用属性：`id`（必填）、`type`（`search`/`insert`/`update`/`delete`，`select` 为历史兼容写法）、`blank-to-null`（默认 `true`）、`debug`（是否输出执行日志）、`query-timeout`（查询超时秒数）、`dataSource`（指定数据源名称）、`dialect`（6.0.3 新增，声明本条 sql 按指定方言形态解析固化，详见[方言自适配与函数扩展](../dialect/sqltoy_function.md)）。

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

### 4.5 参数形态完整示例

一个 `<sql>` 浓缩 sqltoy 支持的全部参数形态（单值、集合展开、数组下标区间、元组多参数、层级嵌套、括号组），配合 filters 前置规整，构成"**查询条件与具体 SQL 分离**"的典型业务形态：

```xml
<!-- 1、条件值处理跟具体 sql 分离 -->
<!-- 2、条件值前置通过 filters 定义的通用方法加工规整（大多数不需要额外处理） -->
<sql id="show_case">
    <filters>
        <!-- 参数 statusAry 只要包含 -1（代表全部）则置 null，不参与条件检索 -->
        <eq params="statusAry" value="-1" />
    </filters>
    <value><![CDATA[
        select t.*
        from sqltoy_device_order_info t
        where #[t.status in (:statusAry)]                          -- 集合自动展开
        #[and t.ORDER_ID=:orderId]                                 -- 单值
        #[and t.ORGAN_ID in (:authedOrganIds)]                     -- 集合（数据权限）
        #[and t.STAFF_ID in (:staffIds)]                           -- 集合（多选）
        #[and t.TRANS_DATE>=:beginAndEndDate[0]]                   -- 数组下标取首
        #[and t.TRANS_DATE<:beginAndEndDate[1]]                    -- 数组下标取尾（时间区间）
        #[and (t.tech_group,t.prod_group) in (:techGroups,:prodGroups)] -- 元组多参数
        #[and t.staff_name like :staffName]                        -- 模糊匹配
        #[and t.creator_id=:xxxVo.creatorId]                       -- 对象属性点路径（单对象传参，见下）
        #[and t.priority=:priority #[and t.level>=:level]]         -- 层级嵌套：外层 null 内层一并剔除
        #[and ( #[t.order_id=:orderId2] or #[t.biz_no=:bizNo] )]   -- 括号组：成员独立判空，悬挂 or 自动清理
    ]]></value>
</sql>
```

**参数形态速查：**

| 形态 | 写法 | 说明 |
| --- | --- | --- |
| 单值 | `:orderId` | 绑定单个值 |
| 集合 / 数组展开 | `t.status in (:statusAry)` | 数组 / 集合自动展开为多个 `?` 占位符 |
| 数组下标 | `:beginAndEndDate[0]` / `:beginAndEndDate[1]` | 同一数组的元素分别引用，构造时间区间等 |
| 元组多参数 | `(t.tech_group,t.prod_group) in (:techGroups,:prodGroups)` | 两个集合按位置配对展开为 `(a1,b1),(a2,b2)` |
| 模糊匹配 | `t.staff_name like :staffName` | 可与 filters 的 `l-like` / `r-like` / `escapeLike` 组合 |
| 对象属性点路径 | `:xxxVo.creatorId` | **单对象传参**：values 只传一个 VO/Map 对象，SQL 参数名即对象属性名，框架反射取值；支持子对象属性级联 `xxxVo.name` 与 `a.b[index]`（大小写不敏感，对应 `BeanUtil.reflectBeanToAry` 语义，`updateByQuery` 等接口同样适用） |
| 层级嵌套 | `#[t.priority=:priority #[and t.level>=:level]]` | 每层独立判空，外层 null 时内层一并剔除 |
| 括号组 | `#[and ( #[t.order_id=:orderId2] or #[t.biz_no=:bizNo] )]` | 成员各自判空，全部为 null 时整组剔除，残留悬挂 `and`/`or` 自动清理 |

**Java 侧传参**（与 names 顺序一一对应，不需要的参数传 null 即可）：

```java
// 方式一：多值传参（names 与 values 一一对应）
List rows = lightDao.findByQuery(
        new QueryExecutor("show_case")
            .names("statusAry", "orderId", "authedOrganIds", "staffIds", "beginAndEndDate",
                   "techGroups", "prodGroups", "staffName", "priority", "level",
                   "orderId2", "bizNo")
            .values(
                    new Integer[] { 1, 2, -1 },        // statusAry：含 -1 → eq 置 null，该段剔除
                    "O0001",                            // orderId：单值
                    new String[] { "A01", "A02" },      // authedOrganIds
                    new String[] { "S001", "S002" },    // staffIds
                    new LocalDateTime[] { start, end }, // beginAndEndDate：区间
                    new String[] { "T001", "T002" },    // techGroups
                    new String[] { "P001", "P002" },    // prodGroups
                    "%张%",                             // staffName
                    1, 2,                               // priority、level（层级嵌套）
                    null, "BZ2026001")                  // orderId2=null → 括号组只保留 or 分支
            .resultType(OrderVO.class))
        .getRows();

// 方式二：单对象传参（参数名 = 对象名.属性名，:xxxVo.creatorId 走属性点路径）
StaffInfoVO xxxVo = new StaffInfoVO();
xxxVo.setCreatorId("U0001");   // 对应 #[and t.creator_id=:xxxVo.creatorId]
List rows2 = lightDao.findByQuery(
        new QueryExecutor("show_case")
            .names("xxxVo")     // 只传一个对象
            .values(xxxVo)
            .resultType(OrderVO.class))
        .getRows();
```

---

## 五、完整 `<sql>` 规范速查

下面罗列了一个 `<sql>` 元素**所有可用的子标签**（已对照 `sqltoy.xsd` 校验）。这是一份"功能全景"参考——**实际编写时按需选取即可，绝大多数 SQL 只需要 `<value>` 加少量标签**（见本节末尾的最小示例）。注意部分标签互斥（如 `pivot` 与 `unpivot`）。

```xml
<?xml version="1.0" encoding="utf-8"?>
<sqltoy xmlns="http://www.sagframe.com/schema/sqltoy"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy https://sagframe.github.io/schema/sqltoy.xsd">
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
        <!-- 常用：eq、to-date；针对性：cache-arg；兜底：primary -->
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

- `@if()`/`@elseif()`/`@else`、`@fast`、`@blank()`、`@value()`、`@loop()`/`@secure-loop()`、`@include(sqlId)`、`@include(:scriptParam)`、`@joinFields()`（字段名列表安全拼接，页面配置化报表用）、`@split()`（把字符串参数拆分成数组，配合 `in` 展开）等宏指令，见[补充说明：标签与表达式参考](../appendix/tags.md)。
- 更多实战写法（动态 `@include`、配置驱动 SQL 集成、慢 SQL 统计等）见[常见 SQL 案例](sql_showcase.md)。
- 查询 API（findOne/find/findPage/findTop/findRandom/getValue/isUnique 等）见[常规查询 API](sqltoy_query.md)。
