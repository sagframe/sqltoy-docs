# Environment & Dependencies

## 1. Environment Requirements

| Item | Requirement |
| --- | --- |
| JDK | **17+** (6.0.1 targets JDK17 / Spring Boot 3/4); for JDK8 projects use `5.6.95.jre8` (the final jre8 version) |
| Build tool | Maven 3.6+ or Gradle |
| Database | Any JDBC database (MySQL/Oracle/PostgreSQL/Dameng/GaussDB/SQL Server/DB2, etc.; see [Supported Databases](../introduction/db_list.md)) |
| Connection pool | Druid, HikariCP or any other connection pool (sqltoy is not bound to a connection pool) |

> [!NOTE]
> For version numbers, refer to the latest release on [Maven Central](https://mvnrepository.com/artifact/com.sagframe/sagacity-sqltoy); this article uses `6.0.1` as an example.

## 2. Add Dependencies

Choose the corresponding artifact according to the framework you use (the groupId is always `com.sagframe`):

**Spring Boot (recommended, auto-configuration)**

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-spring-starter</artifactId>
    <version>6.0.1</version>
</dependency>
```

**Traditional Spring (XML/Java configuration)**

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-spring</artifactId>
    <version>6.0.1</version>
</dependency>
```

**Solon**

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-solon-plugin</artifactId>
    <version>6.0.1</version>
</dependency>
```

**Pure Java**: just include the core package `sagacity-sqltoy`; see [How to Use sqltoy in a Pure Java Project](../config/pure_java.md).

## 3. Connection Pool and Datasource

- The demo project uses the **Druid** connection pool, but sqltoy does not mandate a connection pool — choose one according to your actual situation.
- Spring Boot's default connection pool is **HikariCP**; `spring-boot-starter-jdbc` must be included for the datasource to be initialized automatically.
- Make sure to **configure the dataSource and connection pool first**, and then configure sqltoy.

## 4. Cache Translate Dependencies (Optional)

If you use the [cache translate](../quickstart/translates.md) feature, a cache implementation is required. sqltoy supports **ehcache** by default, and **caffeine** can also be selected:

```xml
<dependency>
    <groupId>org.ehcache</groupId>
    <artifactId>ehcache</artifactId>
    <version>3.12.0</version>
    <exclusions>
        <exclusion>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-api</artifactId>
        </exclusion>
    </exclusions>
</dependency>
```

> Why not use Redis as the translate cache by default? Because cache translate pursues high-frequency code-value conversion with **zero local network overhead**, and local caches (ehcache/caffeine) perform better. For very large master data scenarios, use the [FIFO dynamic cache](../translate/sqltoy_FIFO_translate.md).

## 5. Next Steps

- For the complete flow of creating a project → creating tables → generating POJOs → writing queries, see [helloworld Quick Start](../quickstart/helloworld.md).
- POJOs/VOs are generated automatically from database tables by the **quickvo** tool; see the [quickvo Code Generator](quickvo.md).
