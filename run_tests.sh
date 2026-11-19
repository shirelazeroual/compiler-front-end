#!/bin/bash
# Compile the project and run all the tests in the tests/ folder.
# Usage:  bash run_tests.sh

lex scanner.l && yacc parser.y 2>/dev/null && cc -o parser y.tab.c -ll -Ly || { echo "BUILD FAILED"; exit 1; }
echo "Build OK"
echo

echo "===== LEGAL programs (must print a tree) ====="
for f in tests/good*.txt
do
    if ./parser < "$f" 2>/dev/null | head -1 | grep -q "(CODE"
    then printf "%-34s OK\n" "$f"
    else printf "%-34s PROBLEM\n" "$f"; ./parser < "$f"
    fi
done
echo

echo "===== ILLEGAL programs (must print an error) ====="
for f in tests/bad*.txt
do
    printf "%-34s " "$f"
    out=$(./parser < "$f" 2>&1)
    if echo "$out" | grep -q "error"
    then echo "$out"
    else echo "PROBLEM: no error was printed"
    fi
done
