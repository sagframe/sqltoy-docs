# GraalVM Native Image 指引

sqltoy 的 spring-starter 与 solon-plugin 均内置 AOT/native 支持：构建期自动注册 ORM 所需的反射与资源元数据，运行期自动切换为镜像内资源加载。本页给出完整的支持形态、构建步骤、应用侧必要配合与已知限制。

> **版本说明**：AOT 支持自 5.6 引入；**6.0.8 起**大幅增强（按实际配置动态注册资源与扩展类，实体扫描不再依赖构建期 bean 快照），本文以 6.0.8 为准，6.0.7 及以下的差异在各节单独标注。

## 一、支持形态总览

| 模块 | AOT 组件 | 注册方式 | 作用 |
| --- | --- | --- | --- |
| `sagacity-sqltoy-spring-starter` | `SqltoyRuntimeHintsRegistrar` | `META-INF/spring/aot.factories` 自动注册 | 固定资源 pattern（`sqltoy-translate.xml`、`translates/**`、`sqltoy/**`）+ 配置属性类、5 个内置主键生成器反射 |
| `sagacity-sqltoy-spring-starter` | `SqltoyBeanFactoryInitializationAotProcessor` | 同上 | 实体反射、按配置动态注册的资源 pattern 与扩展类反射（6.0.8 起，见第三节） |
| `sagacity-sqltoy-solon-plugin` | `SqltoyRuntimeNativeRegistrar` | `SqlToyPluginImpl` 在 AOT 模式下自动挂载 | 与 spring 侧对称（solon 的 AOT 构建走真实启动流程，配置 bean 真实可用） |

**native 运行期自适配**（所有版本）：sqltoy 检测到 `org.graalvm.nativeimage.imagecode` 系统属性后，把 `sqlResourcesDir` 目录配置转换为逐个 `.sql.xml` 的镜像内资源列表加载（`SqlScriptLoader` 按资源列表模式工作），solon 侧对 `translateConfig` 同样处理。

> [!NOTE]
> 由此带来一个行为差异：native 下 sql 文件已打进镜像，**debug 模式的 sql 文件热更新自动失效**（文件变更检测只对文件系统上的 File 资源生效）。

## 二、构建步骤（Spring Boot）

