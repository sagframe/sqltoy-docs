# GraalVM Native Image 指引

sqltoy 的 spring-starter 与 solon-plugin 均内置 AOT/native 支持：构建期自动注册 ORM 所需的反射与资源元数据，运行期自动切换为镜像内资源加载。本页给出完整的支持形态、构建步骤、应用侧必要配合与已知限制。

> **版本说明**：AOT 支持自 5.6 引入；**6.0.8 起**大幅增强（按实际配置动态注册资源与扩展类，实体扫描不再依赖构建期 bean 快照），本文以 6.0.8 为准，6.0.7 及以下的差异在各节单独标注。

## 一、支持形态总览

| 模块 | AOT 组件 | 注册方式 | 作用 |
| --- | --- | --- | --- |
| `sagacity-sqltoy-spring-starter` | `SqltoyRuntimeHintsRegistrar` | `META-INF/spring/aot.factories` 自动注册 | 固定资源 pattern（`sqltoy-translate.xml`、`translates/**`、`sqltoy/**`）+ 配置属性类、6 个内置主键生成器（Default/UUID/ULID/NanoTime/Redis/Snowflake）反射 |
| `sagacity-sqltoy-spring-starter` | `SqltoyBeanFactoryInitializationAotProcessor` | 同上 | 实体反射、按配置动态注册的资源 pattern 与扩展类反射（6.0.8 起，见第三节） |
| `sagacity-sqltoy-solon-plugin` | `SqltoyRuntimeNativeRegistrar` | `SqlToyPluginImpl` 在 AOT 模式下自动挂载 | 与 spring 侧对称（solon 的 AOT 构建走真实启动流程，配置 bean 真实可用） |

**native 运行期自适配**（所有版本）：sqltoy 检测到 `org.graalvm.nativeimage.imagecode` 系统属性后，把 `sqlResourcesDir` 目录配置转换为逐个 `.sql.xml` 的镜像内资源列表加载（`SqlScriptLoader` 按资源列表模式工作），solon 侧对 `translateConfig` 同样处理。

> [!NOTE]
> 由此带来一个行为差异：native 下 sql 文件已打进镜像，**debug 模式的 sql 文件热更新自动失效**（文件变更检测只对文件系统上的 File 资源生效）。

## 二、构建步骤（Spring Boot）

