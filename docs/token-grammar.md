# Token grammar (this slice)

Lexical grammar recognized by [`Lovelace.Compiler.Tokenizer`](tokenizer.md). Not a full Lovelace language grammar. No parser.

```ebnf
tokens        = { whitespace | token | error } ;
token         = keyword | identifier | punctuation ;
keyword       = "program" | "begin" | "end" ;          (* case-sensitive *)
punctuation   = ";" | "." ;
identifier    = [ "@" ] identifier_first { identifier_continue } ;
(* "@" only after start, whitespace, or punctuation; not after an identifier *)

whitespace    = whitespace_scalar , { whitespace_scalar } ;
(* ignored: not emitted, not part of the adjacent tokens *)

error         = unrecognized_symbol | invalid_utf_8 ;
```

`identifier_first` / `identifier_continue` are Unicode-scalar predicates documented in [tokenizer.md](tokenizer.md). `_` is allowed; ASCII digits may continue an identifier but must not start one (except after `@`).

Examples:

| Source | Tokens (on success) |
| --- | --- |
| `program begin end.` | `program` `begin` `end` `.` |
| `end;` | `end` `;` |
| `Program` | identifier `Program` |
| `programmer` | identifier `programmer` |
| `@foo` | identifier `@foo` |
