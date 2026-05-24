# 类型扩展处理typeHandler

设置针对json等特殊类型的处理类，实现sqltoy的抽象类:
org.sagacity.sqltoy.plugins.TypeHandler

## 1、配置

```yaml
sqltoy:
  typeHandler: com.example.sqltoy_solon_demo.handler.MyTypeHandler
```

## 2、实现类

新建一个MyTypeHandler类继承org.sagacity.sqltoy.plugins.TypeHandler

```java
public class MyTypeHandler extends TypeHandler {
    @Override
    public boolean setValue(Integer integer, PreparedStatement ps, int parameterIndex, int i1, Object o) throws SQLException {
        if (parameterIndex == 1) {
            ps.setString(parameterIndex, "localhost");
            System.out.printf("setValue: %s ==> %s%n", o, "localhost");
            return true;
        }
        return false;
    }
}
```

## 3、JSONTypeHandler示例

### 3.1 quickvo 生成POJO配置类型映射关系

```xml
<type-mapping>
		<!-- 保留1个范例,一般无需配置 -->
		<!-- 增加雪花算法的演示 -->
		<sql-type native-types="BIGINT" jdbc-type="BIGINT" java-type="java.math.BigInteger" />

		<!-- 泛型注意xml转义符号，table-field指定具体表和字段; jdbc-type 可以直接填数字，这里java-type="List<StaffInfoVO>" -->
		<sql-type table-field="sqltoy_jsontype_showcae.staff_set" native-types="json" jdbc-type="1021" java-type="List&lt;StaffInfoVO&gt;" 
		import-types="com.sqltoy.quickstart.vo.StaffInfoVO" />
</type-mapping>
```

### 3.2 定义JsonTypeHandler

```java
public class JsonTypeHandler extends TypeHandler {
	// 根据情况对null进行设置,postgresql这个环节是必须要的
	@Override
	public boolean setNull(Integer dbType, PreparedStatement pst, int paramIndex, int jdbcType) throws SQLException {
		return false;
	}

	/**
	 * <li>返回true表示类型匹配上，并完成了setValue赋值</li>
	 * <li>返回false 表示常规类型,交回框架自行处理</li>
	 */
	@Override
	public boolean setValue(Integer dbType, PreparedStatement pst, int paramIndex, int jdbcType, Object value)
			throws SQLException {
		// 通过quickvo.xml 中jdbc-type 里面直接设置int数字,来区分特定的类型
		if (jdbcType == 1021) {
			pst.setString(paramIndex, JSONObject.toJSONString(value));
			return true;
		}
		return false;
	}

	/*
	 * <li>1、返回null表示属于常规类型，交回框架完成处理</li>
	 * <li>2、返回非null,表示特殊类型，完成了类型转换可直接映射到VO属性</li>
	 */
	@Override
	public Object toJavaType(String javaTypeName, Class genericType, Object jdbcValue) throws Exception {
		if (javaTypeName.equalsIgnoreCase("java.lang.string")) {
			return jdbcValue.toString();
		}
		// 是一个VO对象
		if (javaTypeName.contains("com.sqltoy")) {
			return JSON.parseObject(jdbcValue.toString(), Class.forName(javaTypeName));
		}
		if (javaTypeName.toLowerCase().contains("jsonobject")) {
			return JSON.parse(jdbcValue.toString());
		} else if (javaTypeName.toLowerCase().contains("jsonarray")) {
			return JSONArray.parseArray(jdbcValue.toString());
		}
		// List<VO>形式
		if (javaTypeName.equalsIgnoreCase("java.util.List") && genericType != null) {
			return JSONArray.parseArray(jdbcValue.toString(), genericType);
		}
		// 其他场景表示非json返回null交框架自行处理
		return null;
	}
}
```
