# What is sqltoy-orm?

* 1. sqltoy-orm is a Java ORM framework that combines JPA-style object CRUD with best-in-class native SQL querying.
* 2. It distills and shares practices from a wide range of project types: simple business systems, large multi-tenant SaaS suites (ERP, MES, CRM) and big-data platforms.

## Its history

* **2007–2008**: while building a management system for Agricultural Bank of China — full of queries and ever-changing filter conditions — an accidental insight produced a dynamic-SQL authoring style far more powerful than MyBatis. It began as a query-side complement to Hibernate/JPA and delivered a stunning development experience. See a blog post from 2009 (Chinese): <https://blog.csdn.net/iteye_2252/article/details/81683940>
* **2008–2012**: years of financial-industry projects facing tens-of-millions-row datasets focused SqlToy on enhancing SQL querying over JPA. By then Cache Translate, Fast Pagination and pivot/unpivot were already in place — features most frameworks still lack.
* **2013–2014**: to spare developers from mixing two technologies in one project, object-based CRUD was implemented inside SqlToy, completing the full sqltoy-orm framework.
* **2014–2017**: while leading the Lakala big-data platform, SqlToy went through a major refactoring that rationalized its internals, and was hardened on Lakala CRM and a big-data platform accumulating up to tens of billions of rows.
* **2018–present**: thoroughly tempered by complex multi-tenant SaaS ERP scenarios and real-time data warehouses combining Flink CDC with MPP databases, SqlToy has become mature and reliable — and is now open source, to share and build together with the community!
