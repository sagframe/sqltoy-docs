# Data Permission & Overreach Check

1. It makes it easy to uniformly pass the current user's data-permission information, such as authorized organizations, authorized account sets, authorized tenants and authorized business lines. For example, in a springsecurity+springsession+redis setup, the current user information can be obtained through ThreadLocal, sparing developers from manually passing these routine parameters on every call.
2. Privilege-escalation check: suppose the user Zhang San is authorized to access data of departments S001 and S002, but the front-end page passes S004 through some means. The framework then compares the passed value against the authorized values to determine whether it is a privilege escalation, and throws an exception if it is.
3. For the multi-tenancy scenario it provides a method for passing the current user's authorized tenants:
```java
// -- Reference: org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor --
// If SqlInterceptors is enabled: xxxx.TenantInterceptor
// For sql query tenant isolation it is recommended to implement this method, because the pagination cached-count step needs this value as part of the key
/**
 * @TODO Return the authorized tenant information; passing the table name and operation type lets the program control what to return: the tenant it belongs to and the authorized tenants, providing part of the decision basis
 * Normally you can simply return the current user's authorized tenant id array, mainly used by SqlInterceptors, such as a custom TenantInterceptor
 * @param entityClass
 * @param operType
 * @return
 */
public default String[] authTenants(Class entityClass, OperateType operType) {
    // You can ignore the entityClass and operType parameters and directly return the tenant ids the current user is authorized for
    // How to get them? Put the user information into ThreadLocal in a filter, then you can fetch it freely here; improvise according to your situation
    // return getCurrentUserAuthedTenants();
    return null;
}
```
