# Engine notes for contributors

Studio runs on BoxLang and Adobe ColdFusion 2023/2025 (the engines of ContentBox 7). CI tests all three. Pitfalls
found so far, with the way Studio handles them:

| Pitfall | Engine | Do this |
|---|---|---|
| Arrays are passed to functions **by value**: `arguments.list.append()` changes a copy | Adobe | Collect into a struct (`result.errors`) |
| `x ?: default` also replaces `false` (and maybe `0`, `""`) | Adobe | `structKeyExists` / `isBoolean` checks for flags |
| Method call on a parenthesized expression: `( a ?: [] ).map()` | Adobe | Assign to a variable first |
| `include template="...";` in script | Adobe | `include "...";` |
| `#...#` nested in an expression inside a string | Adobe | Build the part in a variable first |
| `array.insertAt( len + 1, x )` | Adobe 2023 | `append()` when inserting at the end |
| `var x` with the same name as an argument | Adobe | Use another name |
| Unscoped variables in included templates land in `variables` of the (singleton) component | Adobe | `local.` in block templates |
| `"<"` in a CFML string literal is decoded to `<` | BoxLang | `chr( 92 ) & "u003c"` |
| `deserializeJSON` / `isJSON` accept unquoted keys | BoxLang | Do not rely on them to reject bad JSON |
| After a `transaction {}` commits, ORM queries in the same request fail ("statement closed") | BoxLang + PostgreSQL | Run such queries in their own `transaction {}` |
| Struct key order in `serializeJSON` | Adobe (sorted) | Compare JSON parsed, not as text |
| `url` as a variable name is the URL scope | all | Use another name |
| ColdBox appends `@module` to module interceptor names | ColdBox | Name them without the suffix |
| `this.cfmapping` is deprecated | ColdBox 8 | `this.classMapping` |

Local test runs on a site with ContentBox's rate limiter: send a cookie (`curl -b x=1 ...`), requests without one count
as bots.
