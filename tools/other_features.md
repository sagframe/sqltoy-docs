# 其他特性

本页汇总几个使用频率较低、但特定场景下很有价值的能力。

## 一、GraalVM Native Image（AOT 原生支持）

`sagacity-sqltoy-spring-starter` 内置 Spring AOT 支持，**开箱即用、无需手工配置**（经 `META-INF/spring/aot.factories` 自动注册），按 Spring Boot 3 官方方式构建原生镜像即可：

| 组件 | 作用 |
| --- | --- |
| `SqlToyBeanFactoryInitializationAotProcessor` | 构建期为**全部已注册实体类**注册反射 hints，保障 GraalVM Native Image 下 ORM 反射可用 |
| `SqlToyRuntimeHintsRegistrar` | 为配置属性类、主键生成器及缓存翻译相关资源注册反射与资源访问 hints |

```bash
# 按 Spring Boot 3 标准方式构建 native image，sqltoy 的 hints 自动生效
mvn -Pnative native:compile
```

## 二、geometry 空间类型支持（JTS）

sqltoy 内置对数据库 **geometry 空间列**的自动适配（GIS 场景），核心在 `GeometryTypeUtil`：

- 自动识别 geometry 列类型，处理 **MySQL internal bytes ↔ WKT**、**Oracle SDO ↔ WKT** 的转换；
- classpath 存在 **JTS**（`org.locationtech.jts`，`hasJts()` 自动探测）时，查询结果自动解析为 **JTS `Geometry` 对象**，写入时同样支持 `Geometry` 对象；
- 未引入 JTS 时，以 **WKT 字符串**（如 `POINT(121.4 31.2)`）交互。

```xml
<!-- 使用 Geometry 对象交互时引入 JTS -->
<dependency>
    <groupId>org.locationtech.jts</groupId>
    <artifactId>jts-core</artifactId>
    <version>1.20.0</version>
</dependency>
```

> POJO 的 geometry 属性声明为 JTS `Geometry`（或 WKT 字符串）即可，读写由框架自动编解码（`JtsGeometryCodec` / `GeometryTypeUtil`）。

## 三、公共字段赋值开关（UnifyUpdateFieldsController）

配置了[统一字段处理器](../quickstart/helloworld_improve.md)（unifyFieldsHandler）后，save/update 会自动补漏 `updateBy`/`updateTime` 等公共字段。个别场景（如系统级数据修复脚本，不希望改动"最后更新人"）可临时**暂停**当前线程的公共字段赋值：

```java
try {
    // 暂停当前线程的公共字段自动赋值（ThreadLocal 开关，只影响当前线程）
    UnifyUpdateFieldsController.stop();
    lightDao.update(fixEntity);   // 本次更新不自动填充 updateBy/updateTime
} finally {
    // 必须恢复，否则当前线程后续操作都不会自动赋值
    UnifyUpdateFieldsController.resume();
}
```

| 方法 | 说明 |
| --- | --- |
| `stop()` | 暂停当前线程公共字段赋值 |
| `resume()` | 恢复当前线程公共字段赋值 |
| `useUnifyFields()` | 查询当前线程是否启用 |

## 四、自定义 Connection 操作（DataSourceCallbackHandler）

需要使用框架未封装的原生 JDBC 能力时，自定义 Dao 继承 `SpringDaoSupport`（或 `SqlToyDaoSupport`），通过 `DataSourceUtils.processDataSource` + 匿名 `DataSourceCallbackHandler` 拿到原生 `Connection` 自行处理（框架负责连接获取与释放）：

```java
public class MySpecialDao extends SpringDaoSupport {

    // 参照框架内部的使用模式
    public Object doSpecial(final DataSource dataSource) {
        DataSourceUtils.processDataSource(getSqlToyContext(),
                getDataSource(dataSource),
                new DataSourceCallbackHandler() {
                    @Override
                    public void doConnection(Connection conn, DBProfile profile) throws Exception {
                        // profile 为数据库执行档案：getDbType()/getDialect()/getProductName()/getMajorVersion()
                        // 以及 isMysqlFamily()/isOracleFamily()/isOceanBase() 等便捷判断
                        try (PreparedStatement pst = conn.prepareStatement("select ...")) {
                            ResultSet rs = pst.executeQuery();
                            // ... 自行处理 rs
                            setResult(result);   // 处理结果放回，供外部 getResult() 获取
                        }
                    }
                });
        return getResult();
    }
}
```

| 成员 | 说明 |
| --- | --- |
| `doConnection(conn, profile)` | 抽象方法，拿到原生 `Connection` 与 `DBProfile` 数据库执行档案，自行处理 |
| `DBProfile` | 提供 `getDbType()`/`getDialect()`/`getUrl()`/`getProductName()`/`getMajorVersion()`，及 `isMysqlFamily()`/`isOracleFamily()`/`isOceanBase()`/`isBackslashEscape()` 等便捷判断 |
| `setResult(...)` / `getResult()` | 在回调中暂存结果 / 外部获取结果 |

> **版本说明**：6.0 起回调签名由 `doConnection(Connection conn, Integer dbType, String dialect)` 调整为 `doConnection(Connection conn, DBProfile profile)`（`org.sagacity.sqltoy.model.DBProfile`），5.6.x 版本请按旧签名使用。
