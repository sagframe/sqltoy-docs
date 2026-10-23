# Solon Integration Reference

sqltoy supports the [Solon](https://solon.noear.org/) framework through the standalone `sagacity-sqltoy-solon-plugin` module. The APIs are identical to the Spring version (LightDao / SqlToyLazyDao / SqlToyCRUDService, etc.); only configuration and injection differ. For a hands-on introduction, see the [helloworld-solon demo](en/quickstart/helloworld_solon.md).

## 1. Dependency and Version Requirements

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-solon-plugin</artifactId>
    <!-- keep the same version number as core -->
    <version>6.0.9</version>
</dependency>
```

- Built against **Solon 4.1.1**, with transitive dependencies on `solon-aot` and `solon-data`;
- Datasources are managed by the Solon container (register connection pools such as HikariCP as beans yourself); sqltoy does not manage them a second time.

## 2. Configuration (the solon.sqltoy prefix)

The configuration prefix is **`solon.sqltoy`** (the legacy prefix `sqltoy` is still honored); property names map almost one-to-one to the Spring version's `spring.sqltoy.*` — refer directly to [sqltoy Configuration Parameters](en/config/sqltoy_config.md) for their meanings:

```yaml
solon.sqltoy:
  # sql scan path inside the xml (comma-separated for multiple)
  sqlResourcesDir: classpath:sqltoy
  # default classpath:sqltoy-translate.xml
  translateConfig: classpath:sqltoy-translate.xml
  debug: true
  # cross-database function adaptation (on by default)
  #functionConverts: default
```

Two differences from the Spring version:

| Difference | Description |
| --- | --- |
| `cacheType` defaults to `solon` | Cache translate uses the Solon local cache manager (`SolonTranslateCacheManager`) by default; the Spring version defaults to `ehcache` |
| debug linkage | When Solon starts in debug mode (`Solon.cfg().isDebugMode()`), sqltoy's debug output is force-enabled |

## 3. @Db Injection

On Solon you do not use `@Autowired`; injection goes through `org.sagacity.sqltoy.solon.annotation.Db` (on fields or method parameters):

| Injection target | Description |
| --- | --- |
| `javax.sql.DataSource` | Inject the datasource directly |
| `SqlToyLazyDao` | Full-featured Dao |
| `LightDao` | Lightweight Dao (recommended for direct use in Services) |
| `SqlToyCRUDService` | Generic CRUD service |

The `@Db` value specifies the datasource bean name; omit it for the default datasource:

```java
@Controller
public class TestController {

    // default datasource
    @Db
    private LightDao lightDao;

    // by datasource bean name (matching @Bean(name="db1"))
    @Db("db1")
    private SqlToyLazyDao db1Dao;
}
```

The datasource-selection mechanism (the `datasource` attribute in sql, the lazyDao chained `.dataSource(...)`, the `defaultDataSource` fallback, etc.) is the same as the Spring version — see [Multi-Datasource and Transactions](en/config/dynamic_datasource.md).

## 4. GraalVM Native

The solon-plugin ships `org.sagacity.sqltoy.solon.integration.aot.SqltoyRuntimeNativeRegistrar` (implementing Solon's `RuntimeNativeRegistrar` interface). When building a native image it automatically registers sqltoy's configuration resources (`sqltoy-translate.xml`, etc.) and entity-class reflection metadata — no manual reflect-config additions needed; since 6.0.8 it also registers resource patterns and extension-class reflection dynamically from the configuration, and supports `native-reflection-packages` / `native-reflection-classes` for non-entity DTO/VO reflection.

> For the Spring Boot side of AOT and the full native guide, see the [GraalVM Native Image Guide](en/tools/graalvm_native.md).
