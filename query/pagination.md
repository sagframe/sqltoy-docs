# 分页优化

sqltoy 提供业界最完善的分页机制：**智能 count 优化、缓存分页、快速分页、并行分页**，并支持自定义 count SQL 与跳过 count。开发者无需关心各数据库的分页方言差异，sqltoy 自动适配。

## 一、基本分页 API

```java
// 1) Map 传参分页
Page<SysLog> page = lightDao.findPage(new Page(10, 1), "sys_log_find", paramsMap, SysLog.class);

// 2) QueryExecutor 灵活分页（可指定数据源、翻译、格式化、分页优化等）
QueryResult result = lightDao.findPageByQuery(new Page(10, 1),
        new QueryExecutor("sys_log_find").names("status").values(1).resultType(SysLog.class));

// 3) 单表实体分页
Page<SysLog> page2 = lightDao.findPageEntity(new Page(10, 1), SysLog.class,
        EntityQuery.create().where("status=:status").names("status").values(1));
```

> `Page` 构造为 `new Page(pageSize, pageNo)`，例如 `new Page(10, 1)` 表示每页 10 条、第 1 页。

`Page` 常用方法：

| 方法 | 说明 |
| --- | --- |
| `getRows()` | 当前页数据集合 |
| `getRecordCount()` | 总记录数 |
| `getPageNo()` / `getPageSize()` | 当前页号 / 每页条数 |
| `getTotalPage()` / `getLastPage()` | 总页数 / 末页号 |
| `getNextPage()` / `getPriorPage()` / `getFirstPage()` | 下一页 / 上一页 / 首页 |
| `getStartIndex()` / `getNextIndex()` / `getPreviousIndex()` | 起始/下一/上一索引 |
| `setSkipQueryCount(Boolean)` | 是否跳过总数查询（见第六节） |
| `setOverPageToFirst(Boolean)` | 翻页超出最大页时是否回到第一页 |

---

## 二、智能 count 优化（自动）

分页本质是两步查询：**① 查总记录数，② 查第几页数据**。其中 count 查询往往是大表分页的性能瓶颈。

sqltoy 的 count **不是**简单粗暴地 `select count(1) from (你的sql) as t`，而是智能改写：

- 根据 SQL 逻辑**剔除不必要的 `order by`**；
- 判断是否可以直接**切除原 SQL 中 `from` 之前的 `select` 列与函数运算**，替换为 `select count(1) from ...`，避免无谓的函数计算；
- 自动适配各数据库的分页方言（limit / rownum / offset fetch / top 等）。

绝大多数场景下，这套自动优化已能显著降低 count 开销，无需任何额外配置。

---

## 三、缓存分页（page-optimize）

对于**查询条件相同、被频繁翻页**的场景，每次翻页都重新 count 是浪费。`<page-optimize>` 通过缓存保留"相同查询条件 → count 结果"，在一定周期内翻页时直接复用 count，无需重复查询总数。

```xml
<sql id="sys_log_find">
    <!-- parallel:是否并行执行 count 与单页数据查询;
         alive-max:最多缓存多少组不同查询条件的 count; alive-seconds:缓存存活秒数 -->
    <page-optimize parallel="true" alive-max="100" alive-seconds="120" />
    <value><![CDATA[
        select t.* from sqltoy_staff_info t
        where t.STATUS=1
        #[and t.STAFF_NAME like :staffName]
        order by t.ENTRY_DATE desc
    ]]></value>
</sql>
```

`<page-optimize>` 属性：

| 属性 | 默认 | 说明 |
| --- | --- | --- |
| `parallel` | `false` | 是否并行执行 count 与结果查询以提升效率（`alive-max=1` 时关闭缓存优化） |
| `parallel-maxwait-seconds` | — | 并行查询最大等待秒数，避免执行过久 |
| `alive-max` | `100` | 最多缓存多少组不同查询条件对应的 count 记录 |
| `alive-seconds` | `90` | 每组查询条件及 count 在内存中的存活秒数，超时则重新查询 |
| `skip-zero-count` | `false` | 当 count 为 0 时是否自动重新获取 |

Java 中对应 `QueryExecutor.pageOptimize(PageOptimize)`：

```java
lightDao.findPageByQuery(new Page(10, 1),
        new QueryExecutor("sys_log_find").pageOptimize(new PageOptimize(100, 120)));
```

---

## 四、快速分页（@fast / @fastPage）

**先分页、后关联**：当主查询需要 join 其他表（尤其一对多）时，常规做法是先 join 出大结果集再分页，代价高昂。`@fast()` 用子查询包裹"决定结果集"的部分，**先按 pageSize 取出分页记录，再与其他表关联**，大幅减少关联数据规模。

```xml
<sql id="sys_log_findlist">
    <value><![CDATA[
        select t1.*,t2.ORGAN_NAME
        -- @fast() 先分页取 pageSize 条，再关联
        from @fast(
              select t.* from sqltoy_staff_info t
              where t.STATUS=1
                #[and t.STAFF_NAME like :staffName]
              order by t.ENTRY_DATE desc
             ) t1
        left join sqltoy_organ_info t2 on t1.organ_id=t2.ORGAN_ID
    ]]></value>
</sql>
```

要点：

- `@fast` 与 `@fastPage` **等效**。
- `@fast()` 写在 SQL 中即可，**非分页查询时框架会自动剔除 `@fast`**，因此不影响 find/findTop 等其他查询。
- 对 `findTop`、`findRandom`（getRandomResult）同样生效。
- 可配合提取 1..n 倍数据：如 `pageSize=10` 时取出 50 条再做行转列等二次计算。

---

## 五、并行分页（parallel）

在 `<page-optimize parallel="true">` 下，sqltoy 会**并行执行 count 查询与单页数据查询**，把原本串行的两步压缩为一步的耗时，适合 count 与数据查询都较重的场景。可用 `parallel-maxwait-seconds` 限制并行最大等待时长。

---

## 六、自定义 count-sql 与跳过 count

**自定义 count SQL**：极特殊场景下，可手写最优 count 语句：

```xml
<sql id="sys_log_find">
    <value><![CDATA[ select ... 复杂查询 ... ]]></value>
    <count-sql><![CDATA[ select count(1) from sqltoy_staff_info t where t.STATUS=1 ]]></count-sql>
</sql>
```

**跳过 count**：滚动加载、无限下拉等不需要总数的场景，可跳过 count 查询以提升性能：

```java
Page page = new Page(20, 1);
page.setSkipQueryCount(true);   // 不查询总记录数
Page result = lightDao.findPage(page, "sys_log_find", paramsMap, SysLog.class);
```

---

> 分页相关源码可参考 `org.sagacity.sqltoy.dialect.PageOptimizeUtils`（count 优化与快速分页引擎）与各数据库 `Dialect` 实现。
