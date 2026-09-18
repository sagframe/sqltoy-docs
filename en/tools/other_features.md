# Other Features

This page summarizes a few less frequently used capabilities that are quite valuable in specific scenarios.

## 1. GraalVM Native Image (AOT Support)

`sagacity-sqltoy-spring-starter` ships with built-in Spring AOT support — **works out of the box with no manual configuration** (auto-registered via `META-INF/spring/aot.factories`). Simply build the native image the official Spring Boot 3 way:

| Component | Purpose |
| --- | --- |
| `SqlToyBeanFactoryInitializationAotProcessor` | Registers reflection hints at build time for **all registered entity classes**, ensuring ORM reflection works under GraalVM Native Image |
| `SqlToyRuntimeHintsRegistrar` | Registers reflection and resource-access hints for configuration property classes, primary key generators, and cache-translate related resources |

```bash
# Build the native image the standard Spring Boot 3 way; sqltoy's hints take effect automatically
mvn -Pnative native:compile
```

## 2. geometry Spatial Type Support (JTS)

sqltoy has built-in automatic adaptation for database **geometry spatial columns** (GIS scenarios); the core logic lives in `GeometryTypeUtil`:

- Automatically recognizes geometry column types and handles conversions between **MySQL internal bytes ↔ WKT** and **Oracle SDO ↔ WKT**;
- When **JTS** (`org.locationtech.jts`, auto-detected by `hasJts()`) is on the classpath, query results are automatically parsed into **JTS `Geometry` objects**, and writing `Geometry` objects is supported as well;
- Without JTS, interaction happens through **WKT strings** (e.g. `POINT(121.4 31.2)`).

```xml
<!-- Add the JTS dependency when interacting with Geometry objects -->
<dependency>
    <groupId>org.locationtech.jts</groupId>
    <artifactId>jts-core</artifactId>
    <version>1.20.0</version>
</dependency>
```

> Simply declare the POJO's geometry property as a JTS `Geometry` (or a WKT string); reading and writing is encoded/decoded automatically by the framework (`JtsGeometryCodec` / `GeometryTypeUtil`).

## 3. Common-Field Auto-Fill Switch (UnifyUpdateFieldsController)

Once a [unified fields handler](../quickstart/helloworld_improve.md) (unifyFieldsHandler) is configured, save/update automatically fills in common fields such as `updateBy`/`updateTime`. In certain scenarios (e.g. system-level data repair scripts where you don't want to alter "last updated by"), you can temporarily **pause** common-field auto-fill for the current thread:

```java
try {
    // Pause automatic common-field filling for the current thread (a ThreadLocal switch; only affects the current thread)
    UnifyUpdateFieldsController.stop();
    lightDao.update(fixEntity);   // this update will not auto-fill updateBy/updateTime
} finally {
    // Must resume, otherwise no later operations on this thread will auto-fill
    UnifyUpdateFieldsController.resume();
}
```

| Method | Description |
| --- | --- |
| `stop()` | Pauses common-field auto-fill for the current thread |
| `resume()` | Resumes common-field auto-fill for the current thread |
| `useUnifyFields()` | Checks whether the current thread has it enabled |

## 4. Custom Connection Operations (DataSourceCallbackHandler)

When you need raw JDBC capabilities not wrapped by the framework, write a custom Dao extending `SpringDaoSupport` (or `SqlToyDaoSupport`) and use `DataSourceUtils.processDataSource` together with an anonymous `DataSourceCallbackHandler` to obtain the raw `Connection` and handle it yourself (the framework takes care of acquiring and releasing the connection):

```java
public class MySpecialDao extends SpringDaoSupport {

    // Follow the framework's internal usage pattern
    public Object doSpecial(final DataSource dataSource) {
        DataSourceUtils.processDataSource(getSqlToyContext(),
                getDataSource(dataSource),
                new DataSourceCallbackHandler() {
                    @Override
                    public void doConnection(Connection conn, DBProfile profile) throws Exception {
                        // profile is the database execution profile: getDbType()/getDialect()/getProductName()/getMajorVersion()
                        // plus convenient checks such as isMysqlFamily()/isOracleFamily()/isOceanBase()
                        try (PreparedStatement pst = conn.prepareStatement("select ...")) {
                            ResultSet rs = pst.executeQuery();
                            // ... process rs yourself
                            setResult(result);   // put the result back so it can be fetched via getResult()
                        }
                    }
                });
        return getResult();
    }
}
```

| Member | Description |
| --- | --- |
| `doConnection(conn, profile)` | Abstract method; you receive the raw `Connection` plus the `DBProfile` database execution profile and handle it yourself |
| `DBProfile` | Provides `getDbType()`/`getDialect()`/`getUrl()`/`getProductName()`/`getMajorVersion()`, plus convenient checks such as `isMysqlFamily()`/`isOracleFamily()`/`isOceanBase()`/`isBackslashEscape()` |
| `setResult(...)` / `getResult()` | Stash the result inside the callback / fetch it from outside |

> **Version note**: starting with 6.0 the callback signature changed from `doConnection(Connection conn, Integer dbType, String dialect)` to `doConnection(Connection conn, DBProfile profile)` (`org.sagacity.sqltoy.model.DBProfile`); on 5.6.x please use the old signature.
