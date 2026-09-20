# Compiler parser

`Lovelace.Compiler.Parser` turns a successful tokenizer `Token_Sequence` into a frontend AST module. It lives in crate `lovelace_compiler`. The parser is **recursive descent** (LL(k)): it consumes **one token at a time** and mirrors a non-left-recursive grammar. See also [program-grammar.md](program-grammar.md) and the Cursor rule `parser-recursive-descent`.

This slice accepts only:

```text
program IDENTIFIER; begin end.
```

There is no CLI wiring in this slice. Lowering AST to LIR is documented in [ir-generator.md](ir-generator.md). Frontend AST and types remain distinct from LIR packages.

Public Ada APIs stay on the package specs (GNATdoc); see [gnatdoc.md](gnatdoc.md). Lexical tokens come from [tokenizer.md](tokenizer.md). Source spans and filenames: [source-locations.md](source-locations.md).

## Pipeline

```text
UTF-8 .love  →  Tokenize  →  Token_Sequence  →  Parse  →  Ast.Module  →  Generate  →  LIR
```

Callers tokenize first. `Parse` does not call `Tokenize`. Callers that need LIR call `Ir_Generator.Generate` after a successful parse.

## API

| Package | Role |
| --- | --- |
| `Lovelace.Compiler.Types` | Frontend `Type_Expression` (Unit only in this slice) |
| `Lovelace.Compiler.Ast` | Module, subroutine, `Subroutine_Flags`, empty body |
| `Lovelace.Compiler.Parser` | `Parse`, `Parse_Result`, `Parser_Error` |
| `Lovelace.Compiler.Ir_Generator` | AST → LIR (see [ir-generator.md](ir-generator.md)) |

```ada
function Parse
  (Source_Text : String;
   Token_List  : Tokens.Token_Sequence) return Parse_Result;
```

`Parse_Result` is a module **or** errors, not both:

| `Ok` | Payload |
| --- | --- |
| `True` | `The_Module` — one compilation-unit AST |
| `False` | `Errors` — typically one located error (stop at first) |

Handle both discriminants. Do not read `The_Module` when `Ok` is `False`.

## Grammar (this slice)

```ebnf
compilation_unit = program_header , block , "." ;
program_header   = "program" , identifier , ";" ;
block            = "begin" , "end" ;
```

Keywords are case-sensitive (`program`, not `Program`). The unit terminator after `end` is only `.` (`Full_Stop`). `end;` is a parse error. Extra tokens after a complete unit are `Unexpected_Trailing`.

## AST shape

On success the parser builds:

- A **module** named `IDENTIFIER`
- One **subroutine** with the same name
- Empty body
- Return type **unit** (`Lovelace.Compiler.Types.Unit`)
- Flags: both `Export_Flag` and `Entrypoint_Flag` (frontend bitset, not LIR’s type)

Spans cover the name and the whole unit (first token through the final `.`). Optional filenames come from tokenization ([source-locations.md](source-locations.md)).

## Errors

| Code | Meaning |
| --- | --- |
| `Internal_Error` | Compiler bug (listed first) |
| `Unexpected_End_Of_Input` | A token was required but the cursor was at end |
| `Unexpected_Token` | Wrong kind/subtype at the cursor |
| `Unexpected_Trailing` | Tokens remain after a complete unit |

Empty input / empty token list reports `Unexpected_End_Of_Input` at a synthetic span `(1,1,1)` when nothing was consumed.
