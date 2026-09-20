# Program grammar (this slice)

Syntactic grammar recognized by [`Lovelace.Compiler.Parser`](parser.md) for one compilation unit (one `.love` file). Not a full Lovelace language grammar. Productions are **non-left-recursive** (LL(k) / recursive descent).

Lexical tokens come from [token-grammar.md](token-grammar.md). Whitespace between tokens is ignored by the tokenizer and does not appear in the token stream.

```ebnf
compilation_unit = program_header , block , "." ;
program_header   = "program" , identifier , ";" ;
block            = "begin" , "end" ;
```

| Terminal | Token |
| --- | --- |
| `"program"` | keyword `program` |
| `"begin"` | keyword `begin` |
| `"end"` | keyword `end` |
| `identifier` | identifier (including `@foo`, Unicode names) |
| `";"` | punctuation semicolon |
| `"."` | punctuation full stop |

Examples (all valid when tokenized then parsed):

| Source | Notes |
| --- | --- |
| `program Hello; begin end.` | Canonical |
| `program IDENTIFIER;begin end.` | No space after `;` |
| `    program   X ; begin end .  ` | Arbitrary spaces |

Not accepted in this slice: `end;`, wrong keyword order, missing `.`, trailing tokens after `.`, `Program` as the first keyword (identifier, not keyword).
