# 配置化服务底座（报表 / 配置化 API 服务）

> `XMLBinding` 与 `parseSqlSegment` 注册能力自 sqltoy 6.0.x 提供。

sqltoy 的 **sqlId + 命名参数** 模式天然适合把查询做成配置：SQL 片段以 `<sql>` 形式**存进数据库（或配置中心、报表模型）**，运行期由框架动态解析执行。这一能力正是页面配置化报表、配置化 API 服务、低代码平台的底座——开发侧只需维护"配置"，接口按 id 取用，无需反复发版。

## 一、整体思路

配置侧：每条 SQL 配置携带**唯一 id** 与**最后修改时间**（用于缓存失效判断）。

执行侧：两种姿势，按配置变化频率选择：

| 姿势 | 适用场景 | 说明 |
| --- | --- | --- |
| `XMLBinding` 动态执行 | 配置频繁变化的查询 | 每次请求带 id + lastUpdateTime，框架按时间判断命中解析缓存，变化才重新解析 |
| `parseSqlSegment` + `putSqlToyConfig` 注册 | 相对稳定的查询 | 启动 / 变更时解析注册一次，后续 `lightDao.find(id, params)` 与静态 sqlId 完全一致 |

动态列：用 `@joinFields(:fields, default)` 让配置决定 `select` / `group by` / `order by` 的列（字段白名单校验 + 保留字按方言加引用符），详见[标签与表达式](../appendix/tags.md)。

## 二、配置存储示例（数据库）

```sql
create table report_sql_config (
    report_id   varchar(64)  primary key,
    sql_xml     text         not null,   -- 完整的 <sql>...</sql> 片段
    update_time datetime     not null
);
```

## 三、姿势一：XMLBinding 动态解析执行

```java
@Service
public class ReportService {

    @Autowired
    private LightDao lightDao;

    /** 从数据库 / 配置中心加载 SQL 配置片段 */
    private String loadSqlXml(String reportId) {
        // 例如：select sql_xml from report_sql_config where report_id = ?
        // 或从配置中心、报表模型读取
    }

    public List<Map> query(String reportId, LocalDateTime updateTime,
                           Map<String, Object> params) {
        String sqlXml = loadSqlXml(reportId);
        return lightDao.findByQuery(
                new QueryExecutor(new XMLBinding(sqlXml)
                        .id(reportId)
                        .lastUpdateTime(updateTime))  // 未变化时直接命中解析缓存
                .values(params)
                .resultType(Map.class))
            .getRows();
    }
}
```

**缓存规则（框架语义）：**

- 未带 `lastUpdateTime`：首次解析后一直走缓存；
- 带 `lastUpdateTime`：缓存为空、或时间比缓存新、或缓存本身无时间 → 重新解析；否则直接命中缓存，不重复解析。

## 四、姿势二：解析并注册，按 sqlId 复用

```java
public void registerReport(String reportId, String sqlXml) throws Exception {
    SqlToyConfig config = lightDao.getSqlToyContext().parseSqlSegment(sqlXml);
    // 一张报表可能含多个 sql 片段，用 reportId + "_" + index 保证唯一
    config.setId(reportId);
    lightDao.getSqlToyContext().putSqlToyConfig(config);
}

public List<Map> queryById(String reportId, Map<String, Object> params) {
    // 注册后与静态 sqlId 用法完全一致
    return lightDao.find(reportId, params);
}
```

> 注销不再使用的注册：`lightDao.getSqlToyContext().removeSql(reportId)`。

## 五、动态列：配置决定 select / group by / order by

```xml
<sql id="report_dynamic_columns">
    <value><![CDATA[
        select @joinFields(:fields, t.order_id)
        from sqltoy_order_info t
        #[and t.trans_date >= :startDate]
        #[and t.trans_date < :endDate]
        order by @joinFields(:orderFields, t.trans_date)
    ]]></value>
</sql>
```

```java
List rows = lightDao.findByQuery(
        new QueryExecutor("report_dynamic_columns")
            .names("fields", "orderFields", "startDate", "endDate")
            .values(
                "t.order_id,t.customer_name,t.total_amt",  // 纯标识符，逗号分隔
                "t.total_amt,t.trans_date",
                "2026-01-01", "2026-01-31")
            .resultType(Map.class))
        .getRows();
```

**注意：**

- `@joinFields` 只受理**纯标识符**（字段白名单：字母含中文、数字、下划线，最多三段点号）；`sum(t.total_amt)`、`t.*` 这类表达式请继续用 `@value`（安全自负）。
- 字段名可能命中保留字（`order` / `desc` / `level` / `group` 等）时，必须配置 `spring.sqltoy.reservedWords`，框架才会按方言加引用符（mysql 反引号、oracle/pg 双引号、sqlserver 方括号）。
- 排序方向建议固定写在 SQL 文本里；确需由配置决定方向时，用 `@value` 拼接并自行保证安全。

## 六、与报表 / 低代码平台的对接

- **一张报表多个 SQL 片段**：各自解析注册，`reportId + "_" + index` 唯一化后按序取数；
- **叠加能力**：配置片段里照常写 `<translate>` 缓存翻译、`<summary>` / `<pivot>` / `<link>` 等内存分析标签，无需额外代码；
- **分页**：`findPage` / `Page` 用法与静态 sqlId 完全一致。

## 相关

- [动态 SQL 编写规范](../query/dynamic_sql.md)（`#[]` 动态段、`@include`、`@joinFields` 所在体系）
- [标签与表达式](../appendix/tags.md)（`@joinFields`、`@value`、`@loop` / `@secure-loop` 等）
- [平台集成（报表 / 低代码）](../tools/integration.md)
