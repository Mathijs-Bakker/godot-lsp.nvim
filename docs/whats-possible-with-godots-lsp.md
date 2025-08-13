Godot’s built-in Language Server Protocol (LSP) implementation for GDScript is functional but not on the same level as something like clangd or pyright — there are clear limits.

Here’s a breakdown:

## ✅ What’s possible with Godot’s LSP
Most of the core LSP features are supported because Godot’s GDScript language server runs directly inside the editor process (or in headless mode for external editors):

- **Diagnostics**
  - Syntax errors, parse errors, and some static type errors.
  - Warnings for unused variables, unreachable code, etc.
- Go to definition
  - Works for variables, functions, classes, and signals within known scripts.
  - Can jump into built-in classes and engine source for some types.
- **Hover / symbol info**
  - Shows type hints, docstrings, and sometimes inferred types.
- **Autocomplete / IntelliSense**
  - Includes functions, members, signals, constants, and built-ins.
- **Signature help**
  - Shows function parameters and default values.
- **Rename symbol**
  - Works for local and project-wide symbols (though not 100% perfect with dynamic code).
- **Document symbols / outline view**
  - Lists functions, variables, signals, classes in the current file.
- **Workspace symbols search**
  - Find classes and members across the project.
- **Diagnostics on save or live**
  - Immediate feedback as you type.

## ❌ What’s (currently) not possible or incomplete
Some LSP capabilities are missing or not as strong as in other language servers:

- **Go to type definition**
  - Not implemented — you can go to the variable’s definition, but not directly to the class/type that it refers to.
- **Full type inference across all dynamic patterns**
  - If your code uses a lot of load() or dynamic property access, LSP may fail to guess types.
- **Find all references (cross-file)**
  - Only partially works; it often misses dynamically referenced symbols.
- **Code formatting**
  - No native formatter via LSP — you need external tools like gdformat.
- **Code actions / quick fixes**
  - Minimal support; mostly for adding missing imports or basic fixes.
- **Refactoring tools beyond rename**
  - No extract method, move symbol, inline variable, etc.
- **Semantic highlighting**
  - The highlighting is basic; no advanced semantic tokenization like in C# or TypeScript.
- **Inlay hints**
  - Parameter name hints, inferred type hints are not exposed via LSP yet.
- **Project-wide static analysis beyond syntax/types**
  - No lint rules for style, unused exports, complexity, etc., unless you add your own tooling.
- **Debug integration via LSP**
  - Debugging is still via Godot’s own debugger, not an LSP feature.

## Why some things aren’t possible
The main reasons:
1 **Dynamic nature of GDScript** — without running the code, some types or symbol references can’t be resolved.
1 **Partial LSP feature implementation** — Godot’s LSP implementation covers common editor needs, but not all of the optional LSP spec.
1 **No external type indexer** — The LSP relies on Godot’s internal parser and symbol table, which doesn’t store all relationships needed for things like “Go to type definition”.

---

Here’s a Godot LSP feature support table based on the official LSP spec and what’s currently implemented for GDScript.
I’ve marked each as ✅ supported, ⚠️ partial, or ❌ not supported, with some notes.

