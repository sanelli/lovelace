# Directives (flavor `#if`)

Lovelace **directives** are part of the language grammar (not a separate preprocessor). They do not expand into statements. In this slice, the only directive form is **flavor selection** for Augusta / host flavors.

Related: [compilation-unit-grammar.md](compilation-unit-grammar.md), [tokenizer.md](tokenizer.md), [parser.md](parser.md), [cli.md](cli.md), roadmap [001](roadmap/001-roadmap-print-integer-wasi.md).

## Flavors

| Name | Role |
| --- | --- |
| `wasi` | WASI guest path (CLI default) |
| `native` | Host native / `love:` path (bodies later) |
| `web` | Browser / web path (bodies later) |

Select the active flavor with `lovelace build --flavor <name>` (default `wasi`). See [cli.md](cli.md).

## Syntax

Allowed only in a **module** unit’s declaration list (alongside `procedure` declarations). Not in `program` units and not inside procedure bodies.

```ebnf
flavor_conditional = "#if" , flavor_condition , { module_declaration } ,
                     { "#elsif" , flavor_condition , { module_declaration } } ,
                     [ "#else" , { module_declaration } ] ,
                     "#end" ;
flavor_condition   = "flavor" , "=" , string_literal ;
```

- End token is `#end` (not `#endif`).
- `flavor` is an ordinary identifier (not a keyword).
- The string must be exactly `"wasi"`, `"native"`, or `"web"` (case-sensitive). Other values → [`LV00012`](diagnostics.md).
- Nesting is allowed.
- General `#if` expressions, `#pragma`, and OS splits are **not** in this slice.

Example: [`samples/directives/FlavorSelect.love`](../samples/directives/FlavorSelect.love).

## Selection rules

1. The whole file is tokenized, including inactive arms.
2. The parser parses **every** arm for syntax validity.
3. Only declarations from the **active** arm are kept in the AST used for lowering:
   - first matching `#if` / `#elsif` whose string equals the active flavor, else `#else` if present
4. The same procedure name may appear in mutually exclusive arms. Name clashes ([`LV00011`](diagnostics.md)) apply only among surviving declarations.

## Reserved for later

- `import … as …` and other directives
- `#pragma` warning control
- General conditions beyond `flavor = "…"`
- Per-flavor output folders (`bin/wasi/`, …) — roadmap macro step 11
