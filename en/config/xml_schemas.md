# XML Schema Guide

All three sqltoy XML configuration files ship with official XSD schemas (hosted on GitHub: [sagframe/schema](https://github.com/sagframe/schema)). With the schema configured, IDEA gives you **tag completion, attribute hints and error highlighting** while editing.

## The three config files and their schema locations

| Config file | Purpose | xmlns (namespace — never changes) | File location in `xsi:schemaLocation` |
| --- | --- | --- | --- |
| `*.sql.xml` | sql / mql / eql query definitions | `http://www.sagframe.com/schema/sqltoy` | `https://sagframe.github.io/schema/sqltoy.xsd` |
| `sqltoy-translate.xml` | Cache-translate configuration | `https://www.sagframe.com/schema/sqltoy-translate` | `https://sagframe.github.io/schema/sqltoy-translate.xsd` |
| `quickvo.xml` | quickvo code-generation configuration | `http://www.sagframe.com/schema/quickvo` | `https://sagframe.github.io/schema/quickvo.xsd` |

> [!IMPORTANT]
> The `xmlns` is the schema identity — it does **not** need to be reachable and must **never be modified**. The second URI in `xsi:schemaLocation` is only a hint of where the file lives. The framework never downloads the XSD at runtime; it serves IDE completion and validation only.

## Legacy address (transition)

Historical versions referenced the `http://www.sagframe.com/schema/sqltoy/` addresses:

| Legacy address (still reachable) | New address (recommended) |
| --- | --- |
| `http://www.sagframe.com/schema/sqltoy/sqltoy.xsd` | `https://sagframe.github.io/schema/sqltoy.xsd` |
| `http://www.sagframe.com/schema/sqltoy/sqltoy-translate.xsd` | `https://sagframe.github.io/schema/sqltoy-translate.xsd` |
| `http://www.sagframe.com/schema/sqltoy/quickvo.xsd` | `https://sagframe.github.io/schema/quickvo.xsd` |

For existing files:

- **No runtime impact**: the framework never reads the XSD, so files carrying the legacy address keep working as-is;
- **IDE experience only**: the legacy address is plain http and returns `application/octet-stream`; some network environments or IDEA versions may fail to fetch it, leaving files without completion;
- **Migrate gradually** to the new addresses — no big-bang change needed. The new address is https with a proper XML content type; one Alt+Enter fetch activates it.

## Standard file headers (copy & paste)

**`*.sql.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<sqltoy xmlns="http://www.sagframe.com/schema/sqltoy"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy https://sagframe.github.io/schema/sqltoy.xsd">

</sqltoy>
```

**`sqltoy-translate.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity xmlns="https://www.sagframe.com/schema/sqltoy-translate"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="https://www.sagframe.com/schema/sqltoy-translate https://sagframe.github.io/schema/sqltoy-translate.xsd">

</sagacity>
```

**`quickvo.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sagframe.com/schema/quickvo https://sagframe.github.io/schema/quickvo.xsd">

</quickvo>
```

## Enabling completion & validation in IDEA

1. Open any config file, put the caret on the highlighted URI and press **Alt+Enter** → choose **Fetch external resource** (once is enough — IDEA caches it globally, no need to repeat per project);
2. From then on you get tag/attribute completion, and typos in tag or attribute names are highlighted immediately;
3. Alternatively, register a URI → XSD file mapping manually under `Settings | Languages & Frameworks | Schemas and DTDs`.

## Related pages

- [Dynamic SQL Guide](../query/dynamic_sql.md): the full `<sql>` element and child-tag specification inside `*.sql.xml`
- [Cache Translate in Action](../quickstart/translates.md): translate.xml configuration and usage
- [quickvo Code Generator](../prepare/quickvo.md): key quickvo.xml configuration
