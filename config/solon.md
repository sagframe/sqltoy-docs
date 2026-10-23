# Solon 集成参考

sqltoy 通过独立的 `sagacity-sqltoy-solon-plugin` 模块支持 [Solon](https://solon.noear.org/) 框架，API 与 Spring 版完全一致（LightDao / SqlToyLazyDao / SqlToyCRUDService 等），差异只在配置与注入方式。入门实战见 [helloworld-solon 案例](quickstart/helloworld_solon.md)。

## 一、依赖与版本要求

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-solon-plugin</artifactId>
    <!-- 与 core 保持同版本号 -->
    <version>6.0.9</version>
</dependency>
```

- 基于 **Solon 4.1.1** 构建，传递依赖 `solon-aot`、`solon-data`；
- 数据源由 Solon 容器管理（HikariCP、liteflow 等连接池自行注册为 bean），sqltoy 不重复托管。

## 二、配置（solon.sqltoy 前缀）

配置前缀为 **`solon.sqltoy`**（兼容旧前缀 `sqltoy`）；属性名与 Spring 版 `spring.sqltoy.*` 几乎一一对应，参数含义直接参阅[sqltoy 配置参数](config/sqltoy_config.md)即可：

```yaml
solon.sqltoy:
  # xml 中的 sql 扫描路径(多个用逗号分隔)
  sqlResourcesDir: classpath:sqltoy
  # 默认 classpath:sqltoy-translate.xml
  translateConfig: classpath:sqltoy-translate.xml
  debug: true
  # 函数跨库自适配(默认开启)
  #functionConverts: default
```

与 Spring 版的两点差异：

| 差异点 | 说明 |
| --- | --- |
| `cacheType` 默认值为 `solon` | 缓存翻译默认使用 Solon 本地缓存管理器（`SolonTranslateCacheManager`）；Spring 版默认 `ehcache` |
| debug 联动 | Solon 以 debug 模式启动时（`Solon.cfg().isDebugMode()`），强制开启 sqltoy 的 debug 输出 |

## 三、@Db 注入

Solon 侧不使用 `@Autowired`，而是通过 `org.sagacity.sqltoy.solon.annotation.Db` 注入（可标注字段或方法参数）：

| 注入目标 | 说明 |
| --- | --- |
| `javax.sql.DataSource` | 直接注入数据源 |
| `SqlToyLazyDao` | 全功能 Dao |
| `LightDao` | 轻量 Dao（推荐 Service 中直接使用） |
| `SqlToyCRUDService` | 通用 CRUD 服务 |

`@Db` 的 value 指定数据源 bean 名，缺省为默认数据源：

```java
@Controller
public class TestController {

    // 默认数据源
    @Db
    private LightDao lightDao;

    // 指定数据源 bean 名(对应 @Bean(name="db1") 的数据源)
    @Db("db1")
    private SqlToyLazyDao db1Dao;
}
```

多数据源的选择机制（sql 中 `datasource` 属性、lazyDao 链式 `.dataSource(...)`、`defaultDataSource` 兜底等）与 Spring 版一致，参见[多数据源与事务](config/dynamic_datasource.md)。

## 四、GraalVM Native

solon-plugin 内置 `org.sagacity.sqltoy.solon.integration.aot.SqltoyRuntimeNativeRegistrar`（实现 Solon 的 `RuntimeNativeRegistrar` 接口），构建 native image 时自动注册 sqltoy 配置资源（`sqltoy-translate.xml` 等）与实体类反射元数据，无需手工追加 reflect-config；6.0.8 起同样按配置动态注册资源 pattern、扩展类反射，并支持用 `native-reflection-packages` / `native-reflection-classes` 登记非实体 DTO/VO 的反射。

> Spring Boot 侧的 AOT 说明与完整 native 指引见 [GraalVM Native Image 指引](tools/graalvm_native.md)。
