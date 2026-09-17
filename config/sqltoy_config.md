# sqltoy 配置参数

- Spring 项目以 `spring.sqltoy.` 为前缀；
- Solon 项目以 `solon.sqltoy.` 为前缀；
- 传统 Spring XML 模式则在 `SqlToyContext` bean 上以 `<property>` 设置同名属性。

下面按用途分类列出**全部配置参数**（以 spring-boot-starter 的 `SqlToyContextProperties` 与 `SqlToyContext` 为准，含默认值）。绝大多数项目只需设置其中 3~5 个，见文末[常规项目用法](#常规项目用法)。

---

## 一、资源加载与调试

```properties
# sql.xml 资源路径，多个用逗号分隔；支持 classpath*:com/**/*.sql.xml 的 AntPath 模式(5.6.75+)
spring.sqltoy.sqlResourcesDir=classpath:com/nebula/crm/modules
# 直接指定具体的 sql.xml 文件资源(数组)，与 sqlResourcesDir 二选一或并用
spring.sqltoy.sqlResources[0]=classpath:com/nebula/system.sql.xml
# 实体 Entity 扫描包路径(数组)，以 @Entity/@SqlToyEntity 注解为依据；默认无需配置(首次使用时加载)
spring.sqltoy.packagesToScan[0]=com.yourproject.modules
# 额外注解 class 类(数组)，一般已无必要
#spring.sqltoy.annotatedClasses[0]=com.yourproject.SomeEntity
# sql 文件编码
spring.sqltoy.encoding=UTF-8
# 是否开启 debug 模式，默认 false；为 true 时输出执行 sql 日志与耗时，且 sql 文件更新检测间隔为 2 秒(false 时 15 秒)
spring.sqltoy.debug=true
# sql 文件脚本变更检测间隔(秒)；<0 或 >86400(一天) 表示关闭更新检测
spring.sqltoy.scriptCheckIntervalSeconds=2
# 缓存更新、sql 脚本更新 延迟多少秒后开始检测
spring.sqltoy.delayCheckSeconds=300
# 发现重复 sqlId 时是否抛异常终止程序，默认 true；false 则后面的覆盖前面的
spring.sqltoy.breakWhenSqlRepeat=true
# sql 日志输出格式化器：defaultSqlFormater 或 default(使用 druid 的 sql 格式化，需引入 druid)
spring.sqltoy.sqlFormater=defaultSqlFormater
```

## 二、数据源与方言

```properties
# 多数据源场景下指定默认数据源，效果同 spring 的 @Primary
spring.sqltoy.defaultDataSource=crmDataSource
# 自定义数据源选择器(实现 DataSourceSelector)，用于动态数据源路由
#spring.sqltoy.dataSourceSelector=com.yourproject.MyDataSourceSelector
# 连接管理实现扩展(实现 ConnectionFactory)；纯 Java 环境常用
#spring.sqltoy.connectionFactory=org.sagacity.sqltoy.integration.impl.SimpleConnectionFactory
# 数据库方言，一般无需设置(框架自动识别)
#spring.sqltoy.dialect=mysql
# 数据库方言参数配置(Map)，用于覆盖/补充方言行为
#spring.sqltoy.dialectConfig.xxx=yyy
# 不同数据库方言的映射(Map)，如把未内置的库按某方言处理：OSCAR-->oracle
#spring.sqltoy.dialectMap.OSCAR=oracle
# 跨库适配验证：任意查询会在这些数据源上重放一次(数组)，用于产品化多库测试
#spring.sqltoy.redoDataSources[0]=oracleDB
# 数据库保留字，逗号分隔(对象操作自动兼容；自定义 sql 跨库时按此适配)
spring.sqltoy.reservedWords=maxvalue,minvalue,name
# 默认查询超时时长(秒)
#spring.sqltoy.defaultStatementTimeout=30
```

## 三、批量、分页与执行

```properties
# 批量操作(saveAll/updateAll 等)每批次数量，默认 200
spring.sqltoy.batchSize=200
# 数据库端默认提取记录量(fetchSize)，默认 -1，一般无需设置
#spring.sqltoy.fetchSize=1000
# 分页最大单页数据量，默认 100000(10万)；<0 表示不限制。防止 pageNo=-1 做全量提取
spring.sqltoy.pageFetchSizeLimit=100000
# 默认每页记录数，默认 10
spring.sqltoy.defaultPageSize=10
# 未匹配的数据库类型，分页采用 limit ? offset ? 还是 limit ?,? 模式
#spring.sqltoy.defaultPageOffset=false
# 翻页超出最大页时是否回到第一页
spring.sqltoy.overPageToFirst=true
# 大批量数据修改时输出日志提醒的记录数阈值，默认 2000
spring.sqltoy.updateTipCount=2000
# 拆分 merge into 为 updateAll + saveAllIgnoreExist 两步(seata 分布式事务不支持 merge)
#spring.sqltoy.splitMergeInto=false
# executeSql 变更操作型 sql 执行时，空白参数是否默认转为 null
#spring.sqltoy.executeSqlBlankToNull=true
```

## 四、缓存翻译

```properties
# 缓存翻译配置文件，默认 classpath:sqltoy-translate.xml;classpath:translates
# (classpath:translates 指该路径下以 .trans.xml/.translates.xml/-translate.xml/-translates.xml 结尾的文件)
spring.sqltoy.translateConfig=classpath:sqltoy-translate.xml
# 缓存翻译使用的缓存组件，默认 ehcache，可选 caffeine
spring.sqltoy.cacheType=caffeine
# 自定义缓存管理器(实现 TranslateCacheManager)
#spring.sqltoy.translateCacheManager=com.yourproject.MyTranslateCacheManager
# 动态获取缓存的实现(一般基于 redis)，用于超大规模主数据，详见 FIFO 动态缓存
#spring.sqltoy.dynamicCacheFetch=com.yourproject.MyDynamicCacheFetch
# 动态捞取缓存的缓存管理器，框架提供了默认实现(FIFODynamicFetchCacheManager)
#spring.sqltoy.dynamicFecthCacheManager=...
# 分布式 id key 的缓存天数(一般基于 redis，避免长期占用空间)，多少天失效
#spring.sqltoy.distributeIdCacheExpireDays=30
```

## 五、函数适配（跨库）

```properties
# 开启数据库 sql 函数自动适配；也可挂载自定义函数：default,com.yourpackage.Instr
# (类名一致则自定义实现覆盖框架默认；close 表示关闭)
spring.sqltoy.functionConverts=default
```

## 六、字段处理与类型

```properties
# 统一字段处理器：对 createBy/createTime/updateBy/updateTime 等做补漏性赋值(为空时才赋)
spring.sqltoy.unifyFieldsHandler=com.sqltoy.plugins.SqlToyUnifyFieldsHandler
# 非标准数据类型处理器(如 JSON)，详见类型扩展 TypeHandler
spring.sqltoy.typeHandler=com.sqltoy.plugins.JSONTypeHandler
# 查询返回 List<Map> 时，map 的 label 是否转驼峰，默认 true
spring.sqltoy.humpMapResultTypeLabel=true
# 获取 ResultSetMetaData 列标题的处理策略：default(不处理)/upper(转大写)/lower(转小写)
spring.sqltoy.columnLabelUpperOrLower=default
# sql 日志输出时 LocalDateTime 的格式，可设 auto 或 yyyy-MM-dd HH:mm:ss.SSSSSS 等
spring.sqltoy.localDateTimeFormat=yyyy-MM-dd HH:mm:ss.SSSSSS
# sql 日志输出时 LocalTime 的格式，可设 auto 或 HH:mm:ss.SSSSSS 等
spring.sqltoy.localTimeFormat=HH:mm:ss.SSSSSS
# 默认区域设置(如 zh_CN、en-US)，影响日期/数字格式化解析的区域符号；为 null 则用 JVM 默认区域
#spring.sqltoy.defaultLocale=zh_CN
# like 查询 ESCAPE 子句是否使用双反斜杠：true=ESCAPE '\\'，false=ESCAPE '\'，null=按方言自动判断
#spring.sqltoy.backslashEscaping=
```

## 七、安全（加解密与脱敏）

```properties
# 字段加解密的 RSA 密钥
spring.sqltoy.securePrivateKey=classpath:mock/rsa_private.key
spring.sqltoy.securePublicKey=classpath:mock/rsa_public.key
# 自定义加解密算法实现(默认 RSA，无需设置)，接口 org.sagacity.sqltoy.plugins.secure.FieldsSecureProvider
#spring.sqltoy.fieldsSecureProvider=com.yourproject.FieldsSecureProvider
# 自定义脱敏实现(默认已提供，无需设置)，接口 org.sagacity.sqltoy.plugins.secure.DesensitizeProvider
#spring.sqltoy.desensitizeProvider=com.yourproject.DesensitizeProvider
```

## 八、DDL 自动建表

```properties
# 是否自动通过 POJO 创建/更新表结构，默认 false，需配合 packagesToScan
spring.sqltoy.autoDDL=true
# 生成 DDL 时表名/字段名转小写还是大写
#spring.sqltoy.ddlLowerOrUpper=lower
# 自定义数据库 DDL 产生器(实现 DialectDDLGenerator)
#spring.sqltoy.dialectDDLGenerator=com.yourproject.MyDDLGenerator
# 单记录保存采用 identity/sequence 主键策略并返回主键值时，字段名称大小写处理(Map: lower/upper)
#spring.sqltoy.dialectReturnPrimaryColumnCase.mysql=lower
```

## 九、拦截器、慢 SQL 与扩展

```properties
# sql 执行拦截器(数组)，可改变当前 sql，如统一租户隔离/越权过滤
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
# 自定义 filter 处理器(预留备用)
#spring.sqltoy.customFilterHandler=...
# 慢 sql 时长阈值(毫秒)，超过则日志输出并存入慢 sql 队列，默认 8000(8秒)
spring.sqltoy.printSqlTimeoutMillis=3000
# 慢 sql 收集处理器，默认 DefaultOverTimeHandler
# 获取：lightDao.getSqlToyContext().getOverTimeSqlHandler().getSlowest(100, true)
spring.sqltoy.overTimeSqlHandler=org.sagacity.sqltoy.plugins.overtime.DefaultOverTimeHandler
# 业务代码调用点获取(FirstBizCodeTrace)，用于追踪 sql 的业务来源
#spring.sqltoy.firstBizCodeTrace=...
```

### 线程池（taskExecutor）

并行查询、并行分页、并行批量等使用的线程池，前缀 `spring.sqltoy.taskExecutor.`：

```properties
# 指定线程池名称，指定后以该线程池为默认；默认 none(使用 sqltoy 内置线程池)
#spring.sqltoy.taskExecutor.targetPoolName=none
# 线程名前缀，默认 sqltoyThreadPool
spring.sqltoy.taskExecutor.threadNamePrefix=sqltoyThreadPool
# 核心线程数，默认 CPU核数/2+1
spring.sqltoy.taskExecutor.corePoolSize=8
# 最大线程数，默认 CPU核数*3
spring.sqltoy.taskExecutor.maxPoolSize=24
# 缓冲队列容量，默认 200
spring.sqltoy.taskExecutor.queueCapacity=200
# 线程空闲存活时间(秒)，默认 60
spring.sqltoy.taskExecutor.keepAliveSeconds=60
# 关闭时是否等待任务完成，默认 true
spring.sqltoy.taskExecutor.waitForTasksToCompleteOnShutdown=true
# 超时中断时间(秒)，默认 -1
spring.sqltoy.taskExecutor.awaitTerminationSeconds=-1
```

## 十、NoSQL（Elasticsearch）

ES 节点配置前缀 `spring.sqltoy.elastic.`（支持多节点/多集群），完整说明见 [Elasticsearch 支持](../nosql/sqltoy_elasticsearch.md)：

```properties
spring.sqltoy.elastic.defaultId=default
spring.sqltoy.elastic.endpoints[0].id=default
spring.sqltoy.elastic.endpoints[0].url=http://192.168.56.101:9200
spring.sqltoy.elastic.endpoints[0].username=elastic
spring.sqltoy.elastic.endpoints[0].password=skyline
spring.sqltoy.elastic.endpoints[0].sqlPath=_nlpcn/sql
```

> MongoDB 复用 spring-data 的 `spring.data.mongodb.*` 配置，见 [MongoDB 支持](../nosql/sqltoy_mongo.md)。

---

## 常规项目用法

看到清单别被吓到，绝大多数项目只需设置 3~5 个参数：

```properties
# 推荐复杂查询放 xml 中
spring.sqltoy.sqlResourcesDir=classpath:com/nebula/crm/modules
# 输出执行的 sql、参数和耗时，便于定位问题
spring.sqltoy.debug=true
# 公共字段统一赋值处理
spring.sqltoy.unifyFieldsHandler=com.sqltoy.plugins.SqlToyUnifyFieldsHandler
# 慢 sql 的时长标准定义
spring.sqltoy.printSqlTimeoutMillis=3000
# 非标准类型处理(如 JSON)，使用比例较低(枚举类型框架自动适配)
spring.sqltoy.typeHandler=com.sqltoy.plugins.JSONTypeHandler
```
