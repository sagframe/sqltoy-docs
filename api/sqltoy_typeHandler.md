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
