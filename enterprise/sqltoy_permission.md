# 数据权限传参和越权校验

1. 便于统一传递当前用户信息相关的数据权限信息，如:授权机构、授权账套、授权租户、授权业务条线等，比如基于springsecurity+springsession+redis模式，可以通过ThreadLocal获取当前用户信息，避免开发者调用时手工传递这些常规信息
2. 越权校验:比如张三用户授权访问数据部门为S001、S002,前端页面通过一些手段调用传递的是S004，此时框架就会将传递值跟授权值进行比较，判断是否越权，越权就抛出异常
3. 提供了多租户场景下，传递当前用户授权租户方法:
```java
// -- 参考: org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor --
// 如果启用SqlInterceptors:xxxx.TenantInterceptor
// sql查询租户隔离，建议要实现此方法，因为在分页缓存count环节需要此值作为key的组成
/**
 * @TODO 获取授权租户信息，传递表名和操作类型目的为程序可以控制返回：所在租户和授权租户  提供部分决策依据
 * 一般你可以直接返回当前用户的授权租户id数组，主要用于SqlInterceptors，如自定义的TenantInterceptor
 * @param entityClass
 * @param operType
 * @return
 */
public default String[] authTenants(Class entityClass, OperateType operType) {
    // 你可以不用管entityClass、operType参数，直接返回当前用户授权的租户Id
    // 怎么获取？通过filter将用户信息放入ThreadLocal，这里就随意获取了，请根据情况发挥
    // return getCurrentUserAuthedTenants();
    return null;
}
```
