# Dynamic Cache Control

Since version 5.2.8, sqltoy allows you to flexibly **dynamically extend caches and dynamically extend cache update checkers**, and to update cached data in real time. All of this is done through `TranslateManager` (the cache translate manager).

## 1. Getting the Cache Manager

```java
TranslateManager translateManager = lightDao.getSqlToyContext().getTranslateManager();
```

> **Prerequisite**: to dynamically extend cache translation, a `translate.xml` (i.e., the cache translate configuration file pointed to by `spring.sqltoy.translateConfig`) must be configured; it may contain no concrete cache configuration at all.

## 2. Common Operations

`TranslateManager` provides comprehensive operation capabilities over caches:

| Method | Description |
| --- | --- |
| `existCache(String cacheName)` | Whether a cache exists |
| `getCacheNames()` | Get all cache names |
| `getCacheData(String cacheName, String cacheType)` | Get the data of a cache (`HashMap<String, Object[]>`) |
| `putCacheData(String cacheName, String cacheType, HashMap<String,Object[]> cacheValue)` | Write/update cache data |
| `clear(String cacheName, String cacheType)` | Clear the data of a cache |
| `getCacheConfig(String cacheName)` | Get the cache configuration model |
| `putCache(TranslateConfigModel model)` | **Dynamically add a cache** |
| `removeCache(String cacheName)` | Dynamically remove a cache |
| `putCacheUpdater(CheckerConfigModel model)` | Dynamically add a cache update checker |
| `removeCacheUpdater(CheckerConfigModel model)` | Remove a cache update checker |
| `getAllTranslates()` | Get all cache translate configurations |

## 3. Two Typical Scenarios

**1) Only dynamically control cache data** (the cache is already defined in translate.xml): directly use `getCacheData`/`putCacheData`/`clear` to read, write, and refresh cache content — for example, proactively refreshing the cached value of a code after a business change.

**2) Dynamically extend caches** (adding cache definitions at runtime): use `putCache(TranslateConfigModel)` to dynamically register a new cache, and attach an update checker to it with `putCacheUpdater`, extending the cache translation capability on demand at runtime.

> For the basic usage of Cache Translate, see [Cache Translate usage](../quickstart/translates.md); for the FIFO dynamic cache of large-scale master data, see [Large-Scale Master-Data Cache (FIFO)](sqltoy_FIFO_translate.md).
