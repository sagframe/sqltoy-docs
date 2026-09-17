# 必杀集锦

增删改查、级联、跨库、分库分表等，sqltoy 与 hibernate/mybatis 并无太多差异。sqltoy 真正想分享的是**不同的思考方式**——下面这些"必杀技"是它在大量项目实践中沉淀出的高价值特性。

## 一、完美 SQL 写法

需求：查询订单表，条件包含交易日期范围、订单状态、机构、员工、订单号。

**mybatis 写法**（`<if>` 夹杂在 SQL 中，繁琐且易错）：

```xml
<select id="findOrder" resultType="OrderInfoVO">
    select * from sqltoy_order_info t
    <where>
        <if test="beginDate!=null"> and t.trans_date &gt;= #{beginDate} </if>
        <if test="endDate!=null"> and t.trans_date &lt;= #{endDate} </if>
        <if test="status!=null"> and t.status=#{status} </if>
        <if test="organId!=null"> and t.organ_id=#{organId} </if>
        <if test="staffCode!=null"> and t.staff_code=#{staffCode} </if>
        <if test="orderId!=null"> and t.order_id=#{orderId} </if>
    </where>
</select>
```

**sqltoy 写法**（SQL 整洁、可直接复制到客户端运行，参数为 null 自动剔除对应片段）：

```xml
<sql id="findOrder">
    <value><![CDATA[
        select * from sqltoy_order_info t
        where 1=1
        #[and t.trans_date>=:beginDate]
        #[and t.trans_date<=:endDate]
        #[and t.status=:status]
        #[and t.organ_id=:organId]
        #[and t.staff_code=:staffCode]
        #[and t.order_id=:orderId]
    ]]></value>
</sql>
```

一眼就能看明白业务含义，后期维护、优化、调整都更容易。详见[动态 SQL 编写规范](../query/dynamic_sql.md)。

## 二、快速分页与 count 优化

sqltoy 自动提供智能分页，开发者无需了解各数据库分页方言。其 count 查询**不是**简单粗暴的 `select count(1) from (你的sql) as t`，而是：

- 剔除不必要的 `order by`；
- 剔除 `select` 与 `from` 之间不必要的函数运算与无关信息；
- 充分辨别 `union` 与 `group` 类型查询。

配合 `@fast()`（先分页后关联）与 `<page-optimize>`（缓存 count），可让原本 2 次的分页查询降到约 **1.35 次**。详见[分页优化](../query/pagination.md)。

## 三、缓存翻译

把"码值→名称"的转换交给缓存，而不是写一堆 `left join`。没有缓存翻译时，多表关联的 SQL 又长又慢；用了缓存翻译，SQL 简洁清晰、效率几何级提升。详见[缓存翻译使用](../quickstart/translates.md)。

## 四、函数替换（跨库）

对象操作容易跨库，但**手写的 SQL** 呢？用 MySQL 写的 SQL 能直接跑在 Oracle/SQL Server 上吗？sqltoy 给了答案：在首次加载或动态执行时，**根据数据库类型自动替换 SQL 中的函数**（如 `nvl`/`ifnull`/`isnull`、`concat`、`to_char`、`date_format` 等）。详见[方言自适配与函数扩展](../dialect/sqltoy_function.md)。

## 五、防止 SQL 注入

很多人误解 SQL 注入原理，靠"过滤页面传来的参数值是否含 SQL 片段"来防护，南辕北辙。例如 `select * from table t where t.password=:password`，若把 password 变成 `(select password from table where id=xxx)` 就可能穿透这种检查。

sqltoy 从根本上杜绝：**SQL 参数最终全部转换成 `?` 形式，通过 `PreparedStatement` 设置参数值**，参数永远只会被当作"值"而非"SQL 片段"。

```text
-- 你写的：
select * from sqltoy_staff_info t where t.staff_name=:staffName
-- 实际执行：
select * from sqltoy_staff_info t where t.staff_name=?
```

此外还可用 `<valid-sqlInjection>` 过滤器对参数做注入校验（见[动态 SQL 编写规范](../query/dynamic_sql.md)）。

## 六、SQL 中可以加注释

sqltoy 坚持让开发者把在 DBeaver 等客户端写好的 SQL **直接 copy 到 xml**（修改时也可从 xml copy 回客户端调试），因此 SQL 可以保留注释：

- `--` 与 `/* */` 形式的注释在 SQL 加载时会被自动剔除；
- 但 `/*+ xxxx */` 形式的注释**不会被剔除**——这种通常作为数据库 hint 用于优化 SQL 性能。

---

> 更多实战写法见[常见 SQL 案例](../query/sql_showcase.md)与[补充说明：标签与表达式参考](../appendix/tags.md)。
