# 数据脱敏和加解密


## 数据脱敏

* sqltoy脱敏包含tel\name\id-card\bank-card\address\email\public-account 几种固定类型
* 针对相对固定长度的字符脱敏可通过head-size、tail-size、mask-code自行定义脱敏规则
* 针对不固定长度可通过脱敏比例mask-rate设置比例，如：mask-rate="50"
* 也可以自行定义脱敏处理函数

```java
# 实现org.sagacity.sqltoy.plugins.secure.DesensitizeProvider
# 默认实现类:org.sagacity.sqltoy.plugins.secure.impl.DesensitizeDefaultProvider
spring.sqltoy.desensitizeProvider=your.DesensitizeProvider
```

* xml 用法

```xml
<sql id="sys_findStaff_info">
	<!-- 安全掩码:tel\name\id-card\bank-card\address\email\public-account\other -->
	<!--最简单用法: <secure-mask columns="mobile_tel" type="tel"/> -->
	<secure-mask type="tel" columns="mobile_tel" head-size="3"
		tail-size="4" mask-code="*****" />
    <value>
        <![CDATA[
        select staff_code,staff_name,address,mobile_tel,id_card,blank_type,blank_code
        from sys_staff_info
        where staff_code=:staffCode
        ]]>
    </value>
</sql>
```

* java代码中用法

```java
String sql = """
		  select staff_code,staff_name,address,mobile_tel,id_card,blank_type,blank_code
		  from sys_staff_info
		  where staff_code=:staffCode
				""";
List result = lightDao
		.findByQuery(
				new QueryExecutor(sql).secureMask(MaskType.TEL, "mobile_tel").secureMask(MaskType.ID, "id_card")
						.values(MapKit.keys("staffCode").values("S0001")).resultType(StaffInfoVO.class))
		.getRows();
```

## 字段加密解密

* sqltoy支持对字段进行加密存储，查询时可动态解密
* sqltoy 通过一对 RSA 公私钥实现字段加解密（公钥加密、私钥解密）。密钥格式为**去掉 PEM 头尾和换行的单行 Base64**（私钥 PKCS#8、公钥 X.509），用 openssl 一条命令即可生成（Git Bash / Linux / macOS 自带 openssl，Windows 装了 Git 即有）：

```bash
# 生成 1024 位私钥(PKCS#8)并导出配对公钥(X.509)，去头尾压成单行 Base64
openssl genrsa 1024 2>/dev/null | openssl pkcs8 -topk8 -nocrypt > private.pem
openssl rsa -in private.pem -pubout > public.pem
grep -v '^-' private.pem | tr -d '
' > rsa_private.key && echo >> rsa_private.key
grep -v '^-' public.pem  | tr -d '
' > rsa_public.key  && echo >> rsa_public.key
```

> 也可以用纯 Java 生成（JDK 自带 JCE，无需任何依赖）——sqltoy 源码 `src/test` 路径下的 `org.sagacity.sqltoy.utils.SecureUtils` 就是这段逻辑的封装：

```java
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;

public class GenerateRsaKeys {
    public static void main(String[] args) throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(1024); // 2048 for production; widen the encrypted column accordingly
        KeyPair keyPair = generator.generateKeyPair();
        // single-line Base64 without PEM headers — the format sqltoy expects
        // (private key PKCS#8, public key X.509); print two lines and save each to its own file
        System.out.println(Base64.getEncoder().encodeToString(keyPair.getPrivate().getEncoded()));
        System.out.println(Base64.getEncoder().encodeToString(keyPair.getPublic().getEncoded()));
    }
}
```1024 位密文的单字段密文约 172 字符，加密列建议 `varchar(500)`；生产环境可按安全要求改用更长位数（列宽同步加大）。

```properties
# 可以自定义加解密算法实现，框架提供了默认实现
# spring.sqltoy.fieldsSecureProvider=org.sagacity.sqltoy.plugins.secure.impl.FieldsRSASecureProvider
spring.sqltoy.securePrivateKey=classpath:mock/rsa_private.key
spring.sqltoy.securePublicKey=classpath:mock/rsa_public.key
```

传统 Spring XML 模式在 `SqlToyContext` bean 上配置同名属性（演示项目 `sqltoy-showcase` 的 `spring-sqltoy.xml` 即此写法）：

```xml
<property name="securePrivateKey" value="classpath:mock/rsa_private.key" />
<property name="securePublicKey" value="classpath:mock/rsa_public.key" />
```

> 🎬 完整可运行示例：演示项目 `sqltoy-showcase` 的 `SecureEncryptTest.java`（加密存储/自动解密/检索码）与 `SecureMaskTest.java`（先解密再脱敏）；测试资源已内置 `mock/rsa_private.key`、`rsa_public.key` 演示密钥。

* 在pojo对象类上增加注解@SecureConfig,为了便于检索，可以额外增加一个脱敏值，注意sourceField的指向作用

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_secure_case",comment="安全加解密演示",pk_constraint="PRIMARY")
@SecureConfig(secures = { @Secure(field = "telNoMask", secureType = SecureType.TEL),
		@Secure(field = "telNo", secureType = SecureType.ENCRYPT),
		@Secure(field = "telNoMask", secureType = SecureType.TEL,sourceField="telNo"),
		@Secure(field = "homeAddressMask", secureType = SecureType.DISCRETE_RATE, maskRate = 50, sourceField = "homeAddress"),
		@Secure(field = "homeAddress", secureType = SecureType.ENCRYPT) })
public class SecureCaseVO implements Serializable {
	@Schema(name="staffId",description="工号",nullable=false)
	@Id(strategy="generator",generator="org.sagacity.sqltoy.plugins.id.impl.DefaultIdGenerator")
	@Column(name="STAFF_ID",comment="工号",length=22L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String staffId;

	@Schema(name="staffName",description="姓名",nullable=false)
	@Column(name="STAFF_NAME",comment="姓名",length=30L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String staffName;

	@Schema(name="telNo",description="移动电话",nullable=false)
	@Column(name="TEL_NO",comment="移动电话",length=500L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String telNo;

	@Schema(name="telNoMask",description="电话检索",nullable=false)
	@Column(name="TEL_NO_MASK",comment="电话检索",length=30L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String telNoMask;

	@Schema(name="homeAddress",description="家庭地址",nullable=false)
	@Column(name="HOME_ADDRESS",comment="家庭地址",length=500L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String homeAddress;

	@Schema(name="homeAddressMask",description="家庭地址检索",nullable=false)
	@Column(name="HOME_ADDRESS_MASK",comment="家庭地址检索",length=100L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String homeAddressMask;

	......
}
```

* 调用对象save数据库字段中就会存储加密和脱敏的值
* 基于对象load则会自动将数值解密
* 基于sql语句查询解密

```java
List result = lightDao.findByQuery(new QueryExecutor(sql).secureDecrypt("address")
				.values(MapKit.keys("staffCode").values("S0001")).resultType(StaffInfoVO.class)).getRows();

```

* xml中查询解密:secure-decrypt

```xml
<sql id="qstart_secure_decrypt">
	<!-- 解密配置 -->
	<secure-decrypt columns="tel_no,home_address" />
	<value>
		<![CDATA[
			select * from sqltoy_secure_case
		]]>
	</value>
</sql>
```


