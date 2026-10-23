# Elasticsearch 支持

sqltoy 集成 Elasticsearch 的出发点（同样适用于 MongoDB）：

1. 充分发挥 sqltoy **动态条件组织**的优势；
2. 结合 sqltoy 的**缓存翻译**，解决 ES 关联配置表的复杂性（或 ETL 清洗的复杂性）；
3. 利用 sqltoy 提供的**结果集算法**（脱敏、格式化、旋转、分组汇总等），简化直接写查询/聚合的复杂度；
4. 便于与外部低代码框架（如报表平台）集成，实现配置化数据查询与处理。

> 演示项目：https://github.com/sagframe/sqltoy-showcase

## 一、配置 ES 节点

基于 spring-boot-starter，在 `application.yml` 中配置 `spring.sqltoy.elastic`（支持多节点/多集群）：

```yaml
spring:
  sqltoy:
    elastic:
      # 默认节点 id（不设置则取第一个）
      defaultId: default
      endpoints[0]:
        id: default
        # 集群多个节点用逗号分隔
        url: http://192.168.56.101:9200
        username: elastic
        password: skyline
        # sql 查询路径，见下方说明
        sqlPath: _nlpcn/sql
        # ===== 以下为 https/证书场景的可选项 =====
        #keyStore: 证书文件路径
        #keyStorePass: 证书密码
        #keyStoreType: jks          # 默认 jks，可不设置
        #keyStoreSelfSign: true     # 是否自签名证书，默认 true
        #authCaching: true          # 是否禁止抢占式身份认证，默认 true
```

`sqlPath`（SQL 模式的查询端点）可选值：

