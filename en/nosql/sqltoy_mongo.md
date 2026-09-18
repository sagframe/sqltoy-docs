# MongoDB

**Note**: sqltoy's MongoDB integration **supports queries only**; for pure CRUD (insert/delete/update), use spring-data's `MongoTemplate` directly. sqltoy's motivation for integrating MongoDB is:

1. To fully leverage sqltoy's strength in **organizing dynamic conditions**;
2. Combined with sqltoy's **Cache Translate**, it eliminates the complexity of joining configuration collections in MongoDB (or the complexity of ETL cleansing);
3. It makes use of sqltoy's **result-set algorithms** (data masking, formatting, pivot, group summary, etc.) to simplify writing queries/aggregations directly;
4. It facilitates integration with external low-code frameworks (such as reporting platforms), enabling configuration-driven data query and processing.

> Demo project: https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-nosql

## 1. Configuration

sqltoy reuses spring-data-mongodb's `MongoTemplate`; just configure it in the standard Spring Boot way:

```yaml
spring:
  data:
    mongodb:
      host: 192.168.56.101
      port: 27017
      database: sagframe
      username: sagframe
      password: sagframe
```

Direct object operations (`@Document(collection="")`, `@Id`, `@Field` annotations + `MongoTemplate`) belong to the spring-data domain and are not covered here; sqltoy mainly takes care of **querying + Cache Translate + result-set algorithms**.

## 2. Writing mql Queries

MongoDB queries are defined with the `<mql>` tag; the MongoDB JSON query/aggregation statements go into `value`, dynamic conditions are wrapped with `<#> ... </#>`, and parameters are referenced with `@(:paramName)`.

### 2.1 Basic Query (Field Alias + Cache Translate + Data Masking)

```xml
<!-- In fields, transType:transTypeName means the value of transType is also stored under the alias
     transTypeName, which facilitates the subsequent cache translate mapping -->
<mql id="sqltoy_mongo_find"
     fields="transId,merchantCode,transCode,transCode:transCodeName,transDate,agentOrg,transType,transType:transTypeName,transAmt"
     collection="fact_trans_details">
    <!-- Translate the alias columns; original-columns points to the columns that serve as the code source -->
    <!-- MongoDB cannot do "select trans_type as transTypeName" like SQL, so this is achieved via
         the fields alias + original-columns -->
    <translate cache="dictKeyName" cache-type="TRANS_CODE"
               columns="transCodeName" original-columns="transCode" />
    <translate cache="dictKeyName" cache-type="TRANS_TYPE"
               columns="transTypeName" original-columns="transType" />
    <!-- Secure data masking -->
    <secure-mask columns="merchantCode" type="bank-card" />
    <value><![CDATA[
        {
        <#>transType:@(:transType)</#>
        <#>@if(@(:flag)==1),transAmt:{$gt:@(:transAmt)}</#>
        <#>@else ,transAmt:{$gte:@(:transAmt)}</#>
        }
    ]]></value>
</mql>
```

Key points:

- **Field alias**: MongoDB cannot do `select trans_type as transTypeName` as SQL does; sqltoy uses the `source:alias` syntax in `fields` to copy the same field value into an alias column, then applies Cache Translate to the alias column via `<translate original-columns="sourceField" columns="aliasName">`, keeping the original code column unchanged.
- **Dynamic conditions**: when a parameter inside `<#>...</#>` is null, the whole segment is removed; it can be combined with `@if()/@else` for branching (see [Tags & Expressions reference](../appendix/tags.md)).
- **Data masking**: `<secure-mask>` is used the same way as in SQL queries.

### 2.2 Aggregation Query

```xml
<!-- In aggregation, fields can extract nested fields via _id.xxx:alias, e.g. when $group uses
     multiple fields: fields="_id[transCode,colName:aliasName],count,totalAmt" -->
<mql id="sqltoy_mongo_agg"
     fields="_id.transCode:transCode,count,totalAmt"
     collection="fact_trans_details">
    <translate cache="dictKeyName" cache-type="TRANS_CODE" columns="transCode" />
    <value><![CDATA[
        [
         { $group: {
              _id: {transCode:"$transCode"},
              count: { $sum: 1 },
              totalAmt:{$sum:"$transAmt"}
           }
         },
         { $match: {
              <#>transType:@(:transType)</#>
              <#>,transAmt:{$gt:@(:transAmt)}</#>
           }
         }
        ]
    ]]></value>
</mql>
```

