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
* sqltoy 定义私钥和公钥，可通过sqltoy框架源码中src/test 路径下面的org.sagacity.sqltoy.utils.SecureUtils生成，默认基于RSA算法

```properties
spring.sqltoy.securePrivateKey=classpath:mock/rsa_private.key
spring.sqltoy.securePublicKey=classpath:mock/rsa_public.key
```

* 在pojo对象类上增加注解@SecureConfig,为了便于检索，可以额外增加一个脱敏值

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_secure_case",comment="安全加解密演示",pk_constraint="PRIMARY")
@SecureConfig(secures = { @Secure(field = "telNoMask", secureType = SecureType.TEL),
		@Secure(field = "telNo", secureType = SecureType.ENCRYPT),
		@Secure(field = "homeAddressMask", secureType = SecureType.ADDRESS),
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


