# GraalVM Native Image Guide

Both the sqltoy spring-starter and solon-plugin ship with built-in AOT/native support: ORM reflection and resource metadata are registered automatically at build time, and resource loading switches to in-image resources at runtime. This page covers the full picture — what is supported, how to build, what the application must contribute, and the known limitations.

> **Version note**: AOT support was introduced in 5.6; **since 6.0.8** it is substantially enhanced (resources and extension classes are registered dynamically from the actual configuration, and entity scanning no longer depends on a build-time bean snapshot). This page describes 6.0.8; differences for 6.0.7 and earlier are called out per section.

## 1. What Is Built In

| Module | AOT component | Registration | Purpose |
| --- | --- | --- | --- |
| `sagacity-sqltoy-spring-starter` | `SqltoyRuntimeHintsRegistrar` | auto-registered via `META-INF/spring/aot.factories` | fixed resource patterns (`sqltoy-translate.xml`, `translates/**`, `sqltoy/**`) + reflection for the config-property classes and the 6 built-in id generators (Default/UUID/ULID/NanoTime/Redis/Snowflake) |
| `sagacity-sqltoy-spring-starter` | `SqltoyBeanFactoryInitializationAotProcessor` | same | entity reflection plus configuration-driven resource patterns and extension-class reflection (since 6.0.8, see section 3) |
| `sagacity-sqltoy-solon-plugin` | `SqltoyRuntimeNativeRegistrar` | mounted automatically by `SqlToyPluginImpl` in AOT mode | symmetric with the Spring side (solon's AOT build runs the real startup flow, so configuration beans are genuinely available) |

**Native runtime adaptation** (all versions): when sqltoy detects the `org.graalvm.nativeimage.imagecode` system property, it converts the `sqlResourcesDir` directory configuration into an explicit list of in-image `.sql.xml` resources (`SqlScriptLoader` works in resource-list mode); the solon side does the same for `translateConfig`.

> [!NOTE]
> One behavioral difference follows from this: sql files are baked into the image, so **debug-mode sql hot reload is automatically disabled under native** (file-change detection only works for File resources on a filesystem).

## 2. Build Steps (Spring Boot)

Prerequisites (identical to the official Spring Boot requirements — see the [Spring Boot Native Image documentation](https://docs.spring.io/spring-boot/reference/packaging/native-image/index.html)):

- **GraalVM JDK 25+**: older versions are incompatible with the current GraalVM reachability metadata repository (verified matrix: **17 and 23** do not understand the new metadata schema — native-maven-plugin rejects them outright; **21** does not support `typeReached` conditional metadata — conditions count as always-true, spring-aop's AspectJ serialization entries get registered by mistake, and the build fails without aspectjweaver); 25.0.4 is verified with the full matrix on both stacks; on GitHub Actions `actions/setup-java` requires `distribution: graalvm` (`graalvm-community` was removed from setup-java v4's distribution list — using it fails the step outright), which still serves the official GraalVM Community builds;
- Visual Studio Build Tools (MSVC) on Windows, a gcc toolchain on Linux, Xcode Command Line Tools on macOS.

> [!NOTE]
> If the project uses lombok: JDK 23+ javac no longer runs classpath annotation processors implicitly — declare lombok explicitly in the maven-compiler-plugin's `annotationProcessorPaths`, otherwise entity getters/setters are not generated when compiling with GraalVM 25.

With `spring-boot-starter-parent` as the project parent, the `native` profile is built in:

```bash
# Build the native image (sqltoy's AOT metadata takes effect automatically)
mvn -Pnative native:compile -DskipTests

# Run it
./target/your-app
```

## 3. What the Application Must Contribute

### 1. packagesToScan is required (all versions)

sqltoy entities are **parsed lazily on first use**, while a native build can only register reflection metadata at build time. For native scenarios you must therefore configure `packagesToScan` (or `annotatedClasses`) so entities are registered at startup:

```yaml
spring:
    sqltoy:
        # required for native: the build-time scan registers @Entity reflection metadata from this package
        packagesToScan: com.yourcorp.project.entity
        sqlResourcesDir: classpath:sqltoy
```

> On a regular JVM this property is optional (entities are parsed on demand); setting it only means eager parsing at startup, with no behavioral difference.

> `packagesToScan` only covers `@Entity`; plain DTO/VOs returned by queries are registered with `native-reflection-packages` / `native-reflection-classes` in section 3.1.

### 2. Resource and extension-class registration (automatic since 6.0.8)

**Since 6.0.8**, `SqltoyBeanFactoryInitializationAotProcessor` binds the `spring.sqltoy` configuration straight from the Environment (during AOT build processing the container does not instantiate/bind beans, so the old bean-snapshot implementation saw an empty configuration) and registers automatically:

| Registered | Configuration source |
| --- | --- |
| Entity reflection | `packagesToScan` / `annotatedClasses` scan |
| Id-generator reflection | the 6 built-in generators are always registered (Default/UUID/ULID/NanoTime/Redis/Snowflake); custom generator classes referenced by `@Id(generator/strategy)` or `@BusinessId(generator)` on scanned entities are registered automatically |
| Nested config-property classes | `Elastic`, `ElasticConfig` (needed by solon's runtime `cfg().toBean(...)` binding for nested endpoints) |
| Sql file resource patterns | `sqlResourcesDir` (multi-directory splitting), `sqlResources` |
| Translate config resources | `translateConfig` (`.xml` as files, directories as `/**`) |
| Key resources | `securePublicKey` / `securePrivateKey` |
| Extension-class reflection | `unifyFieldsHandler`, `typeHandler`, `sqlInterceptors`, `sqlFormater` (including `default` alias expansion), `translateCacheManager`, `dataSourceSelector`, `connectionFactory`, `fieldsSecureProvider`, `desensitizeProvider`, `customFilterHandler`, `overTimeSqlHandler`, `dialectDDLGenerator`, `firstBizCodeTrace`, `dynamicCacheFetch`, `dynamicFecthCacheManager` (same convention as runtime: a value containing `.` is a class name, otherwise it is a bean name covered by Spring AOT itself), and `functionConverts` (including the `default`-expanded built-in function set, resolved via `FunctionUtils.resolveFunctionClassNames` with exactly the runtime semantics) |
| Integration-class reflection (conditional) | registration follows the classpath, not the build-time configuration: caffeine library present → the translate cache manager (the ehcache manager is instantiated directly at runtime and needs no registration); mongo driver present → `SpringMongoQuery`; spring-data-redis present → `SpringRedisIdGenerator` |
| Extension-type driver classes (conditional) | registered when the corresponding driver is on the classpath: the 5 isomorphic `PGobject` classes of the PG family (postgresql plus the stardb-style fallback, opengauss/mogdb, vastbase, gaussdb, and kingbase's `KBobject` — json/jsonb/vector/geometry are constructed and read reflectively), mssql-jdbc's `Geometry`/`Vector`, and oracle's `OracleTypes` |
| JsonProvider reflection | **all** built-in implementations whose JSON library is on the classpath (fastjson2/jackson3/jackson2, by their markers) plus an explicitly configured custom implementation class name |
| Lambda serialization base | java-serialization registration for `SerializedLambda` and sqltoy's mirror class (fixed; the app side must additionally register lambda defining classes, see next section) |

In other words: **with entities, resources and extensions configured by convention, a native build needs no extra AOT code since 6.0.8**; non-entity DTO/VOs are registered with `native-reflection-classes` / `native-reflection-packages` in the next section.

> [!WARNING]
> The built-in implementation behind `sqlFormater` (`DefaultSqlFormater`) hard-depends on druid (optional in core): applications configuring `sqlFormater` must add druid themselves, otherwise the debug-statistics path (`SqlExecuteStat`) throws `NoClassDefFoundError` when it formats SQL (not triggered while debug is off).

> [!NOTE]
> **Runtime switching**: a native image is frozen at build time, so integration classes and JsonProviders are registered by **classpath** (not by the build-time values of `cacheType`/`jsonProvider`) — as long as the corresponding library is on the classpath, switching `cacheType` (ehcache↔caffeine) or `jsonProvider` (fastjson2/jackson3/jackson2/custom) via startup arguments works at runtime; sqltoy-aot-verify runs dedicated switch rounds on both stacks.

### 3. What remains application-side (any version)

Five categories the framework cannot infer — complete runnable examples: [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify) (`AotVerifyRuntimeHints` / solon `Config#aotVerifyNativeRegistrar`) and the showcase's [`ShowcaseRuntimeHints`](https://github.com/sagframe/sqltoy-showcase/blob/master/src/main/java/com/sqltoy/showcase/config/ShowcaseRuntimeHints.java):

1. **classpath resources loaded by application code itself**: e.g. startup schema scripts (the showcase's `mock/schema-*.sql`, read by `DataSourceConfig`);
2. **classes referenced BY NAME from SQL/third-party mechanisms**: e.g. H2's `CREATE ALIAS ... FOR 'com.x.Procedures.listStaff'` (loaded via `Class.forName` by H2 at runtime);
3. **`@Bean` methods declared with an interface return type that carry `initMethod`/transactional proxies**: Spring AOT pre-determines bean types from the declaration, and an interface declaration hides the concrete class (the native runtime then fails with a missing init method or "CGLIB runtime enhancement not supported") — **declare the `@Bean` with the concrete return type** and no hints are needed (the showcase's sharding-strategy beans and the 6.0.8 starter's DAO beans are declared this way);
4. **DTO/VO classes used as query resultType**: not `@Entity` (so `packagesToScan` does not see them) yet instantiated reflectively by sqltoy at runtime — since 6.0.8 use `native-reflection-classes` / `native-reflection-packages` (see 3.1) instead of writing `RuntimeHints` by hand;
5. **classes that use lambda conditions (lambdaQuery/lambdaUpdate/lambdaDelete)**: property extraction goes through writeReplace/serialization mirroring, which in a native image requires registration by "lambda defining class" — on spring declare `lambdaCapturingTypes` in `META-INF/native-image/**/serialization-config.json` (or `hints.reflection().registerLambda(definingClass, b -> b.withInterfaces(LambdaFn.class))`), on solon `metadata.registerLambdaSerialization(definingClass)`; without it the whole lambda system is unavailable under native (JVM mode is unaffected).

```java
public class ShowcaseRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        // startup schema scripts loaded by app code (the RSA keys are registered
        // by the starter from the secure* properties)
        hints.resources().registerPattern("mock/**");
        // referenced by name from H2's CREATE ALIAS, loaded via Class.forName at runtime
        hints.reflection().registerType(Procedures.class, MemberCategory.values());
    }
}

// mounted on the application class
@SpringBootApplication
@ImportRuntimeHints(ShowcaseRuntimeHints.class)
public class ShowcaseApplication { ... }
```

> [!TIP]
> Keeping sql files under `classpath:sqltoy/` (the solon default convention) hits the built-in fixed patterns — no resource registration code needed on any version.

#### 3.1 Registering DTO/VO reflection (since 6.0.8)

`packagesToScan` only recognizes `@Entity`; plain resultType DTO/VOs are not covered. Since 6.0.8 both starters expose two build-time properties, and the AOT processor registers the reflection metadata automatically — no hand-written `RuntimeHints` needed:

| Property | Value | Use case |
| --- | --- | --- |
| `native-reflection-classes` | list of fully-qualified class names | a few special classes, classes referenced by name, individual DTO/VOs |
| `native-reflection-packages` | list of package paths | many DTO/VOs, register them by package |

```yaml
# Spring Boot
spring:
  sqltoy:
    # recursively register every class under the package(s)
    native-reflection-packages:
      - com.yourcorp.project.dto
      - com.yourcorp.project.vo
    # add special classes individually
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

Rules:

- `native-reflection-packages` recursively scans all `.class` files under each package and registers `MemberCategory.values()`; plain DTO/VOs, records, enums and entity classes are all registered.
- Interfaces, annotations, anonymous/local/synthetic classes and `package-info` are skipped; a class that fails to load is logged and skipped without failing the AOT build.
- Both properties may be used together; duplicate registrations are harmless.
- Package scanning registers every class under the package, which slightly increases image size — keep DTO/VO packages free of unrelated classes rather than adding broad application packages.
- These properties are build-time only and do not affect JVM mode; they do not replace `packagesToScan` — `@Entity` classes still need `packagesToScan` / `annotatedClasses`.

> [!NOTE]
> Verified in real native builds of `sqltoy-aot-verify` on both Spring and Solon: with the application-side DTO reflection code removed and only `native-reflection-packages` configured, the B1 DTO translate query still passes; that round did not configure `native-entity-proxies`, so both native smoke runs report **16 PASS + 0 FAIL + 1 KNOWN-LIMITATION** (with proxies configured, see 3.2: 17 PASS + 0 KNOWN). The generated `reachability-metadata.json`/`reflect-config.json` contains the DTO types.

#### 3.2 updateSaveFetch entity proxies (`native-entity-proxies`)

The "row exists" branch of `updateSaveFetch(entity, EntityUpdateCallback, ...)` needs a proxy that intercepts entity getters/setters: getters read the current `ResultSet` row and setters write to it. On the JVM this subclass is generated at runtime by ByteBuddy; a native image is closed-world and **cannot define new classes at runtime**, so that branch is unavailable by default.

Since 6.0.8, `native-entity-proxies` makes the AOT build pre-generate proxy subclasses (including ByteBuddy auxiliary classes) only for the listed entities, writes them into the image and registers their reflection metadata. At runtime `EntityResultSetProxy` first loads `<entity class name>$$SqltoyEntityProxy`; only if it is missing does it fall back to JVM dynamic generation:

```yaml
# Spring Boot: list only entities that actually use EntityUpdateCallback
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

Constraints:

- The entity must be subclassable: not `final` and with an accessible no-arg constructor; otherwise AOT logs a warning and the entity still fails at runtime with "not pre-generated".
- `byte-buddy` is optional in the starter/plugin and is not transitive; applications using `native-entity-proxies` must add `net.bytebuddy:byte-buddy` explicitly. Without it, the AOT build logs a clear warning and skips proxy generation; the entity remains unavailable at runtime.
- Only the listed entities are covered; unlisted entities keep the "unavailable under native" limitation and never silently fall back to runtime generation.
- Both the proxy and its auxiliary classes are added to the image; more entities slightly increase image size, so do not list every entity indiscriminately.

> [!NOTE]
> Verified in real native builds of `sqltoy-aot-verify` on both stacks: with `native-entity-proxies: com.sqltoy.aotverify.entity.AotUsfVO`, C1 (`updateSaveFetch` with `EntityUpdateCallback`) changes from KNOWN-LIMITATION to **PASS**, and both smoke runs report **17 PASS + 0 FAIL + 0 KNOWN-LIMITATION**.

> **Historical note (6.0.7 and earlier)**: the starter's AOT entity registration did not work under Spring AOT processing (configuration beans are not bound at build time, so the entity snapshot came out empty), and the built-in fixed patterns only span the `sqltoy/**`, `translates/**`, `sqltoy-translate.xml` conventions. Applications had to cover five things themselves: ① resource patterns for custom sql directories; ② reflection for class-name configured extensions; ③ entity reflection (scanning the same package as `packagesToScan` for `@Entity`); ④ reflection for sqltoy's 8 XML parsing model classes (without them the attributes of `<unpivot>`/`<tree-sort>`/chain-relative tags are **silently dropped** and parsing dies with an NPE); ⑤ re-declaring the DAO beans with concrete return types. The full 6.0.7-era recipe is in the showcase repository history.

## 4. Known Limitations

| Limitation | Cause | Scope |
| --- | --- | --- |
| `updateSaveFetch` (`EntityUpdateCallback`) is unavailable by default | `EntityResultSetProxy` generates entity subclasses at runtime via byte-buddy; native image does not support runtime class generation (observed failure: `IllegalArgumentException: Could not create type`) | that feature only; **configuring `native-entity-proxies` for the entity pre-generates the proxy at build time and makes C1 PASS (verified)**; unlisted entities remain unavailable; regular CRUD/queries and the insert branch are unaffected |
| Sql hot reload is disabled | sql files are baked into the image and loaded as a resource list — there is no File to watch | debug hot reload only; use JVM mode during development |
| The startup warning "no entity classes ... matched in the sqltoy pojo scan path" is expected | `EntityScanner` enumerates directories via the file/jar protocol, which is unavailable inside the image, so the `packagesToScan` startup scan comes out empty under native | no functional impact: entity reflection metadata is registered at build time and entities are parsed lazily on first use at runtime (CRUD + translate cache verified by the native smoke run) |
| Third-party components rely on their own metadata | native support for mongo/ES/redis/ehcache clients comes from their official reachability metadata | check the respective library's documentation when using them. Known example: **fastjson2**'s bundled native-image.properties misses nested classes (`JSONFactory$CacheItem` etc.), which fails GraalVM 25's image-heap validation — add the build argument `--initialize-at-build-time=com.alibaba.fastjson2` (already wired in sqltoy-aot-verify); even then its `JDKUtils` Unsafe field-offset recomputation fails at build time, so runtime detection **silently skips fastjson2 and degrades to jackson3/jackson2** by design (functionality unaffected) — prefer jackson2/jackson3 for JSON columns under native (both verified) |
| Business types serialized to JSON | the JsonProvider implementation is registered automatically, but reachability of serialized business types depends on the JSON library's own native support | JSON columns / ES scenarios; Spring Boot has built-in Jackson support |

## 5. Solon Integration

The solon-plugin ships `SqltoyRuntimeNativeRegistrar` (implementing solon's `RuntimeNativeRegistrar` interface, mounted automatically by `SqlToyPluginImpl` in AOT mode). Its registrations are symmetric with the Spring side: fixed resource patterns, reflection for config-property classes and the 6 built-in id generators, entity reflection — and since 6.0.8, configuration-driven resource patterns, extension-class reflection, and the DTO/VO and special classes listed by `native-reflection-classes` / `native-reflection-packages`, plus `native-entity-proxies` for pre-generated updateSaveFetch proxies. Solon's default `sqlResourcesDir=classpath:sqltoy` hits the built-in patterns, so it works with zero configuration. For the build flow see the official solon native documentation and the [Solon Integration Reference](en/config/solon.md).

> [!NOTE]
> When solon binds a yml **scalar** to a `String[]`, the elements come out quoted (`packagesToScan: com.x.entity` binds as `"com.x.entity"`), and a quoted package name makes the entity scan come out silently empty. Since 6.0.8 the plugin strips surrounding quotes, so both the scalar and the yaml-list forms work; on 6.0.7 and earlier use the yaml-list form.

## 6. Demo & Verification

**Dedicated verification project [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify)** (spring + solon stacks sharing one verification matrix, PostgreSQL pgvector+postgis): the matrix covers CRUD × json/vector/geometry in three shapes (String / float[] / JTS Geometry), cache translate on both ehcache and caffeine, the updateSaveFetch proxy path, and lambda single-table/join/setExpr/matchAll-guard/delete. JVM full matrix: 17/17 PASS on both stacks; with `native-entity-proxies` configured, native smoke: **17 PASS + 0 KNOWN-LIMITATION** on both stacks (C1 resolved by the pre-generated proxy).

The demo project [sqltoy-showcase](https://github.com/sagframe/sqltoy-showcase) provides two verification layers:

1. **JVM level (runs as part of `mvn test`, no GraalVM needed)**: [`NativeAotTest`](https://github.com/sagframe/sqltoy-showcase/blob/master/src/test/java/com/sqltoy/showcase/NativeAotTest.java) runs the exact same Spring Boot AOT processing that `native:compile` consumes (`SpringApplicationAotProcessor`), parses the generated `reachability-metadata.json`, and asserts that entity reflection, the sql/mock resource patterns and the extension-class reflection are all in place;
2. **Real compilation (CI)**: the [native-build workflow](https://github.com/sagframe/sqltoy-showcase/actions/workflows/native-build.yml) runs `mvn -Pnative native:compile` on ubuntu + GraalVM and smoke-runs the binary with `--smoke` (NativeSmokeRunner: entity load, SQL count, translate cache; manual dispatch + weekly, kept out of the regular PR CI).

> 🎬 Full example source: `NativeAotTest.java` and `ShowcaseRuntimeHints.java` in the sqltoy-showcase demo project

## Related

- [Other Features](en/tools/other_features.md)
- [Solon Integration Reference](en/config/solon.md)
- [Configuration Reference](en/config/sqltoy_config.md)