The `value` is an aggregation pipeline array (`$group`/`$match`/`$sort`, etc.); `fields` uses `_id.transCode:transCode` to extract the nested `_id.transCode` from the aggregation result into a `transCode` column, on which Cache Translate is then applied.

### 2.3 mql Tag Attributes

| Attribute | Required | Description |
| --- | --- | --- |
| `id` | Yes | Unique identifier of the query |
| `collection` | Yes | MongoDB collection name |
| `fields` | Yes | Fields to extract/map; supports `source:alias`, `_id.xxx:alias`, `_id[a,b:alias]`, etc. |
| `aggregate` | No | Whether it is an aggregation query; defaults to `false` |
| `blank-to-null` | No | Convert blank parameters to null |

Inside `<mql>`, sub-tags such as `filters`, `translate`, `secure-mask`, `pivot`/`unpivot`/`summary`, and `page-optimize` are also supported.

## 3. Cache Translate Definition

The `dictKeyName` cache in the example above is defined in `sqltoy-translate.xml` (with an inside-category `cache-type`, i.e. `DICT_TYPE`):

```xml
<sagacity xmlns="http://www.sagframe.com/schema/sqltoy-translate">
    <cache-translates>
        <!-- Build the cache from a SQL query; the first column of the query result is the category (DICT_TYPE) -->
        <sql-translate cache="dictKeyName" datasource="dataSource">
            <sql><![CDATA[
                select t.DICT_KEY,t.DICT_NAME,t.STATUS
                from SQLTOY_DICT_DETAIL t
                where t.DICT_TYPE=:dictType
                order by t.SHOW_INDEX
            ]]></sql>
        </sql-translate>
    </cache-translates>
    <cache-update-checkers>
        <!-- Incremental refresh check; has-inside-group=true means the first result column is the category -->
        <sql-increment-checker cache="dictKeyName" check-frequency="15"
                               has-inside-group="true" datasource="dataSource">
            <sql><![CDATA[
                select t.DICT_TYPE,t.DICT_KEY,t.DICT_NAME,t.STATUS
                from SQLTOY_DICT_DETAIL t
                where t.UPDATE_TIME >=:lastUpdateTime
            ]]></sql>
        </sql-increment-checker>
    </cache-update-checkers>
</sagacity>
```

For the full usage of Cache Translate, see [Cache Translate usage](../quickstart/translates.md).

## 4. Java Invocation

Invoke through the `lightDao.mongo()` chain (pass the mql id to `sql`):

```java
// Query with parameters passed via an entity object
PospTransDetailVO queryVO = new PospTransDetailVO();
queryVO.setTransType("N");
queryVO.setTransAmt(0d);
List<PospTransDetailVO> result = (List<PospTransDetailVO>) lightDao.mongo()
        .sql("sqltoy_mongo_find")
        .resultType(PospTransDetailVO.class)
        .entity(queryVO)
        .find();

// Pass parameters via names/values + pagination
Page page = lightDao.mongo()
        .sql("sqltoy_mongo_find")
        .resultType(PospTransDetailVO.class)
        .names("transType", "transAmt", "flag").values("N", 13800, 2)
        .findPage(new Page<>());

// Aggregation query
List aggResult = lightDao.mongo()
        .sql("sqltoy_mongo_agg")
        .names("transType", "transAmt").values(null, null)
        .find();
```

The `mongo()` chain supports: `sql`, `names`, `values`, `entity`, `resultType`, `humpMapLabel`; terminal methods: `find()`, `getOne()`, `findTop(Float)`, `findPage(Page)`.

## 5. Notes

- sqltoy **only performs queries** on MongoDB; use `MongoTemplate` for insert/delete/update (with the object annotations `@Document`/`@Id`/`@Field`).
- Combined with the `fields` alias + `original-columns`, Cache Translate resolves code-value translation without writing any join lookups.
- For aggregation results, extract nested fields via `fields` using `_id.xxx:alias` before translating/processing them.