前置条件（与 Spring Boot 官方要求一致，详见 [Spring Boot Native Image 文档](https://docs.spring.io/spring-boot/reference/packaging/native-image/index.html)）：

- **GraalVM JDK 23+（建议 25）**：旧版本与当前 GraalVM reachability metadata repository 不兼容——17 不支持新元数据 schema（native-maven-plugin 直接报错），21 不支持 `typeReached` 条件元数据（条件被当作恒真，spring-aop 的 AspectJ 序列化条目被误注册，无 aspectjweaver 时构建失败）；CI 中常用 `graalvm-community`；
- Windows 需安装 Visual Studio Build Tools（MSVC），Linux 需 gcc 工具链，macOS 需 Xcode Command Line Tools。

> [!NOTE]
> 项目使用 lombok 时注意：JDK 23+ 的 javac 不再隐式运行 classpath 上的注解处理器，需在 `maven-compiler-plugin` 的 `annotationProcessorPaths` 中显式声明 lombok，否则用 GraalVM 25 编译时实体 getter/setter 不会生成。

项目 parent 为 `spring-boot-starter-parent` 时自带 `native` profile，直接构建：

```bash
# 构建原生镜像（sqltoy 的 AOT 元数据自动生效）
mvn -Pnative native:compile -DskipTests

# 运行
./target/your-app
```

## 三、应用侧必要配合

### 1. packagesToScan 必配（所有版本）

sqltoy 实体是**即用即加载**的（首次使用时才解析注册），而 native 构建只能在构建期登记反射元数据。因此 native 场景必须配置 `packagesToScan`（或 `annotatedClasses`），让实体在启动期完成注册：

```yaml
spring:
    sqltoy:
        # native 场景必配:构建期按此包扫描 @Entity 注册反射元数据
        packagesToScan: com.yourcorp.project.entity
        sqlResourcesDir: classpath:sqltoy
```

> 普通 JVM 场景该配置非必需（实体按需解析），配置后仅意味着启动期提前解析，行为无差异。

### 2. 资源与扩展类注册（6.0.8 起自动）

**6.0.8 起**，`SqltoyBeanFactoryInitializationAotProcessor` 直接从 Environment 绑定 `spring.sqltoy` 配置（AOT 构建期容器不实例化/绑定 bean，此前依赖 bean 快照的实现拿不到配置），自动注册：

| 注册内容 | 配置来源 |
| --- | --- |
| 实体反射 | `packagesToScan` / `annotatedClasses` 扫描 |
| sql 文件资源 pattern | `sqlResourcesDir`（多目录分隔）、`sqlResources` |
| 翻译配置资源 | `translateConfig`（`.xml` 按文件、目录按 `/**`） |
| 密钥资源 | `securePublicKey` / `securePrivateKey` |
| 扩展类反射 | `unifyFieldsHandler`、`typeHandler`、`sqlInterceptors`、`sqlFormater`（含 `default` 别名展开）、`translateCacheManager`、`dataSourceSelector`、`connectionFactory`、`fieldsSecureProvider`、`desensitizeProvider`、`customFilterHandler`、`overTimeSqlHandler`、`dialectDDLGenerator`、`firstBizCodeTrace`、`dynamicCacheFetch`、`dynamicFecthCacheManager`（约定同运行期：含 `.` 视为类名，否则为 bean 名称由 Spring AOT 覆盖）、`functionConverts`（含 `default` 展开的内置函数集，经 `FunctionUtils.resolveFunctionClassNames` 与运行期同语义解析） |
| 集成类反射（条件） | 注册跟随 classpath 而非构建期配置：caffeine 库在 → 翻译缓存管理器（ehcache 管理器为运行期直接 new，无需注册）；mongo 驱动在 → `SpringMongoQuery`；spring-data-redis 在 → `SpringRedisIdGenerator` |
| 扩展类型驱动专属类（条件） | 对应驱动在 classpath 时注册：PG 系 `PGobject` 同构类 5 个（postgresql 及 stardb 等兜底、opengauss/mogdb、vastbase、gaussdb、kingbase 的 `KBobject`——json/jsonb/vector/geometry 经反射构造与读写）、mssql-jdbc 的 `Geometry`/`Vector`、oracle 的 `OracleTypes` |
| JsonProvider 反射 | classpath 上存在对应 JSON 库的**全部**内置实现（fastjson2/jackson3/jackson2 按各自 marker）+ 显式配置的自定义实现类名 |
| lambda 序列化基础 | `SerializedLambda` 与 sqltoy 镜像类的 java 序列化注册（固定；还需应用侧配合注册 lambda 定义类，见下节） |

即：**按配置约定使用 sqltoy 的应用，6.0.8 起 native 构建零额外代码**。

> [!WARNING]
> `sqlFormater` 的内置实现 `DefaultSqlFormater` 硬依赖 druid（core 中标记 optional）：配置 `sqlFormater` 的应用需自行引入 druid，否则 debug 统计路径（`SqlExecuteStat`）触发格式化时 `NoClassDefFoundError`（debug 关闭不触发）。

> [!NOTE]
> **运行期动态切换**：native 镜像在构建期冻结，因此集成类与 JsonProvider 的注册跟随 **classpath**（而非构建期的 `cacheType`/`jsonProvider` 取值）——只要对应库在 classpath 上，运行期用启动参数切换 `cacheType`（ehcache↔caffeine）或 `jsonProvider`（fastjson2/jackson3/jackson2/自定义）均可用，sqltoy-aot-verify 已双框架实测切换轮。

### 3. 仍归应用侧的部分（任何版本）

以下五类框架无从推断，由应用注册——完整可运行示范见 [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify)（`AotVerifyRuntimeHints` / solon `Config#aotVerifyNativeRegistrar`）与 showcase 的 [`ShowcaseRuntimeHints`](https://github.com/sagframe/sqltoy-showcase/blob/master/src/main/java/com/sqltoy/showcase/config/ShowcaseRuntimeHints.java)：

1. **应用代码自行加载的 classpath 资源**：如启动建表脚本（showcase 的 `mock/schema-*.sql` 由 `DataSourceConfig` 自己读取）；
2. **被 SQL/第三方机制按类名引用的类**：如 H2 的 `CREATE ALIAS ... FOR 'com.x.Procedures.listStaff'`（运行期由 H2 `Class.forName` 加载）；
3. **接口返回类型 + `initMethod`/事务代理的 `@Bean`**：Spring AOT 按声明类型预判 bean 类型，接口声明会让具体类不可见（native 运行期报 init 方法找不到或 "CGLIB runtime enhancement not supported"）——**改用具体返回类型声明即可**，无需 hints（showcase 的分片策略 bean 与 6.0.8 starter 的 DAO bean 均如此声明）；
4. **作为查询 resultType 的 DTO/VO**：非 `@Entity`（`packagesToScan` 扫不到），运行期由 sqltoy 反射实例化并逐列赋值——注册反射即可；
5. **使用 lambda 条件（lambdaQuery/lambdaUpdate/lambdaDelete）的类**：属性提取经 writeReplace/序列化镜像，native 下需按"lambda 定义类"注册——spring 侧在 `META-INF/native-image/**/serialization-config.json` 声明 `lambdaCapturingTypes`（或 `hints.reflection().registerLambda(定义类, b -> b.withInterfaces(LambdaFn.class))`），solon 侧 `metadata.registerLambdaSerialization(定义类)`；不注册则 lambda 体系在 native 下全部不可用（JVM 不受影响）。

```java
public class ShowcaseRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        // 应用自行加载的启动建表脚本(RSA 密钥已由 starter 按 secure* 配置注册)
        hints.resources().registerPattern("mock/**");
        // H2 CREATE ALIAS 按类名引用,运行期 Class.forName 加载
        hints.reflection().registerType(Procedures.class, MemberCategory.values());
    }
}

// 启动类挂载
@SpringBootApplication
@ImportRuntimeHints(ShowcaseRuntimeHints.class)
public class ShowcaseApplication { ... }
```

> [!TIP]
> sql 文件放在 `classpath:sqltoy/` 下（solon 默认约定）可命中内置固定 pattern，任何版本都无需为 sql 资源写注册代码。

> **历史注记（6.0.7 及以下）**：starter 的 AOT 实体注册在 Spring AOT 下不生效（构建期配置 bean 未绑定、实体快照为空），且内置固定 pattern 只覆盖 `sqltoy/**`、`translates/**`、`sqltoy-translate.xml` 约定目录，应用需自行补齐五件事：① 自定义 sql 目录的资源 pattern；② 按类名配置的扩展类反射；③ 实体反射（扫描 `packagesToScan` 同款包下的 `@Entity`）；④ sqltoy XML 解析的 8 个模型类反射（缺失时 `<unpivot>`/`<tree-sort>`/环比等标签属性**静默丢失**并解析 NPE）；⑤ DAO bean 用具体返回类型覆盖声明。完整 6.0.7 时代配方可查 showcase 仓库历史。

## 四、已知限制

| 限制 | 原因 | 影响范围 |
| --- | --- | --- |
| `updateSaveFetch`（`EntityUpdateCallback`）不可用 | `EntityResultSetProxy` 经 byte-buddy 在运行期生成实体子类，native image 不支持运行期类生成（实测异常形态：`IllegalArgumentException: Could not create type`） | 仅该特性；常规 CRUD/查询不受影响；行不存在时的 insert 分支不经代理，native 可用（实测） |
| sql 文件热更新失效 | sql 文件打进镜像，按资源列表加载，无 File 可监听 | 仅 debug 热更新；开发期用 JVM 模式即可 |
| 启动期出现 "no entity classes ... matched in the sqltoy pojo scan path" 告警属预期 | `EntityScanner` 依赖 file/jar 协议的目录枚举，镜像内不可用，`packagesToScan` 的启动期扫描在 native 下为空 | 无功能影响：实体反射元数据已在构建期注册，运行期按首次使用懒解析（native 冒烟已验证 CRUD/翻译缓存可用） |
| 第三方组件依赖各自元数据 | mongo/ES/redis/ehcache 等客户端的 native 支持由其官方 reachability metadata 提供 | 使用对应组件时按其官方文档确认。已知例子：**fastjson2** 自带的 native-image.properties 漏掉嵌套类（`JSONFactory$CacheItem` 等），GraalVM 25 的 image heap 校验会构建失败，应用需追加构建参数 `--initialize-at-build-time=com.alibaba.fastjson2`（sqltoy-aot-verify 已内置）；补参后其 `JDKUtils` 的 Unsafe 字段偏移仍在构建期重算失败，运行期探测按设计**静默跳过 fastjson2 降级到 jackson3/jackson2**（功能不受影响）——native 下 JSON 列建议使用 jackson2/jackson3（均已实测） |
| JSON 序列化的业务类型 | JsonProvider 实现类已自动注册，但被序列化业务类型是否可达取决于 JSON 库自身的 native 支持 | JSON 列/ES 场景，Spring Boot 对 Jackson 已有内建支持 |

## 五、Solon 集成

solon-plugin 内置 `SqltoyRuntimeNativeRegistrar`（实现 solon 的 `RuntimeNativeRegistrar` 接口，`SqlToyPluginImpl` 在 AOT 模式下自动挂载），注册内容与 spring 侧对称：固定资源 pattern、配置属性类与主键生成器反射、实体反射，6.0.8 起同样按配置动态注册资源 pattern 与扩展类反射。solon 默认 `sqlResourcesDir=classpath:sqltoy` 命中内置 pattern，零配置即可。构建方式参见 solon 官方 native 文档与 [Solon 集成参考](../config/solon.md)。

> [!NOTE]
> solon 把 yml **标量**绑定到 `String[]` 时元素会带上引号（`packagesToScan: com.x.entity` 绑定为 `"com.x.entity"`），带引号包名会让实体扫描静默为空。6.0.8 起插件已自动剥离首尾成对引号，标量与 yaml 列表两种写法均可；6.0.7 及以下请使用 yaml 列表写法。

## 六、演示与验证

**专项验证工程 [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify)**（spring + solon 双栈共用验证矩阵，PostgreSQL pgvector+postgis）：矩阵覆盖 CRUD×json/vector/geometry 三形态（String/float[]/JTS Geometry）、ehcache+caffeine 双实现缓存翻译、updateSaveFetch 代理路径、lambda 单表/join/setExpr/matchAll 守卫/删除；JVM 全矩阵双框架 16/16 PASS，native 冒烟双框架 15 PASS + 1 KNOWN-LIMITATION（updateSaveFetch 代理路径，预期内）。

演示项目 [sqltoy-showcase](https://github.com/sagframe/sqltoy-showcase) 提供两层验证：

1. **JVM 层（随 `mvn test` 运行，无需 GraalVM）**：[`NativeAotTest`](https://github.com/sagframe/sqltoy-showcase/blob/master/src/test/java/com/sqltoy/showcase/NativeAotTest.java) 运行与 `native:compile` 完全相同的 Spring Boot AOT 处理（`SpringApplicationAotProcessor`），解析生成的 `reachability-metadata.json`，断言实体反射、sql/mock 资源 pattern、扩展类反射全部就位；
2. **真实编译（CI）**：[native-build workflow](https://github.com/sagframe/sqltoy-showcase/actions/workflows/native-build.yml) 在 ubuntu + GraalVM 上执行 `mvn -Pnative native:compile`，并以 `--smoke` 参数运行二进制做启动 + 查询路径冒烟（`NativeSmokeRunner`：实体加载、SQL 计数、缓存翻译；手动/每周触发，不占用常规 PR CI）。

> 🎬 完整示例源码：演示项目 sqltoy-showcase 的 `NativeAotTest.java`、`ShowcaseRuntimeHints.java`

## 相关文档

- [其他特性](other_features.md)
- [Solon 集成参考](../config/solon.md)
- [sqltoy 配置参数](../config/sqltoy_config.md)