### Godot LSP Feature Support Matrix
| LSP Feature | Status | Notes |
| --- | --- | --- |
| Hover | ✅ | Shows type hints, docstrings, constants, and inferred type where possible. |
| Completion | ✅ | Autocomplete for functions, members, constants, signals, keywords. Works with static typing and some inference. |
| Signature Hel | ✅ | Shows parameters and defaults when typing a call. |
| Goto Definition | ✅ | Works for symbols with known locations, including built-ins. |
| Goto Type Definition | ❌ | Not implemented — can’t directly jump to a type/class from a variable. |
| Goto Implementation | ❌ | Not implemented — no way to jump to implementing scripts/interfaces. |
| Find References | ⚠️ | Works within same file; cross-file is unreliable and misses dynamic uses. |
| Document Symbols | ✅ | Lists functions, variables, signals, classes for current file. |
| Workspace Symbols | ✅ | Search across project by name. |
| Document Highlights | ⚠️ | Highlights occurrences in file, but sometimes misses dynamic usages. |
| Rename Symbol | ⚠️ | Works for many cases, but can break in dynamic code or miss external references. |
| Document Formatting | ❌ | No formatter built into Godot LSP; use gdformat externally. |
| Range Formatting | ❌ | Same as above. |
| On-Type Formatting | ❌ | Not implemented. |
| Code Actions / Quick Fixes | ⚠️ | Very limited — can sometimes add missing imports. No refactor suggestions. |
| Code Lens | ❌ | Not implemented. |
| Inlay Hints | ❌ | Not exposed; Godot shows some hints in-editor, but they don’t come through LSP. |
| Semantic Tokens | ⚠️ | Basic tokenization; lacks advanced semantic highlighting. |
| Diagnostics | ✅ | Shows syntax errors, some type errors, warnings for unused variables, etc. |
| Folding Ranges | ✅ | Works for functions, classes, and some blocks. |
| Selection Ranges | ⚠️ | Works for basic expressions and blocks, but not perfect. |
| Linked Editing Ranges | ❌ | Not implemented. |
| References to built-in docs | ✅ | Shows engine documentation in hover popups. |
| Debug Adapter Protocol | ❌ | Debugging is handled separately by Godot, not via LSP. |

### Biggest missing pieces for Godot LSP:
- **Go to Type Definition**
- **Code formatting via LSP**
- **Refactoring beyond rename**
- **Robust find-references across dynamic code**
- **Inlay hints / advanced semantic tokens**

## Where the “Godot LSP spec” comes from
1. Godot’s official documentation
   The Godot manual confirms that Godot includes built-in Language Server Protocol (LSP) support—specifically for features like autocomplete, error highlighting, and go-to-definition [Godot Engine Docs](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html). However, it doesn’t publish a comprehensive capability list or spec beyond that.

1. Godot’s source code
   The real authority is within Godot’s own repository—particularly `modules/gdscript/language_server`. There, the actual handlers (like `handle_completion`, `handle_definition, `handle_hover`, etc.) define what methods Godot’s LSP supports—or doesn’t support.

   - For instance, if you search for methods handling `textDocument/typeDefinition`, none exist, which directly explains why Go to Type Definition doesn’t work.
   - Similarly, there are handlers for completion and diagnostics, but none for things like formatting or code actions.
     So the supported features are evident in the code itself.

1. LSP standard (Microsoft spec)
   To know what’s possible in theory, I compared Godot’s implementation to the official [Language Server Protocol](https://microsoft.github.io/language-server-protocol/) specification—which lists all possible features like type definition, code actions, formatting, refactoring, inlay hints, semantic tokens, etc. 
[Wikipedia](https://en.wikipedia.org/wiki/Language_Server_Protocol)
   The missing handlers in Godot’s code (especially around type definition, implementation, formatting, etc.) reveal which features are not implemented.

1. Empirical testing
   Another practical way: start Godot with LSP enabled (e.g., in headless mode or using verbose flags) and monitor the actual LSP messages your IDE sends—then observe which ones Godot responds to and which methods lead to no response. This confirms partial vs full support, and helps catch edge cases.

### Summary Table
| Source | What It Provides |
| Godot Documentation | Confirms LSP support and basic features (autocomplete, errors, go-to-definition, etc.) [Godot Engine Docs](https://docs.godotengine.org/en/stable/tutorials/editor/external_editor.html) |
| Godot Source (LSP handlers in code) | Definitively shows which textDocument/… requests are implemented (or missing) |
| Official LSP Spec (Microsoft) | Full list of possible LSP methods for comparison [Wikipedia](https://en.wikipedia.org/wiki/Language_Server_Protocol) |
| Practical Testing (LSP logs/debugging) | Confirms what works in real-world usage, and what fails or is partial |
