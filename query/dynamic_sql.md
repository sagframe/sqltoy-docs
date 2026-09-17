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

## 五、相关高级语法

- `@if()`/`@elseif()`/`@else`、`@fast`、`@blank()`、`@value()`、`@loop()`/`@secure-loop()`、`@include(sqlId)`、`@include(:scriptParam)` 等宏指令，见[补充说明：标签与表达式参考](../appendix/tags.md)。
- 更多实战写法（动态 `@include`、配置驱动 SQL 集成、慢 SQL 统计等）见[常见 SQL 案例](sql_showcase.md)。
- 查询 API（findOne/find/findPage/findTop/findRandom/getValue/isUnique 等）见[常规查询 API](sqltoy_query.md)。
