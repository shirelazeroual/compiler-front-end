# Compiler Front-End: Scanner & Parser (Lex / Yacc)

Front-end of a compiler for a small C-like language, written in **C with Lex and Yacc**.
It reads a source program, checks that it is valid, and builds an **Abstract Syntax Tree (AST)**.
If the code has an error, it stops and prints a clear message with the **line number and the reason**.

This is the first stage of a compiler pipeline, built as part of the *Compilation Principles* course at SCE (Sami Shamoon College of Engineering).

## Features

- **Lexical analysis (`scanner.l`)**: keywords, types (`int`, `real`, `char`, `bool`, `string`, pointers), literals (decimal, hex, real with exponent, chars, strings), operators and multi-line comments `#-> ... <-#`
- **Syntax analysis (`parser.y`)**: full grammar of the language with operator precedence: functions, parameters, variable declarations, `if / elif / else`, `while`, `for`, `do-while`, nested blocks, function calls and pointers
- **AST construction (`ast.h`)**: the tree is printed in preorder, with indentation that shows the nesting of the code
- **Error handling**: precise messages for lexical and syntax errors (for example an unclosed comment, a missing `;`, parameters in the wrong order, or a function that returns a value but has no `return`)
- **Automated test suite**: `run_tests.sh` builds the project and runs 20 test programs (5 valid, 15 invalid), checking that valid programs produce a tree and invalid ones produce an error

## Example

Input:

```
def foo(): returns int
begin
    return 0;
end
```

Output: an indented AST starting with `(CODE (FUNC foo (ARGS NONE) (RET INT) (BODY ...)))`.

Invalid input (missing semicolon):

```
def f():
begin
    x = 5
end
```

Output: a syntax error with the line number and what was expected.

## Build and run

Requires `flex` (or `lex`), `yacc` (or `bison`) and a C compiler.

```bash
lex scanner.l
yacc parser.y
cc -o parser y.tab.c -ll -Ly
./parser < tests/good1.txt
```

Run all the tests:

```bash
bash run_tests.sh
```

## Project structure

```
scanner.l      Lexical analyzer (Lex)
parser.y       Grammar, AST building and error handling (Yacc)
ast.h          AST node structure and preorder printing
run_tests.sh   Builds the project and runs the test suite
tests/         Valid (good*) and invalid (bad*) test programs
```

## Tech

C · Lex · Yacc · Bash · Linux
