# 超大规模缓存翻译

* 开启缓存数据动态获取FIFIO并保留频繁使用数据的方式，主要针对超大量的配置数据，如平台型电商SKU具体原理:
针对百万级SKU，但真正常用的可能只有10万左右，设置一个FIFOMap，最大数据量为一个固定值（如十万），
一开始数据为空，用到哪些数据先判断缓存中是否存在，不存在就动态加载，频繁使用的会自动排序到最后面，
达到10万条时，新进来的就会挤掉排最前面不常用的，具体参见：

## 具体步骤

* 1、配置缓存，在sqltoy-translates.xml 中定义

```xml
//sid、properties 可选，会传递给查询数据的接口
//keep-alive 数据存活时长，单位秒
<local-translate cache="缓存名称" sid="特定标记如sqlId" properties="属性信息"  
keep-alive="3600" dynamic-cache="true" dynamic-cache-maxSize="100000"/>
```

* 2、项目yml配置spring.sqltoy.dynamicCacheFetch自定义捕获数据的接口实现，具体接口如下：

```java
package org.sagacity.sqltoy.translate;
public interface DynamicCacheFetch {
    public void initialize(AppContext appContext);
    public Object[] getCache(String cacheName, String cacheType, String sid, String[] properties, String key);
    public Map<String,Object[]> getCache(String cacheName, String cacheType, String sid, String[] properties, String[] keys);
}
```

* 3、【可选】可自定义DynamicFecthCacheManager,框架提供了默认实现：
参见：org.sagacity.sqltoy.translate.cache.impl.FIFODynamicFetchCacheManager

```java
//自定义实现配置：spring.sqltoy.dynamicFecthCacheManager=xxxx.DynamicFecthCacheManagerImpl
package org.sagacity.sqltoy.translate.cache;
public interface DynamicFecthCacheManager {
    ......
}
```
