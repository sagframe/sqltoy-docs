# 动态控制缓存

sqltoy 自 5.2.8 版本起，可以灵活地**动态扩展缓存、动态扩展缓存更新检测程序**，并实时更新缓存数据。这一切通过 `TranslateManager`（缓存翻译管理器）完成。

## 一、获取缓存管理器

```java
TranslateManager translateManager = lightDao.getSqlToyContext().getTranslateManager();
```

> **前提**：动态扩展缓存翻译，必须配置一个 `translate.xml`（即 `spring.sqltoy.translateConfig` 指向的缓存翻译配置文件），其中可以不具体配置任何缓存。

## 二、常用操作

`TranslateManager` 提供了对缓存的全面操作能力：

| 方法 | 说明 |
| --- | --- |
| `existCache(String cacheName)` | 判断缓存是否存在 |
| `getCacheNames()` | 获取全部缓存名称 |
| `getCacheData(String cacheName, String cacheType)` | 获取某个缓存的数据（`HashMap<String, Object[]>`） |
| `putCacheData(String cacheName, String cacheType, HashMap<String,Object[]> cacheValue)` | 写入/更新缓存数据 |
| `clear(String cacheName, String cacheType)` | 清除某个缓存的数据 |
| `getCacheConfig(String cacheName)` | 获取缓存配置模型 |
| `putCache(TranslateConfigModel model)` | **动态新增一个缓存** |
| `removeCache(String cacheName)` | 动态移除一个缓存 |
| `putCacheUpdater(CheckerConfigModel model)` | 动态新增缓存更新检测器 |
| `removeCacheUpdater(CheckerConfigModel model)` | 移除缓存更新检测器 |
| `getAllTranslates()` | 获取全部缓存翻译配置 |

## 三、两类典型场景

**1）只动态控制缓存数据**（缓存已在 translate.xml 中定义）：直接用 `getCacheData`/`putCacheData`/`clear` 读写、刷新缓存内容，例如业务变更后主动刷新某条码值缓存。

**2）动态扩展缓存**（运行时新增缓存定义）：用 `putCache(TranslateConfigModel)` 动态注册一个新缓存，并可用 `putCacheUpdater` 为其挂载更新检测器，实现运行时按需扩展缓存翻译能力。

> 缓存翻译的基本用法见[缓存翻译使用](../quickstart/translates.md)；超大规模主数据的 FIFO 动态缓存见[超大规模主数据缓存](sqltoy_FIFO_translate.md)。
