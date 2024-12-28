# C Compiler from Scratch Using Lex and Yacc

This project involves implementing a simple compiler from scratch with modern optimizations for a subset of C language using **Flex** and **Yacc** for lexical and syntactical analysis, and includes a custom-built **Symbol Table** for semantic analysis. The generated intermediate code can be run using emu8086.

## Project Structure

- **1705051.l**: Contains the lexical analyzer definition written in **Flex**.
- **1705051.y**: Contains the syntax analyzer (parser) definition written in **Yacc**.
- **SymbolTable.h**: Header file for the custom **Symbol Table** implementation.
- **script.sh**: A Bash script to automate the compilation and execution process.

## Features

1. **Lexical Analysis**: 
   - Tokenizes the input source code using Flex.
2. **Syntax Analysis**:
   - Implements parsing rules using Yacc.
3. **Semantic Analysis**:
   - Utilizes a custom **Symbol Table** to manage variables, functions, and their attributes.
4. **Automated Workflow**:
   - The provided script automates the entire process from generating the parser and scanner to running the compiled code.


