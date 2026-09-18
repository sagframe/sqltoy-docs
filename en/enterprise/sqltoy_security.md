# Data Masking & Encryption


## Data Masking

* sqltoy masking covers the fixed types tel\name\id-card\bank-card\address\email\public-account
* For characters of relatively fixed length, you can define your own masking rules via head-size, tail-size and mask-code
* For non-fixed-length characters, set the proportion via the mask-rate masking ratio, e.g.: mask-rate="50"
* You can also define your own masking handler

```java
# Implement org.sagacity.sqltoy.plugins.secure.DesensitizeProvider
# Default implementation class: org.sagacity.sqltoy.plugins.secure.impl.DesensitizeDefaultProvider
spring.sqltoy.desensitizeProvider=your.DesensitizeProvider
```

* XML usage

```xml
<sql id="sys_findStaff_info">
	<!-- Security mask types: tel\name\id-card\bank-card\address\email\public-account\other -->
	<!--Simplest usage: <secure-mask columns="mobile_tel" type="tel"/> -->
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

* Usage in Java code

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

## Field Encryption/Decryption

* sqltoy supports encrypting fields for storage and decrypting them dynamically at query time
* sqltoy defines a private key and a public key, which can be generated with org.sagacity.sqltoy.utils.SecureUtils located under the src/test path of the sqltoy framework source code; the default is based on the RSA algorithm

```properties
# You can provide a custom encryption/decryption algorithm implementation; the framework ships a default one
# spring.sqltoy.fieldsSecureProvider=org.sagacity.sqltoy.plugins.secure.impl.FieldsRSASecureProvider
spring.sqltoy.securePrivateKey=classpath:mock/rsa_private.key
spring.sqltoy.securePublicKey=classpath:mock/rsa_public.key
```

In traditional Spring XML mode, configure the properties of the same names on the `SqlToyContext` bean (the `spring-sqltoy.xml` of the demo project `sqltoy-showcase` uses exactly this style):

```xml
<property name="securePrivateKey" value="classpath:mock/rsa_private.key" />
<property name="securePublicKey" value="classpath:mock/rsa_public.key" />
```

> 🎬 Fully runnable example: `SecureTest.java` in the demo project `sqltoy-showcase` (the test resources already bundle the demo keys `mock/rsa_private.key` and `rsa_public.key`, ready for direct reuse).

* Add the @SecureConfig annotation on the POJO class; to facilitate searching, you can additionally store a masked value — pay attention to what sourceField points to

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_secure_case",comment="Security encryption/decryption demo",pk_constraint="PRIMARY")
@SecureConfig(secures = { @Secure(field = "telNoMask", secureType = SecureType.TEL),
		@Secure(field = "telNo", secureType = SecureType.ENCRYPT),
		@Secure(field = "telNoMask", secureType = SecureType.TEL,sourceField="telNo"),
		@Secure(field = "homeAddressMask", secureType = SecureType.DISCRETE_RATE, maskRate = 50, sourceField = "homeAddress"),
		@Secure(field = "homeAddress", secureType = SecureType.ENCRYPT) })
public class SecureCaseVO implements Serializable {
	@Schema(name="staffId",description="Staff ID",nullable=false)
	@Id(strategy="generator",generator="org.sagacity.sqltoy.plugins.id.impl.DefaultIdGenerator")
	@Column(name="STAFF_ID",comment="Staff ID",length=22L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String staffId;

	@Schema(name="staffName",description="Name",nullable=false)
	@Column(name="STAFF_NAME",comment="Name",length=30L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String staffName;

	@Schema(name="telNo",description="Mobile phone",nullable=false)
	@Column(name="TEL_NO",comment="Mobile phone",length=500L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String telNo;

	@Schema(name="telNoMask",description="Phone search",nullable=false)
	@Column(name="TEL_NO_MASK",comment="Phone search",length=30L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String telNoMask;

	@Schema(name="homeAddress",description="Home address",nullable=false)
	@Column(name="HOME_ADDRESS",comment="Home address",length=500L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String homeAddress;

	@Schema(name="homeAddressMask",description="Home address search",nullable=false)
	@Column(name="HOME_ADDRESS_MASK",comment="Home address search",length=100L,type=java.sql.Types.VARCHAR,nativeType="VARCHAR",nullable=false)
	private String homeAddressMask;

	......
}
```

* When the object is saved, the database columns store the encrypted and masked values
* Loading via the object automatically decrypts the values
* Decryption for SQL-based queries

```java
List result = lightDao.findByQuery(new QueryExecutor(sql).secureDecrypt("address")
				.values(MapKit.keys("staffCode").values("S0001")).resultType(StaffInfoVO.class)).getRows();

```

* Decryption in XML queries: secure-decrypt

```xml
<sql id="qstart_secure_decrypt">
	<!-- Decryption configuration -->
	<secure-decrypt columns="tel_no,home_address" />
	<value>
		<![CDATA[
			select * from sqltoy_secure_case
		]]>
	</value>
</sql>
```