| sqlPath | 说明 |
| --- | --- |
| `_sql`（即 `_xpack/sql`） | ES 原生 SQL，**已支持 cursor 游标模式分页** |
| `_nlpcn/sql` | [elasticsearch-sql](https://github.com/NLPchina/elasticsearch-sql) 插件（推荐，支持分页） |
| `_opendistro/_sql` | AWS opendistro SQL 插件 |

> ES 原生 SQL 早期不支持分页，**现已支持通过 cursor 游标模式分页**，可直接使用 `_sql`。elasticsearch-sql（`_nlpcn/sql`）、opendistro（`_opendistro/_sql`）插件仍可作为备选；其中 elasticsearch-sql 在 7.9.3 之后停止维护，可改用 AWS opendistro 插件。

## 二、编写 eql 查询

ES 查询用 `<eql>` 标签定义，支持两种模式：`mode="sql"`（SQL 模式）与原生 JSON REST 模式（不写 mode）。

### 2.1 SQL 模式

```xml
<eql id="es_find_company" fields="company_id,company_name,company_type" mode="sql">
    <value><![CDATA[
        select * from cc_company_info
        where 1=1
           #[@if(:flag==1) and company_name=:companyName]
           #[@else  and company_type<>:companyType ]
    ]]></value>
</eql>

<!-- 分页查询（ES 原生 SQL 已支持 cursor 游标分页，也可用 elasticsearch-sql 插件） -->
<eql id="es_find_company_page" fields="company_id,company_name,company_type" mode="sql">
    <value><![CDATA[
        select * from cc_company_info
        where company_name like :companyName and company_type<>:companyType
    ]]></value>
</eql>
```

### 2.2 原生 JSON REST 模式

不写 `mode` 即为原生 JSON 模式。此时动态条件用 `<#> ... </#>` 包裹（替代 SQL 模式的 `#[]`），参数用 `@(:paramName)` 引用：

```xml
<!-- fields 属性 与 查询体中的 _source 二选一:两者都没有时结果映射报错
     (collection or property name array is empty) -->
<eql id="sys_elastic_test_json" fields="company_id,company_name,company_type" index="cc_company_info">
    <!-- 依然可以使用 translate 缓存翻译，column 对应 _source 中定义的字段 -->
    <value><![CDATA[
        {
            "_source": ["company_id","company_name","company_type"],
            "query": {
                "bool": {
                    "filter": [
                        <#>{"terms":{"company_type":@(:companyTypes)}}</#>
                    ]
                }
            }
        }
    ]]></value>
</eql>
```

### 2.3 eql 标签属性

| 属性 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 查询唯一标识 |
| `fields` | 条件必填 | 最终 ES 返回 JSON 中需要提取的属性名。**与查询体中的 `_source` 二选一**（实测验证）：两者都不提供时触发 `collection or property name array is empty`（属性名数组为空）异常 |
| `mode` | 否 | `sql`（SQL 模式）或 `original`（原生 JSON），缺省为原生 JSON |
| `index` | 否 | 索引名（JSON 模式常用） |
| `end-point` | 否 | 对应配置中的 endpoint id，缺省取第一个 |
| `aggregate` | 否 | 是否聚合查询，默认 `false` |
| `blank-to-null` | 否 | 空白参数转 null，默认 `true` |
| `value-root` / `type` | 否 | JSON 结果根路径 / 类型 |

`<eql>` 内还可使用 `filters`、`translate`（缓存翻译）、`secure-mask`（脱敏）、`pivot`/`unpivot`/`summary`（结果集算法）、`page-optimize`（分页优化）等子标签，与 SQL 查询一致。

## 三、Java 调用

通过 `lightDao.elastic()` 链式调用（`sql` 传 eql 的 id）：

```java
// 普通查询（SQL 模式）
List<CompanyInfoVO> result = (List<CompanyInfoVO>) lightDao.elastic()
        .sql("es_find_company")
        .values(MapKit.keys("companyName", "companyType", "flag").values("浙江华旭", "3", 2))
        .resultType(CompanyInfoVO.class)
        .find();

// 分页查询（ES 原生 SQL 已支持 cursor 游标分页）
Page page = (Page) lightDao.elastic()
        .sql("es_find_company_page")
        .values(MapKit.keys("companyName", "companyType", "flag").values("浙江华旭", "3", 2))
        .resultType(CompanyInfoVO.class)
        .findPage(new Page());

// 取 Top N
List top = lightDao.elastic().sql("es_find_company_page")
        .values(...).resultType(CompanyInfoVO.class).findTop(10);

// 原生 JSON 模式查询（参数为数组）
List<CompanyInfoVO> jsonResult = (List<CompanyInfoVO>) lightDao.elastic()
        .sql("sys_elastic_test_json")
        .names("companyTypes").values(new Object[]{ new Object[]{ "1", "2" } })
        .resultType(CompanyInfoVO.class)
        .find();
```

`elastic()` 链式可设置：`sql`、`names`、`values`、`entity`、`endPoint`、`resultType`、`humpMapLabel`；终止方法：`find()`、`getOne()`、`findTop(int)`、`findPage(Page)`。

## 四、注意事项

- **分页**：ES 原生 SQL 已支持 cursor 游标模式分页；elasticsearch-sql / opendistro 插件亦支持，可按需选择 `sqlPath`。
- 多集群/多节点通过配置多个 `endpoints[n]` 实现，查询时可用 `end-point` 属性或 `.endPoint(id)` 指定。
- 纯 CRUD 建议直接用 ES 官方客户端；sqltoy 的价值在于**动态条件 + 缓存翻译 + 结果集算法**的组合。

## 五、接入注意事项（实测）

1. **endpoint 的 `id` 必填**：`endpoints[0].id` 缺省不写会在 `SqlToyContext` 初始化时报 `getId()` 为 null 的 NPE，务必为每个 endpoint 显式设置 id（或配置 `default-id`）。
2. **依赖**：sqltoy 的 ES 客户端（Rest5Client）基于 Apache HttpClient 5，项目需显式引入 `org.apache.httpcomponents.client5:httpclient5`（sqltoy 未传递该依赖）。
3. **`fields` 或 `_source` 必须提供其一**：见 2.3 属性表说明——两者都缺时结果映射报 `collection or property name array is empty`。
4. **JSON 库可插拔**：ES 插件栈与 JSON 列共用同一套 JsonProvider 抽象，按 classpath 自动探测 fastjson2 -> jackson3 -> jackson2；探测到的库还要通过一次冒烟解析才被采纳，不可用（如 jackson3 遇到过旧的 jackson-annotations）则告警并降级到下一个候选。也可用 `spring.sqltoy.jsonProvider` 显式指定，取值为内置别名 `fastjson2` / `jackson3` / `jackson2` 或自定义实现的全限定类名；皆不可用时启动仅告警、触及 JSON/ES 功能才报错。

> 完整可运行示例：`sqltoy-showcase` 的 `NoSqlTest`（Testcontainers 起真实 ES 容器，`<eql>` json 模式动态查询实测）。

## 六、安全连接（认证与 TLS）

生产环境的 ES 通常开启安全（认证 + TLS）。sqltoy 的 endpoint 支持完整的连接安全配置：

```yaml
spring:
  sqltoy:
    elastic:
      endpoints[0]:
        id: prod
        url: https://es.prod.internal:9200
        # Basic 认证
        username: elastic
        password: ${ES_PASSWORD}
        # TLS:信任的证书库(自签证书场景)
        key-store: classpath:certs/es-truststore.p12
        key-store-pass: ${ES_TRUSTSTORE_PASS}
        key-store-type: PKCS12
        key-store-self-sign: true   # 自签证书
        # 认证缓存(默认开启,避免每次请求重复认证)
        auth-caching: true
```

> 完整属性见 `ElasticEndpoint`（id/url/username/password/keyStore*/requestTimeout 等）。演示项目 `NoSqlTest` 出于零门槛用了无安全容器（`xpack.security.enabled=false`），生产配置以上述为准。

