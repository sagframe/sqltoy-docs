# 开发环境与依赖

## 一、环境要求

| 项 | 要求 |
| --- | --- |
| JDK | **17+**（6.0.2 面向 JDK17 / Spring Boot 3/4）；JDK8 项目请使用 `5.6.96.jre8`（最终 jre8 版本，支持 quickvo-maven-plugin 插件） |
| 构建工具 | Maven 3.6+ 或 Gradle |
| 数据库 | 任意 JDBC 数据库（MySQL/Oracle/PostgreSQL/达梦/高斯/SQL Server/DB2 等，详见[支持的数据库](../introduction/db_list.md)） |
| 连接池 | Druid、HikariCP 等任意连接池（sqltoy 不绑定连接池） |

> [!NOTE]
> 版本号请以 [Maven Central](https://mvnrepository.com/artifact/com.sagframe/sagacity-sqltoy) 最新版为准，本文以 `6.0.2` 为例。

## 二、引入依赖

根据所用框架选择对应 artifact（groupId 均为 `com.sagframe`）：

**Spring Boot（推荐，自动配置）**

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-spring-starter</artifactId>
    <version>6.0.2</version>
</dependency>
```

**传统 Spring（XML/Java 配置）**

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-spring</artifactId>
    <version>6.0.2</version>
</dependency>
```

**Solon**

```xml
<dependency>
    <groupId>com.sagframe</groupId>
    <artifactId>sagacity-sqltoy-solon-plugin</artifactId>
    <version>6.0.2</version>
</dependency>
```

**纯 Java**：直接引入核心包 `sagacity-sqltoy` 即可，参见[纯 Java 项目如何使用](../config/pure_java.md)。

## 三、连接池与数据源

- 演示项目使用 **Druid** 连接池，但 sqltoy 并不限定连接池，按实际情况选配即可。
- Spring Boot 默认连接池是 **HikariCP**，需引入 `spring-boot-starter-jdbc` 才会自动初始化数据源。
- 务必**先配置好 dataSource 及连接池**，再配置 sqltoy。

## 四、缓存翻译依赖（可选）

如使用[缓存翻译](../quickstart/translates.md)功能，需引入缓存实现。sqltoy 默认支持 **ehcache**，也可选配 **caffeine**：

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

> 为什么默认不用 Redis 做翻译缓存？因为缓存翻译追求**本地零网络开销**的高频码值转换，本地缓存（ehcache/caffeine）性能更佳；超大规模主数据场景可用 [FIFO 动态缓存](../translate/sqltoy_FIFO_translate.md)。

## 五、下一步

- 完整的建项目→建表→生成 POJO→写查询流程，见 [helloworld 快速上手](../quickstart/helloworld.md)。
- POJO/VO 由 **quickvo** 工具根据数据库表自动生成，见 [quickvo 代码生成工具](quickvo.md)。