前置条件（与 Spring Boot 官方要求一致，详见 [Spring Boot Native Image 文档](https://docs.spring.io/spring-boot/reference/packaging/native-image/index.html)）：

- **GraalVM JDK 25+**：低版本与当前 GraalVM reachability metadata repository 不兼容（实测矩阵：**17 与 23** 不识别新元数据 schema，被 native-maven-plugin 直接拒绝；**21** 不支持 `typeReached` 条件元数据——条件被当作恒真，spring-aop 的 AspectJ 序列化条目被误注册，无 aspectjweaver 时构建失败）；25.0.4 已双框架全矩阵验证；CI 中常用 `graalvm-community`；
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

> `packagesToScan` 只覆盖 `@Entity`；查询返回的普通 DTO/VO 用 3.1 的 `native-reflection-packages` / `native-reflection-classes` 登记。

### 2. 资源与扩展类注册（6.0.8 起自动）

**6.0.8 起**，`SqltoyBeanFactoryInitializationAotProcessor` 直接从 Environment 绑定 `spring.sqltoy` 配置（AOT 构建期容器不实例化/绑定 bean，此前依赖 bean 快照的实现拿不到配置），自动注册：

| 注册内容 | 配置来源 |
| --- | --- |
| 实体反射 | `packagesToScan` / `annotatedClasses` 扫描 |
| 主键生成器反射 | 6 个内置生成器固定注册（Default/UUID/ULID/NanoTime/Redis/Snowflake）；实体扫描到的 `@Id(generator/strategy)`、`@BusinessId(generator)` 自定义生成器类随实体自动注册 |
| 配置属性嵌套类 | `Elastic`、`ElasticConfig`（solon 运行期 `cfg().toBean(...)` 绑定嵌套 endpoints 时需要） |
| sql 文件资源 pattern | `sqlResourcesDir`（多目录分隔）、`sqlResources` |
| 翻译配置资源 | `translateConfig`（`.xml` 按文件、目录按 `/**`） |
| 密钥资源 | `securePublicKey` / `securePrivateKey` |
| 扩展类反射 | `unifyFieldsHandler`、`typeHandler`、`sqlInterceptors`、`sqlFormater`（含 `default` 别名展开）、`translateCacheManager`、`dataSourceSelector`、`connectionFactory`、`fieldsSecureProvider`、`desensitizeProvider`、`customFilterHandler`、`overTimeSqlHandler`、`dialectDDLGenerator`、`firstBizCodeTrace`、`dynamicCacheFetch`、`dynamicFecthCacheManager`（约定同运行期：含 `.` 视为类名，否则为 bean 名称由 Spring AOT 覆盖）、`functionConverts`（含 `default` 展开的内置函数集，经 `FunctionUtils.resolveFunctionClassNames` 与运行期同语义解析） |
| 集成类反射（条件） | 注册跟随 classpath 而非构建期配置：caffeine 库在 → 翻译缓存管理器（ehcache 管理器为运行期直接 new，无需注册）；mongo 驱动在 → `SpringMongoQuery`；spring-data-redis 在 → `SpringRedisIdGenerator` |
| 扩展类型驱动专属类（条件） | 对应驱动在 classpath 时注册：PG 系 `PGobject` 同构类 5 个（postgresql 及 stardb 等兜底、opengauss/mogdb、vastbase、gaussdb、kingbase 的 `KBobject`——json/jsonb/vector/geometry 经反射构造与读写）、mssql-jdbc 的 `Geometry`/`Vector`、oracle 的 `OracleTypes` |
| JsonProvider 反射 | classpath 上存在对应 JSON 库的**全部**内置实现（fastjson2/jackson3/jackson2 按各自 marker）+ 显式配置的自定义实现类名 |
| lambda 序列化基础 | `SerializedLambda` 与 sqltoy 镜像类的 java 序列化注册（固定；还需应用侧配合注册 lambda 定义类，见下节） |

即：**实体、资源与扩展类按约定配置后，6.0.8 起 native 构建无需额外 AOT 代码**；非实体 DTO/VO 用下节的 `native-reflection-classes` / `native-reflection-packages` 登记。

> [!WARNING]
> `sqlFormater` 的内置实现 `DefaultSqlFormater` 硬依赖 druid（core 中标记 optional）：配置 `sqlFormater` 的应用需自行引入 druid，否则 debug 统计路径（`SqlExecuteStat`）触发格式化时 `NoClassDefFoundError`（debug 关闭不触发）。

> [!NOTE]
> **运行期动态切换**：native 镜像在构建期冻结，因此集成类与 JsonProvider 的注册跟随 **classpath**（而非构建期的 `cacheType`/`jsonProvider` 取值）——只要对应库在 classpath 上，运行期用启动参数切换 `cacheType`（ehcache↔caffeine）或 `jsonProvider`（fastjson2/jackson3/jackson2/自定义）均可用，sqltoy-aot-verify 已双框架实测切换轮。

### 3. 仍归应用侧的部分（任何版本）

以下五类框架无从推断，由应用注册——完整可运行示范见 [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify)（`AotVerifyRuntimeHints` / solon `Config#aotVerifyNativeRegistrar`）与 showcase 的 [`ShowcaseRuntimeHints`](https://github.com/sagframe/sqltoy-showcase/blob/master/src/main/java/com/sqltoy/showcase/config/ShowcaseRuntimeHints.java)：

1. **应用代码自行加载的 classpath 资源**：如启动建表脚本（showcase 的 `mock/schema-*.sql` 由 `DataSourceConfig` 自己读取）；
2. **被 SQL/第三方机制按类名引用的类**：如 H2 的 `CREATE ALIAS ... FOR 'com.x.Procedures.listStaff'`（运行期由 H2 `Class.forName` 加载）；
3. **接口返回类型 + `initMethod`/事务代理的 `@Bean`**：Spring AOT 按声明类型预判 bean 类型，接口声明会让具体类不可见（native 运行期报 init 方法找不到或 "CGLIB runtime enhancement not supported"）——**改用具体返回类型声明即可**，无需 hints（showcase 的分片策略 bean 与 6.0.8 starter 的 DAO bean 均如此声明）；
4. **作为查询 resultType 的 DTO/VO**：非 `@Entity`（`packagesToScan` 扫不到），运行期由 sqltoy 反射实例化并逐列赋值——6.0.8 起优先用 `native-reflection-classes` / `native-reflection-packages` 配置登记（见 3.1），无需手写 `RuntimeHints`；
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

#### 3.1 DTO/VO 反射登记（6.0.8 起）

`packagesToScan` 只识别 `@Entity`，普通 resultType DTO/VO 不在其中。6.0.8 起两个 starter 都提供两个构建期配置项，由 AOT 处理器自动注册反射元数据，应用不需要再写 `RuntimeHints`：

| 配置项 | 取值 | 适用场景 |
| --- | --- | --- |
| `native-reflection-classes` | 全限定类名列表 | 少量特殊类、按名引用的类、单个 VO/DTO |
| `native-reflection-packages` | 包路径列表 | VO/DTO 较多，按包批量扫描 |

```yaml
# Spring Boot
spring:
  sqltoy:
    # 包下全部类递归注册（VO/DTO 多时用这个）
    native-reflection-packages:
      - com.yourcorp.project.dto
      - com.yourcorp.project.vo
    # 个别特殊类再单独补
    native-reflection-classes:
      - com.yourcorp.project.report.TreeModel
```

```yaml
# Solon
solon:
  sqltoy:
    native-reflection-packages:
      - com.yourcorp.project.dto
      - com.yourcorp.project.vo
    native-reflection-classes:
      - com.yourcorp.project.report.TreeModel
```

规则：

- `native-reflection-packages` 递归扫描包下所有 `.class`，注册 `MemberCategory.values()`；普通 DTO/VO、record、enum、实体类都会注册。
- 跳过接口、注解、匿名类、局部类、合成类、`package-info`；类加载失败只记日志跳过，不中断 AOT 构建。
- 两个配置可同时使用；包扫描和显式类重复注册无副作用。
- 包扫描会把包内所有类都打进元数据，镜像会略大；不要把包含大量无关类的包整个加进来，优先单独放 DTO/VO 的包。
- 这两个配置只在构建期生效，运行期 JVM 模式不受影响；它们不替代 `packagesToScan`，`@Entity` 仍需 `packagesToScan` / `annotatedClasses`。

> [!NOTE]
> 已在 `sqltoy-aot-verify` 的 Spring/Solon 真实 native 构建中验证：移除应用侧 DTO 反射代码、仅保留 `native-reflection-packages` 后，B1 DTO 翻译查询仍通过；该轮未配置 `native-entity-proxies`，双栈 native 冒烟为 **16 PASS + 0 FAIL + 1 KNOWN-LIMITATION**（配置代理后的结果见 3.2，为 17 PASS + 0 KNOWN）。生成的 `reachability-metadata.json`/`reflect-config.json` 中可看到 DTO 类型。

#### 3.2 updateSaveFetch 实体代理（native-entity-proxies）

`updateSaveFetch(entity, EntityUpdateCallback, ...)` 的“行已存在”分支需要一个能拦截实体 getter/setter 的代理：getter 直接读 `ResultSet` 当前行，setter 直接写当前行。JVM 下由 ByteBuddy 在运行期生成子类；native image 是 closed-world，**不能运行期定义新类**，因此该分支默认不可用。

6.0.8 起增加 `native-entity-proxies`，在 AOT 构建期只为明确列出的实体预生成代理子类（含 ByteBuddy 生成的 auxiliary 类），写入镜像并注册反射；运行期 `EntityResultSetProxy` 先按 `<实体类名>$$SqltoyEntityProxy` 加载预生成类，加载不到才回退 JVM 动态生成：

```yaml
# Spring Boot:只列出真正使用 EntityUpdateCallback 的实体
spring:
  sqltoy:
    native-entity-proxies:
      - com.yourcorp.project.entity.StockVO
      - com.yourcorp.project.entity.AccountVO
```

```yaml
# Solon
solon:
  sqltoy:
    native-entity-proxies:
      - com.yourcorp.project.entity.StockVO
      - com.yourcorp.project.entity.AccountVO
```

约束：

- 实体必须可被子类化：不能是 `final`，且要有可访问的无参构造器；不满足时 AOT 记 warn，运行期该实体仍会报“not pre-generated”。
- `byte-buddy` 在 starter/plugin 中为 optional，不会传递；使用 `native-entity-proxies` 的应用需显式引入 `net.bytebuddy:byte-buddy`。未引入时 AOT 构建会输出明确警告并跳过代理生成，运行期该实体仍不可用。
- 只对列出的实体生效；未列出的实体仍保持“native 下不可用”的限制，不会静默退回运行期生成。
- 生成的代理类和 auxiliary 类都会进入镜像，实体越多镜像略增；不要无差别把所有实体都列进来。

> [!NOTE]
> 已在 `sqltoy-aot-verify` 双栈真实 native 构建中验证：配置 `native-entity-proxies: com.sqltoy.aotverify.entity.AotUsfVO` 后，C1（`updateSaveFetch` 的 `EntityUpdateCallback`）由 KNOWN-LIMITATION 变为 **PASS**，双栈冒烟均为 **17 PASS + 0 FAIL + 0 KNOWN-LIMITATION**。

> **历史注记（6.0.7 及以下）**：starter 的 AOT 实体注册在 Spring AOT 下不生效（构建期配置 bean 未绑定、实体快照为空），且内置固定 pattern 只覆盖 `sqltoy/**`、`translates/**`、`sqltoy-translate.xml` 约定目录，应用需自行补齐五件事：① 自定义 sql 目录的资源 pattern；② 按类名配置的扩展类反射；③ 实体反射（扫描 `packagesToScan` 同款包下的 `@Entity`）；④ sqltoy XML 解析的 8 个模型类反射（缺失时 `<unpivot>`/`<tree-sort>`/环比等标签属性**静默丢失**并解析 NPE）；⑤ DAO bean 用具体返回类型覆盖声明。完整 6.0.7 时代配方可查 showcase 仓库历史。

## 四、已知限制

| 限制 | 原因 | 影响范围 |
| --- | --- | --- |
| `updateSaveFetch`（`EntityUpdateCallback`）默认不可用 | `EntityResultSetProxy` 经 byte-buddy 在运行期生成实体子类，native image 不支持运行期类生成（实测异常形态：`IllegalArgumentException: Could not create type`） | 仅该特性；**配置 `native-entity-proxies` 列出实体后可在构建期预生成，已验证 C1 PASS**；未配置的实体仍不可用；常规 CRUD/查询与 insert 分支不受影响 |
| sql 文件热更新失效 | sql 文件打进镜像，按资源列表加载，无 File 可监听 | 仅 debug 热更新；开发期用 JVM 模式即可 |
| 启动期出现 "no entity classes ... matched in the sqltoy pojo scan path" 告警属预期 | `EntityScanner` 依赖 file/jar 协议的目录枚举，镜像内不可用，`packagesToScan` 的启动期扫描在 native 下为空 | 无功能影响：实体反射元数据已在构建期注册，运行期按首次使用懒解析（native 冒烟已验证 CRUD/翻译缓存可用） |
| 第三方组件依赖各自元数据 | mongo/ES/redis/ehcache 等客户端的 native 支持由其官方 reachability metadata 提供 | 使用对应组件时按其官方文档确认。已知例子：**fastjson2** 自带的 native-image.properties 漏掉嵌套类（`JSONFactory$CacheItem` 等），GraalVM 25 的 image heap 校验会构建失败，应用需追加构建参数 `--initialize-at-build-time=com.alibaba.fastjson2`（sqltoy-aot-verify 已内置）；补参后其 `JDKUtils` 的 Unsafe 字段偏移仍在构建期重算失败，运行期探测按设计**静默跳过 fastjson2 降级到 jackson3/jackson2**（功能不受影响）——native 下 JSON 列建议使用 jackson2/jackson3（均已实测） |
| JSON 序列化的业务类型 | JsonProvider 实现类已自动注册，但被序列化业务类型是否可达取决于 JSON 库自身的 native 支持 | JSON 列/ES 场景，Spring Boot 对 Jackson 已有内建支持 |

## 五、Solon 集成

solon-plugin 内置 `SqltoyRuntimeNativeRegistrar`（实现 solon 的 `RuntimeNativeRegistrar` 接口，`SqlToyPluginImpl` 在 AOT 模式下自动挂载），注册内容与 spring 侧对称：固定资源 pattern、配置属性类与 6 个内置主键生成器反射、实体反射，6.0.8 起同样按配置动态注册资源 pattern、扩展类反射以及 `native-reflection-classes` / `native-reflection-packages` 指定的 DTO/VO 与特殊类，并支持 `native-entity-proxies` 在构建期预生成 updateSaveFetch 代理。solon 默认 `sqlResourcesDir=classpath:sqltoy` 命中内置 pattern，零配置即可。构建方式参见 solon 官方 native 文档与 [Solon 集成参考](../config/solon.md)。

> [!NOTE]
> solon 把 yml **标量**绑定到 `String[]` 时元素会带上引号（`packagesToScan: com.x.entity` 绑定为 `"com.x.entity"`），带引号包名会让实体扫描静默为空。6.0.8 起插件已自动剥离首尾成对引号，标量与 yaml 列表两种写法均可；6.0.7 及以下请使用 yaml 列表写法。

## 六、演示与验证

**专项验证工程 [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify)**（spring + solon 双栈共用验证矩阵，PostgreSQL pgvector+postgis）：矩阵覆盖 CRUD×json/vector/geometry 三形态（String/float[]/JTS Geometry）、ehcache+caffeine 双实现缓存翻译、updateSaveFetch 代理路径、lambda 单表/join/setExpr/matchAll 守卫/删除；JVM 全矩阵双框架 17/17 PASS，配置 `native-entity-proxies` 后 native 冒烟双框架 **17 PASS + 0 KNOWN-LIMITATION**（C1 已由预生成代理解决）。

演示项目 [sqltoy-showcase](https://github.com/sagframe/sqltoy-showcase) 提供两层验证：

1. **JVM 层（随 `mvn test` 运行，无需 GraalVM）**：[`NativeAotTest`](https://github.com/sagframe/sqltoy-showcase/blob/master/src/test/java/com/sqltoy/showcase/NativeAotTest.java) 运行与 `native:compile` 完全相同的 Spring Boot AOT 处理（`SpringApplicationAotProcessor`），解析生成的 `reachability-metadata.json`，断言实体反射、sql/mock 资源 pattern、扩展类反射全部就位；
2. **真实编译（CI）**：[native-build workflow](https://github.com/sagframe/sqltoy-showcase/actions/workflows/native-build.yml) 在 ubuntu + GraalVM 上执行 `mvn -Pnative native:compile`，并以 `--smoke` 参数运行二进制做启动 + 查询路径冒烟（`NativeSmokeRunner`：实体加载、SQL 计数、缓存翻译；手动/每周触发，不占用常规 PR CI）。

> 🎬 完整示例源码：演示项目 sqltoy-showcase 的 `NativeAotTest.java`、`ShowcaseRuntimeHints.java`

## 相关文档

- [其他特性](other_features.md)
- [Solon 集成参考](../config/solon.md)
- [sqltoy 配置参数](../config/sqltoy_config.md)
