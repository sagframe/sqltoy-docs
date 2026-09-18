# sqltoy Configuration

- Spring projects use the `spring.sqltoy.` prefix;
- Solon projects use the `solon.sqltoy.` prefix;
- In traditional Spring XML mode, set properties with the same names via `<property>` on the `SqlToyContext` bean.

Below are **all configuration parameters** grouped by purpose (based on the spring-boot-starter's `SqlToyContextProperties` and `SqlToyContext`, including default values). The vast majority of projects only need to set 3~5 of them; see [Typical Project Usage](#typical-project-usage) at the end.

---

## 1. Resource Loading and Debug Mode

```properties
# Path to sql.xml resources, comma-separated for multiple values; supports AntPath patterns such as classpath*:com/**/*.sql.xml (5.6.75+)
spring.sqltoy.sqlResourcesDir=classpath:com/nebula/crm/modules
# Directly specify concrete sql.xml file resources (array); use alone or together with sqlResourcesDir
spring.sqltoy.sqlResources[0]=classpath:com/nebula/system.sql.xml
# Entity scan packages (array), based on the @Entity/@SqlToyEntity annotations; no configuration needed by default (loaded on first use)
spring.sqltoy.packagesToScan[0]=com.yourproject.modules
# Extra annotated classes (array); generally no longer necessary
#spring.sqltoy.annotatedClasses[0]=com.yourproject.SomeEntity
# Encoding of sql files
spring.sqltoy.encoding=UTF-8
# Whether to enable debug mode, default false; when true, executed sql and elapsed time are logged, and the sql file change check interval becomes 2 seconds (15 seconds when false)
spring.sqltoy.debug=true
# Interval for detecting sql file script changes (seconds); <0 or >86400 (one day) disables change detection
spring.sqltoy.scriptCheckIntervalSeconds=2
# Delay in seconds before detection of cache updates and sql script updates starts
spring.sqltoy.delayCheckSeconds=300
# Whether to throw an exception and terminate when a duplicate sqlId is found, default true; if false, the later definition overrides the earlier one
spring.sqltoy.breakWhenSqlRepeat=true
# sql log output formatter: defaultSqlFormater or default (uses druid's sql formatting, requires druid on the classpath)
spring.sqltoy.sqlFormater=defaultSqlFormater
```

## 2. Datasources and Dialects

```properties
# In multiple-datasource scenarios, specify the default datasource; same effect as Spring's @Primary
spring.sqltoy.defaultDataSource=crmDataSource
# Custom datasource selector (implements DataSourceSelector) for dynamic datasource routing
#spring.sqltoy.dataSourceSelector=com.yourproject.MyDataSourceSelector
# Connection management implementation extension (implements ConnectionFactory); commonly used in pure Java environments
#spring.sqltoy.connectionFactory=org.sagacity.sqltoy.integration.impl.SimpleConnectionFactory
# Database dialect; generally no need to set it (auto-detected by the framework)
#spring.sqltoy.dialect=mysql
# Database dialect parameter configuration (Map), used to override/supplement dialect behavior
#spring.sqltoy.dialectConfig.xxx=yyy
# Dialect mapping for different databases (Map), e.g. treat a non-built-in database as a certain dialect: OSCAR-->oracle
#spring.sqltoy.dialectMap.OSCAR=oracle
# Cross-database adaptation verification: any query is replayed once on these datasources (array), for productized multi-database testing
#spring.sqltoy.redoDataSources[0]=oracleDB
# Database reserved words, comma-separated (object operations handle them automatically; custom sql adapts accordingly when running across databases)
spring.sqltoy.reservedWords=maxvalue,minvalue,name
# Default query timeout (seconds)
#spring.sqltoy.defaultStatementTimeout=30
```

## 3. Batch, Pagination and Execution

```properties
# Batch size for batch operations (saveAll/updateAll etc.), default 200
spring.sqltoy.batchSize=200
# Default number of records fetched on the database side (fetchSize), default -1; generally no need to set it
#spring.sqltoy.fetchSize=1000
# Maximum records per page, default 100000; <0 means unlimited. Prevents full data extraction when pageNo=-1
spring.sqltoy.pageFetchSizeLimit=100000
# Default records per page, default 10
spring.sqltoy.defaultPageSize=10
# For unmatched database types, whether pagination uses the limit ? offset ? pattern or the limit ?,? pattern
#spring.sqltoy.defaultPageOffset=false
# Whether to return to the first page when paging beyond the last page
spring.sqltoy.overPageToFirst=true
# Record-count threshold above which a log reminder is printed for large-volume data modifications, default 2000
spring.sqltoy.updateTipCount=2000
# Split merge into into two steps: updateAll + saveAllIgnoreExist (seata distributed transactions do not support merge)
#spring.sqltoy.splitMergeInto=false
# For change-type sql executed via executeSql, whether blank parameters are converted to null by default
#spring.sqltoy.executeSqlBlankToNull=true
```

## 4. Cache Translate

```properties
# Cache translate config file, default classpath:sqltoy-translate.xml;classpath:translates
# (classpath:translates means files under that path ending with .trans.xml/.translates.xml/-translate.xml/-translates.xml)
spring.sqltoy.translateConfig=classpath:sqltoy-translate.xml
# Cache component used by cache translate, default ehcache, caffeine also available
spring.sqltoy.cacheType=caffeine
# Custom cache manager (implements TranslateCacheManager)
#spring.sqltoy.translateCacheManager=com.yourproject.MyTranslateCacheManager
# Implementation for dynamically fetching the cache (usually redis-based), for very large master data; see FIFO dynamic cache for details
#spring.sqltoy.dynamicCacheFetch=com.yourproject.MyDynamicCacheFetch
# Cache manager for dynamically fetched cache; the framework provides a default implementation (FIFODynamicFetchCacheManager)
#spring.sqltoy.dynamicFecthCacheManager=...
# Number of days to cache distributed id keys (usually redis-based, to avoid long-term space usage); expires after that many days
#spring.sqltoy.distributeIdCacheExpireDays=30
```

## 5. Function Adaptation (Cross-Database)

```properties
# Enable automatic adaptation of database sql functions; custom functions can also be attached: default,com.yourpackage.Instr
# (with an identical class name, a custom implementation overrides the framework default; close disables it)
spring.sqltoy.functionConverts=default
```

## 6. Field Processing and Types

```properties
# Unified field assignment handler (unifyFieldsHandler): fills createBy/createTime/updateBy/updateTime etc. only when they are empty
spring.sqltoy.unifyFieldsHandler=com.sqltoy.plugins.SqlToyUnifyFieldsHandler
# Handler for non-standard data types (e.g. JSON); see the TypeHandler extension for details
spring.sqltoy.typeHandler=com.sqltoy.plugins.JSONTypeHandler
# When queries return List<Map>, whether map labels are converted to camelCase, default true
spring.sqltoy.humpMapResultTypeLabel=true
# Strategy for obtaining ResultSetMetaData column labels: default (no processing)/upper (uppercase)/lower (lowercase)
spring.sqltoy.columnLabelUpperOrLower=default
# Format of LocalDateTime in sql log output; can be set to auto or yyyy-MM-dd HH:mm:ss.SSSSSS etc.
spring.sqltoy.localDateTimeFormat=yyyy-MM-dd HH:mm:ss.SSSSSS
# Format of LocalTime in sql log output; can be set to auto or HH:mm:ss.SSSSSS etc.
spring.sqltoy.localTimeFormat=HH:mm:ss.SSSSSS
# Default locale (e.g. zh_CN, en-US), affects the locale symbols used for date/number formatting and parsing; when null, the JVM default locale is used
#spring.sqltoy.defaultLocale=zh_CN
# Whether the like query ESCAPE clause uses double backslashes: true=ESCAPE '\\', false=ESCAPE '\', null=decided automatically by dialect
#spring.sqltoy.backslashEscaping=
```

## 7. Security (Encryption/Decryption and Masking)

```properties
# RSA keys for field encryption/decryption
spring.sqltoy.securePrivateKey=classpath:mock/rsa_private.key
spring.sqltoy.securePublicKey=classpath:mock/rsa_public.key
# Custom encryption/decryption implementation (RSA by default, no need to set it); interface org.sagacity.sqltoy.plugins.secure.FieldsSecureProvider
#spring.sqltoy.fieldsSecureProvider=com.yourproject.FieldsSecureProvider
# Custom masking implementation (provided by default, no need to set it); interface org.sagacity.sqltoy.plugins.secure.DesensitizeProvider
#spring.sqltoy.desensitizeProvider=com.yourproject.DesensitizeProvider
```

## 8. Automatic DDL Table Creation

```properties
# Whether to automatically create/update table structures from POJOs, default false; requires packagesToScan
spring.sqltoy.autoDDL=true
# Whether table/column names in generated DDL are converted to lowercase or uppercase
#spring.sqltoy.ddlLowerOrUpper=lower
# Custom database DDL generator (implements DialectDDLGenerator)
#spring.sqltoy.dialectDDLGenerator=com.yourproject.MyDDLGenerator
# When a single-record save uses the identity/sequence primary-key strategy and returns the primary key value, the case handling of the field name (Map: lower/upper)
#spring.sqltoy.dialectReturnPrimaryColumnCase.mysql=lower
```

## 9. Interceptors, Slow SQL and Extensions

```properties
# sql execution interceptors (array), can modify the current sql, e.g. unified tenant isolation/overreach filtering
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
# Custom filter handler (reserved for future use)
#spring.sqltoy.customFilterHandler=...
# Slow sql duration threshold (milliseconds); beyond it the sql is logged and put into the slow sql queue, default 8000 (8 seconds)
spring.sqltoy.printSqlTimeoutMillis=3000
# Slow sql collection handler, default DefaultOverTimeHandler
# Access: lightDao.getSqlToyContext().getOverTimeSqlHandler().getSlowest(100, true)
spring.sqltoy.overTimeSqlHandler=org.sagacity.sqltoy.plugins.overtime.DefaultOverTimeHandler
# Capture of the business code call site (FirstBizCodeTrace), used to trace the business origin of a sql
#spring.sqltoy.firstBizCodeTrace=...
```

### Thread Pool (taskExecutor)

The thread pool used by parallel query, parallel pagination, parallel batch, etc., with the prefix `spring.sqltoy.taskExecutor.`:

```properties
# Specify a thread pool name; once set, that pool becomes the default; default none (uses sqltoy's built-in thread pool)
#spring.sqltoy.taskExecutor.targetPoolName=none
# Thread name prefix, default sqltoyThreadPool
spring.sqltoy.taskExecutor.threadNamePrefix=sqltoyThreadPool
# Core thread count, default CPU cores/2+1
spring.sqltoy.taskExecutor.corePoolSize=8
# Maximum thread count, default CPU cores*3
spring.sqltoy.taskExecutor.maxPoolSize=24
# Buffer queue capacity, default 200
spring.sqltoy.taskExecutor.queueCapacity=200
# Thread idle keep-alive time (seconds), default 60
spring.sqltoy.taskExecutor.keepAliveSeconds=60
# Whether to wait for tasks to complete on shutdown, default true
spring.sqltoy.taskExecutor.waitForTasksToCompleteOnShutdown=true
# Await termination timeout (seconds), default -1
spring.sqltoy.taskExecutor.awaitTerminationSeconds=-1
```

## 10. NoSQL (Elasticsearch)

ES node configuration uses the prefix `spring.sqltoy.elastic.` (multiple nodes/clusters supported); for full details see [Elasticsearch Support](../nosql/sqltoy_elasticsearch.md):

```properties
spring.sqltoy.elastic.defaultId=default
spring.sqltoy.elastic.endpoints[0].id=default
spring.sqltoy.elastic.endpoints[0].url=http://192.168.56.101:9200
spring.sqltoy.elastic.endpoints[0].username=elastic
spring.sqltoy.elastic.endpoints[0].password=skyline
spring.sqltoy.elastic.endpoints[0].sqlPath=_nlpcn/sql
```

> MongoDB reuses spring-data's `spring.data.mongodb.*` configuration; see [MongoDB Support](../nosql/sqltoy_mongo.md).

---

## Typical Project Usage

Don't be intimidated by the long list — the vast majority of projects only need to set 3~5 parameters:

```properties
# Recommended to put complex queries in xml files
spring.sqltoy.sqlResourcesDir=classpath:com/nebula/crm/modules
# Output executed sql, parameters and elapsed time to help locate problems
spring.sqltoy.debug=true
# Unified field assignment for common fields
spring.sqltoy.unifyFieldsHandler=com.sqltoy.plugins.SqlToyUnifyFieldsHandler
# Definition of the duration standard for slow sql
spring.sqltoy.printSqlTimeoutMillis=3000
# Handling of non-standard types (e.g. JSON); used relatively rarely (enum types are adapted automatically by the framework)
spring.sqltoy.typeHandler=com.sqltoy.plugins.JSONTypeHandler
```
