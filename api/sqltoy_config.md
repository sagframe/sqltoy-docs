# sqltoy的完整配置
* spring项目以spring.sqltoy.为前缀
* solon项目以solon.sqltoy.为前缀

----------

# 完整参数

```properties
#sql.xml资源,多个用逗号分割classpath:com/nebula/crm/modules,classpath:com/nebula/commons/modules
spring.sqltoy.sqlResourcesDir=classpath:com/nebula/crm/modules
#是否调试，默认为false，为true时会输出执行的sql日志和耗时,且sql文件更新检测间隔为2秒(为false时为15秒)
spring.sqltoy.debug=true
# 提供统一字段:createBy createTime updateBy updateTime 等字段补漏性(为空时)赋值(可选配置)
spring.sqltoy.unifyFieldsHandler=com.sqltoy.plugins.SqlToyUnifyFieldsHandler
#缓存翻译配置,默认:classpath:sqltoy-translate.xml;classpath:translates
#classpath:translates指在这个路径下.trans.xml或-translates.xml或-translate.xml结尾的文件
spring.sqltoy.translateConfig=classpath:sqltoy-translate.xml
# 在多个数据库源场景下，指定默认数据源，跟spring的bean的@Primary效果一致
spring.sqltoy.defaultDataSource=crmDataSource
#saveAll,updateAll等批量操作的批量长度，默认1000
spring.sqltoy.batchSize=1000
#慢sql时长设定，超过就日志输出且存放在慢sql队列中,便于收集优化慢sql
spring.sqltoy.printSqlTimeoutMillis=3000
#缓存翻译使用哪种缓存组件,默认为ehcache
spring.sqltoy.cacheType=caffeine
#非标准数据类型处理，一般目前主要是JSON比较多
spring.sqltoy.typeHandler=com.sqltoy.plugins.JSONTypeHandler
#数据库关键词(原则上表设计要规避使用关键词)
spring.sqltoy.reservedWords=maxvalue,minvalue,name
#开启数据库sql函数自动适配功能,也可以用:com.yourpackage.Nvl,com.yourpackage.Instr形式挂载自定义的函数
#defaults,com.yourpackage.Instr表示加载框架默认的，但Instr用自己的代替(类名称一致则以后面的替代前面的)
spring.sqltoy.functionConverts=defaults
#sql文件更新检测时长<0 或 >3600*24(一天) 表示关闭更新检测
spring.sqltoy.scriptCheckIntervalSeconds=2
#默认true，sqlId出现重复程序启动报错，false则后面的覆盖前面的
spring.sqltoy.breakWhenSqlRepeat=true
#设置字段加解密的key(RSA算法)
spring.sqltoy.securePrivateKey=classpath:mock/rsa_private.key
spring.sqltoy.securePublicKey=classpath:mock/rsa_public.key
#自定义加解密算法实现(默认无需设置)
spring.sqltoy.fieldsSecureProvider=com.yourproject.FieldsSecureProvider
#自定义脱敏实现(默认无需设置)
spring.sqltoy.desensitizeProvider=com.yourproject.DesensitizeProvider
#获取rs.getMetaData的列标题处理策略:default:不做处理;upper:转大写;lower
spring.sqltoy.columnLabelUpperOrLower=default
#分页查询最大查询记录数量,默认10万,<0表示不限制,目的是防止pageNo=-1(页面分页查询表格点下载)做全量数据提取
spring.sqltoy.pageFetchSizeLimit=100000
#针对查询返回List<Map>类型结果，设置返回map的label是否转驼峰模式
spring.sqltoy.humpMapResultTypeLabel=true
#数组类型,针对产品化项目，如:测试阶段主数据库为mysql,同时sql在oracle上执行一次,即一次测试验证多种数据库
#spring.sqltoy.redoDataSources[0]=oracleDB
#数组类型,sql执行拦截器，可以改变当前的sql,如统一的租户隔离
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
#是否自动通过POJO创建表结构，默认为false,需要配合packagesToScan使用
spring.sqltoy.autoDDL=true
#设置扫描加载POJO的包路径(以@Entity注解为依据)，默认无需配置,sqltoy首次使用加载策略
spring.sqltoy.packagesToScan[0]=com.yourproject.modules
#sql日志输出时LocalDateTime的格式,主要提升sql日志的精度，便于sql copy出来客户端调试,可设置为auto
spring.sqltoy.localDateTimeFormat=yyyy-MM-dd HH:mm:ss.SSSSSS
#可设置为auto,会根据实际毫秒位数确定格式
spring.sqltoy.localTimeFormat=HH:mm:ss.SSSSSS
#慢sql收集处理器,默认为DefaultOverTimeHandler,用:lightDao.getSqlToyContext().getOverTimeSqlHandler().getSlowest(100, true);获取
spring.sqltoy.overTimeSqlHandler=org.sagacity.sqltoy.plugins.overtime.DefaultOverTimeHandler
#设置分页默认一页记录条数,默认为10
spring.sqltoy.defaultPageSize=20
#sql日志输出格式化器,可以设置defaultSqlFormater或default表示使用druid的sql格式化(注意要引入druid类)
spring.sqltoy.sqlFormater=defaultSqlFormater
#针对批量操作,设置多少条记录输出日志进行提醒,便于日志跟踪有哪些行为存在大规模数据操作
spring.sqltoy.updateTipCount=3000
```

# 常规项目用法
* 看到清单吓一跳,但绝大多数项目只需要设置3~5个参数

```properties
#推荐复杂查询放xml中
spring.sqltoy.sqlResourcesDir=classpath:com/nebula/crm/modules
#输出执行的sql过程和参数和耗时,便于定位问题
spring.sqltoy.debug=true
#公共字段统一赋值处理
spring.sqltoy.unifyFieldsHandler=com.sqltoy.plugins.SqlToyUnifyFieldsHandler
#慢sql的时长标准定义
spring.sqltoy.printSqlTimeoutMillis=3000
#此项使用比例也较低(枚举类型框架自动适配)
spring.sqltoy.typeHandler=com.sqltoy.plugins.JSONTypeHandler
```
