### JPA part

* JPA-like object CRUD with cascade loading, cascading insert and update
* POJO → DDL generation and direct table creation against the database
* Enhanced `update` with **elastic (null-skipping) field modification** — unlike Hibernate's load-then-update, a single database interaction completes the update, ensuring data accuracy under high concurrency
* Improved cascading updates with options such as *delete or disable first, then overwrite*
* `updateFetch` and `updateSaveFetch` for strong-transaction, high-concurrency scenarios (e.g. inventory or ledger accounts): one database interaction performs lock-query, insert-if-absent or update, and returns the modified result
* Tree-structure packaging to unify recursive queries over hierarchical data across databases
* Sharding (database & table), multiple primary-key strategies (plus Redis-based rule-driven business keys), encrypted storage, data version checking
* Common-field auto-fill (createdBy/createdTime, updatedBy/updatedTime, tenant id), extensible type handling, etc.
* Unified multi-tenant filtering and assignment, data-permission parameter injection and overreach validation

### Query part

* Highly intuitive SQL authoring that migrates easily between DB client and code, and stays easy to maintain
* Cache translate, plus reverse cache matching of keys to replace `LIKE` fuzzy queries
* Cross-database support: automatic function conversion per database, multi-dialect SQL auto-matching, synchronized multi-database testing — a big boost for productization
* Special queries such as Top-N and random sampling
* The strongest pagination mechanism: 1) automatic count-statement optimization; 2) cache-based pagination optimization avoiding repeated count queries; 3) the unique fast pagination; 4) parallel pagination
* Database/table sharding
* Algorithms of great value in management systems, naturally integrated: group summary, pivot (row-to-column) / unpivot (column-to-row), YoY & MoM comparison, tree sorting, tree rollup
* Hierarchy packaging of flat query results into parent-child objects
* Plenty of helpers: data masking, formatting, condition-parameter preprocessing, etc.
