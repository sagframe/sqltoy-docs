# Elasticsearch

sqltoy's motivation for integrating Elasticsearch (equally applicable to MongoDB):

1. To fully leverage sqltoy's strength in **organizing dynamic conditions**;
2. Combined with sqltoy's **Cache Translate**, it eliminates the complexity of joining configuration collections in ES (or the complexity of ETL cleansing);
3. It makes use of sqltoy's **result-set algorithms** (data masking, formatting, pivot, group summary, etc.) to simplify writing queries/aggregations directly;
4. It facilitates integration with external low-code frameworks (such as reporting platforms), enabling configuration-driven data query and processing.

> Demo project: https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-nosql

## 1. Configuring ES Nodes

Based on the spring-boot-starter, configure `spring.sqltoy.elastic` in `application.yml` (multiple nodes/clusters are supported):

```yaml
spring:
  sqltoy:
    elastic:
      # Default endpoint id (the first one is used if not set)
      defaultId: default
      endpoints[0]:
        id: default
        # Multiple cluster nodes are comma-separated
        url: http://192.168.56.101:9200
        username: elastic
        password: skyline
        # SQL query path, see the notes below
        sqlPath: _nlpcn/sql
        # ===== The following are optional settings for https/certificate scenarios =====
        #keyStore: path to the certificate file
        #keyStorePass: certificate password
        #keyStoreType: jks          # defaults to jks; can be omitted
        #keyStoreSelfSign: true     # whether the certificate is self-signed, defaults to true
        #authCaching: true          # whether to disable preemptive authentication, defaults to true
```

Available values for `sqlPath` (the query endpoint in SQL mode):

| sqlPath | Description |
| --- | --- |
| `_sql` (i.e. `_xpack/sql`) | ES native SQL, **now supports cursor-based pagination** |
| `_nlpcn/sql` | The [elasticsearch-sql](https://github.com/NLPchina/elasticsearch-sql) plugin (recommended, supports pagination) |
| `_opendistro/_sql` | The AWS OpenDistro SQL plugin |

> ES native SQL did not support pagination in early versions but **now supports cursor-based pagination**, so `_sql` can be used directly. The elasticsearch-sql (`_nlpcn/sql`) and OpenDistro (`_opendistro/_sql`) plugins remain viable alternatives; note that elasticsearch-sql is no longer maintained after 7.9.3, in which case the AWS OpenDistro plugin can be used instead.

## 2. Writing eql Queries

ES queries are defined with the `<eql>` tag; two modes are supported: `mode="sql"` (SQL mode) and the native JSON REST mode (no `mode` attribute).

### 2.1 SQL Mode

```xml
<eql id="es_find_company" fields="company_id,company_name,company_type" mode="sql">
    <value><![CDATA[
        select * from cc_company_info
        where 1=1
           #[@if(:flag==1) and company_name=:companyName]
           #[@else  and company_type<>:companyType ]
    ]]></value>
</eql>

<!-- Pagination query (ES native SQL already supports cursor-based pagination;
     the elasticsearch-sql plugin also works) -->
<eql id="es_find_company_page" fields="company_id,company_name,company_type" mode="sql">
    <value><![CDATA[
        select * from cc_company_info
        where company_name like :companyName and company_type<>:companyType
    ]]></value>
</eql>
```

### 2.2 Native JSON REST Mode

Omitting `mode` gives the native JSON mode. Dynamic conditions are then wrapped with `<#> ... </#>` (instead of the `#[]` used in SQL mode), and parameters are referenced with `@(:paramName)`:

```xml
<!-- The fields attribute can be left empty when _source already provides the fields -->
<eql id="sys_elastic_test_json" fields="" index="cc_company_info">
    <!-- translate (Cache Translate) still works; column refers to the fields defined in _source -->
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

### 2.3 eql Tag Attributes

| Attribute | Required | Description |
| --- | --- | --- |
| `id` | Yes | Unique identifier of the query |
| `fields` | Yes | Property names to extract from the JSON finally returned by ES (can be left empty in JSON mode if `_source` already contains the fields) |
| `mode` | No | `sql` (SQL mode) or `original` (native JSON); defaults to native JSON |
| `index` | No | Index name (commonly used in JSON mode) |
| `end-point` | No | The endpoint id defined in the configuration; defaults to the first one |
| `aggregate` | No | Whether it is an aggregation query; defaults to `false` |
| `blank-to-null` | No | Convert blank parameters to null; defaults to `true` |
| `value-root` / `type` | No | Root path / type of the JSON result |

Inside `<eql>`, sub-tags such as `filters`, `translate` (Cache Translate), `secure-mask` (data masking), `pivot`/`unpivot`/`summary` (result-set algorithms), and `page-optimize` (pagination optimization) can also be used, exactly as in SQL queries.

## 3. Java Invocation

Invoke through the `lightDao.elastic()` chain (pass the eql id to `sql`):

```java
// Normal query (SQL mode)
List<CompanyInfoVO> result = (List<CompanyInfoVO>) lightDao.elastic()
        .sql("es_find_company")
        .values(MapKit.keys("companyName", "companyType", "flag").values("Zhejiang Huaxu", "3", 2))
        .resultType(CompanyInfoVO.class)
        .find();

// Pagination query (ES native SQL already supports cursor-based pagination)
Page page = (Page) lightDao.elastic()
        .sql("es_find_company_page")
        .values(MapKit.keys("companyName", "companyType", "flag").values("Zhejiang Huaxu", "3", 2))
        .resultType(CompanyInfoVO.class)
        .findPage(new Page());

// Get Top N
List top = lightDao.elastic().sql("es_find_company_page")
        .values(...).resultType(CompanyInfoVO.class).findTop(10);

// Native JSON mode query (the parameter is an array)
List<CompanyInfoVO> jsonResult = (List<CompanyInfoVO>) lightDao.elastic()
        .sql("sys_elastic_test_json")
        .names("companyTypes").values(new Object[]{ new Object[]{ "1", "2" } })
        .resultType(CompanyInfoVO.class)
        .find();
```

The `elastic()` chain supports: `sql`, `names`, `values`, `entity`, `endPoint`, `resultType`, `humpMapLabel`; terminal methods: `find()`, `getOne()`, `findTop(int)`, `findPage(Page)`.

## 4. Notes

- **Pagination**: ES native SQL already supports cursor-based pagination; the elasticsearch-sql / OpenDistro plugins support it as well — choose `sqlPath` as needed.
- Multiple clusters/nodes are configured via multiple `endpoints[n]` entries; at query time, specify one with the `end-point` attribute or `.endPoint(id)`.
- For pure CRUD, use the official ES client directly; sqltoy's value lies in the combination of **dynamic conditions + Cache Translate + result-set algorithms**.
