# zed-bitbake Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Zed editor extension that provides BitBake language support: syntax highlighting, bracket matching, auto-indentation, code outline, embedded bash/Python injection, and a full LSP via `language-server-bitbake` (npm).

**Architecture:** A Rust cdylib crate compiled to `wasm32-wasip1` that wires up the `language-server-bitbake` npm package using Zed's built-in npm API (same pattern as the official Vue extension). Tree-sitter queries are adapted from `tree-sitter-grammars/tree-sitter-bitbake` (MIT) with Zed-compatible capture names.

**Tech Stack:** Rust + `zed_extension_api = "0.7.0"`, `language-server-bitbake` npm package, `tree-sitter-grammars/tree-sitter-bitbake` grammar.

---

## File Map

| File | Purpose |
|---|---|
| `extension.toml` | Extension manifest: id, grammar ref, LSP declaration |
| `Cargo.toml` | Rust crate config (cdylib, wasm target) |
| `src/lib.rs` | LSP install + command wiring |
| `languages/bitbake/config.toml` | Language name, file extensions, comment tokens |
| `languages/bitbake/highlights.scm` | Syntax highlighting (adapted from upstream) |
| `languages/bitbake/injections.scm` | Bash/Python injection (adapted from upstream) |
| `languages/bitbake/brackets.scm` | Bracket matching (hand-written) |
| `languages/bitbake/indents.scm` | Auto-indentation (hand-written) |
| `languages/bitbake/outline.scm` | Code outline for tasks/functions (hand-written) |
| `test/hello.bb` | Sample recipe for manual smoke testing in Zed |

---

## Task 1: Prerequisites

**Files:**
- No files created yet

- [ ] **Step 1: Install the wasm32 Rust target**

```bash
rustup target add wasm32-wasip1
```

Expected output includes: `wasm32-wasip1` in installed list.

- [ ] **Step 2: Verify the target is available**

```bash
rustup target list --installed | grep wasm
```

Expected: `wasm32-wasip1`

---

## Task 2: Scaffold the extension

**Files:**
- Create: `extension.toml`
- Create: `Cargo.toml`
- Create: `src/lib.rs` (stub)
- Create: `languages/bitbake/` (directory)

- [ ] **Step 1: Create `extension.toml`**

```toml
id = "bitbake"
name = "BitBake"
description = "BitBake language support for Yocto/OpenEmbedded."
version = "0.1.0"
schema_version = 1
authors = ["your name <your@email>"]
repository = "https://github.com/yourorg/zed-bitbake"

[language_servers.bitbake-language-server]
name = "BitBake Language Server"
language = "BitBake"

[grammars.bitbake]
repository = "https://github.com/tree-sitter-grammars/tree-sitter-bitbake"
commit = "a5d04fdb5a69a02b8fa8eb5525a60dfb5309b73b"
```

- [ ] **Step 2: Create `Cargo.toml`**

```toml
[package]
name = "zed_bitbake"
version = "0.1.0"
edition = "2021"
publish = false
license = "MIT"

[lib]
path = "src/lib.rs"
crate-type = ["cdylib"]

[dependencies]
zed_extension_api = "0.7.0"
```

- [ ] **Step 3: Create `src/lib.rs` stub**

```rust
use zed_extension_api as zed;

struct BitBakeExtension;

impl zed::Extension for BitBakeExtension {
    fn new() -> Self {
        Self
    }
}

zed::register_extension!(BitBakeExtension);
```

- [ ] **Step 4: Create language directory**

```bash
mkdir -p languages/bitbake
```

- [ ] **Step 5: Verify the crate compiles to wasm**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -5
```

Expected: `Finished release profile [optimized] target(s)` with no errors.

- [ ] **Step 6: Commit**

```bash
git add extension.toml Cargo.toml Cargo.lock src/lib.rs
git commit -m "feat: scaffold zed-bitbake extension"
```

---

## Task 3: Language metadata

**Files:**
- Create: `languages/bitbake/config.toml`

- [ ] **Step 1: Create `languages/bitbake/config.toml`**

```toml
name = "BitBake"
grammar = "bitbake"
path_suffixes = ["bb", "bbappend", "bbclass", "inc"]
line_comments = ["# "]
tab_size = 4
```

- [ ] **Step 2: Rebuild to confirm Zed picks up the language config**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -3
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add languages/bitbake/config.toml
git commit -m "feat: add BitBake language metadata"
```

---

## Task 4: LSP wiring

**Files:**
- Modify: `src/lib.rs`

- [ ] **Step 1: Replace stub `src/lib.rs` with full LSP implementation**

```rust
use std::env;
use std::fs;
use zed_extension_api::{self as zed, Result};

const SERVER_PATH: &str = "node_modules/language-server-bitbake/out/server.js";
const PACKAGE_NAME: &str = "language-server-bitbake";

struct BitBakeExtension {
    did_find_server: bool,
}

impl BitBakeExtension {
    fn server_exists(&self) -> bool {
        fs::metadata(SERVER_PATH).map_or(false, |stat| stat.is_file())
    }

    fn server_script_path(
        &mut self,
        language_server_id: &zed::LanguageServerId,
    ) -> Result<String> {
        let server_exists = self.server_exists();
        if self.did_find_server && server_exists {
            return Ok(SERVER_PATH.to_string());
        }

        zed::set_language_server_installation_status(
            language_server_id,
            &zed::LanguageServerInstallationStatus::CheckingForUpdate,
        );

        let version = zed::npm_package_latest_version(PACKAGE_NAME)?;

        if !server_exists
            || zed::npm_package_installed_version(PACKAGE_NAME)?.as_ref() != Some(&version)
        {
            zed::set_language_server_installation_status(
                language_server_id,
                &zed::LanguageServerInstallationStatus::Downloading,
            );

            let result = zed::npm_install_package(PACKAGE_NAME, &version);
            match result {
                Ok(()) => {
                    if !self.server_exists() {
                        Err(format!(
                            "installed package '{PACKAGE_NAME}' did not contain expected path '{SERVER_PATH}'",
                        ))?;
                    }
                }
                Err(error) => {
                    if !self.server_exists() {
                        Err(error)?;
                    }
                }
            }
        }

        self.did_find_server = true;
        Ok(SERVER_PATH.to_string())
    }
}

impl zed::Extension for BitBakeExtension {
    fn new() -> Self {
        Self {
            did_find_server: false,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &zed::LanguageServerId,
        _worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let server_path = self.server_script_path(language_server_id)?;
        Ok(zed::Command {
            command: zed::node_binary_path()?,
            args: vec![
                env::current_dir()
                    .unwrap()
                    .join(&server_path)
                    .to_string_lossy()
                    .to_string(),
                "--stdio".to_string(),
            ],
            env: Default::default(),
        })
    }
}

zed::register_extension!(BitBakeExtension);
```

- [ ] **Step 2: Build and confirm it compiles**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -5
```

Expected: `Finished release profile [optimized] target(s)` with no errors.

- [ ] **Step 3: Commit**

```bash
git add src/lib.rs Cargo.lock
git commit -m "feat: add LSP wiring for language-server-bitbake"
```

---

## Task 5: Syntax highlighting

**Files:**
- Create: `languages/bitbake/highlights.scm`

- [ ] **Step 1: Create `languages/bitbake/highlights.scm`**

This is adapted from `https://github.com/tree-sitter-grammars/tree-sitter-bitbake/blob/master/queries/highlights.scm` (MIT, Copyright Amaan Qureshi). Capture names remapped for Zed compatibility: `@include`/`@conditional`/`@repeat`/`@exception`/`@keyword.*`/`@storageclass` → `@keyword`; `@field` → `@property`; `@parameter` → `@variable.parameter`; `@variable.builtin` → `@variable.special`; `@float` → `@number`; `@namespace`/`@type.qualifier`/`@type.definition` → `@type`; `@function.*`/`@method.*` → `@function`; `@constant.builtin`/`@string.documentation` → `@constant`/`@string`; `#lua-match?` → `#match?`; Lua `%l`/`%u` → regex `[a-z]`/`[A-Z]`; `@spell`/`@none` lines removed.

```scheme
; Adapted from https://github.com/tree-sitter-grammars/tree-sitter-bitbake (MIT)
; Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>

; Includes

[
  "inherit"
  "include"
  "require"
  "export"
  "import"
] @keyword

; Keywords

[
  "unset"
  "EXPORT_FUNCTIONS"
  "python"
  "assert"
  "exec"
  "global"
  "nonlocal"
  "pass"
  "print"
  "with"
  "as"
] @keyword

["async" "await"] @keyword

["return" "yield"] @keyword
(yield "from" @keyword)

(future_import_statement "from" @keyword "__future__" @constant)
(import_from_statement "from" @keyword)
"import" @keyword

(aliased_import "as" @keyword)

["if" "elif" "else"] @keyword
["for" "while" "break" "continue"] @keyword

[
  "try"
  "except"
  "except*"
  "raise"
  "finally"
] @keyword

(raise_statement "from" @keyword)
(try_statement (else_clause "else" @keyword))

[
  "addtask"
  "deltask"
  "addhandler"
  "def"
  "lambda"
] @keyword

["before" "after"] @keyword
["append" "prepend" "remove"] @type

; Variables

[
  (identifier)
  (python_identifier)
] @variable

[
  "noexec"
  "INHERIT"
  "OVERRIDES"
  "$BB_ENV_PASSTHROUGH"
  "$BB_ENV_PASSTHROUGH_ADDITIONS"
] @variable.special

; Identifier naming conventions

((python_identifier) @type
 (#match? @type "^[A-Z].*[a-z]"))

([(identifier) (python_identifier)] @constant
 (#match? @constant "^[A-Z][A-Z_0-9]*$"))

((python_identifier) @constant
 (#match? @constant "^__[a-zA-Z0-9_]*__$"))

((python_identifier) @constant
 (#any-of? @constant
   "NotImplemented" "Ellipsis" "quit" "exit"
   "copyright" "credits" "license"))

((assignment
  left: (python_identifier) @type
  (type (python_identifier) @_annotation))
 (#eq? @_annotation "TypeAlias"))

((assignment
  left: (python_identifier) @type
  right: (call
    function: (python_identifier) @_func))
 (#any-of? @_func "TypeVar" "NewType"))

; Properties / fields

(flag) @property

((attribute
    attribute: (python_identifier) @property)
 (#match? @property "^[a-z_].*$"))

; Functions

(call function: (python_identifier) @function)

(call function: (attribute attribute: (python_identifier) @function))

((call function: (python_identifier) @constructor)
 (#match? @constructor "^[A-Z]"))

((call function: (attribute attribute: (python_identifier) @constructor))
 (#match? @constructor "^[A-Z]"))

((call function: (python_identifier) @function)
 (#any-of? @function
   "abs" "all" "any" "ascii" "bin" "bool" "breakpoint" "bytearray" "bytes"
   "callable" "chr" "classmethod" "compile" "complex" "delattr" "dict" "dir"
   "divmod" "enumerate" "eval" "exec" "filter" "float" "format" "frozenset"
   "getattr" "globals" "hasattr" "hash" "help" "hex" "id" "input" "int"
   "isinstance" "issubclass" "iter" "len" "list" "locals" "map" "max"
   "memoryview" "min" "next" "object" "oct" "open" "ord" "pow" "print"
   "property" "range" "repr" "reversed" "round" "set" "setattr" "slice"
   "sorted" "staticmethod" "str" "sum" "super" "tuple" "type" "vars" "zip"
   "__import__"))

(python_function_definition name: (python_identifier) @function)

(type (python_identifier) @type)
(type (subscript (python_identifier) @type))

((call
  function: (python_identifier) @_isinstance
  arguments: (argument_list (_) (python_identifier) @type))
 (#eq? @_isinstance "isinstance"))

(anonymous_python_function (identifier) @function)
(function_definition (identifier) @function)
(addtask_statement (identifier) @function)
(deltask_statement (identifier) @function)
(export_functions_statement (identifier) @function)
(addhandler_statement (identifier) @function)

(python_function_definition
  body: (block . (expression_statement (python_string) @string)))

; Namespace / inherit paths

(inherit_path) @type

; Parameters

(parameters (python_identifier) @variable.parameter)
(lambda_parameters (python_identifier) @variable.parameter)
(lambda_parameters (tuple_pattern (python_identifier) @variable.parameter))
(keyword_argument name: (python_identifier) @variable.parameter)
(default_parameter name: (python_identifier) @variable.parameter)
(typed_parameter (python_identifier) @variable.parameter)
(typed_default_parameter (python_identifier) @variable.parameter)
(parameters (list_splat_pattern (python_identifier) @variable.parameter))
(parameters (dictionary_splat_pattern (python_identifier) @variable.parameter))

; Literals

(none) @constant
[(true) (false)] @boolean

((python_identifier) @variable.special (#eq? @variable.special "self"))
((python_identifier) @variable.special (#eq? @variable.special "cls"))

(integer) @number
(float) @number

; Operators

[
  "?=" "??=" ":=" "=+" ".=" "=." "-" "-=" "!="
  "*" "**" "**=" "*=" "/" "//" "//=" "/="
  "&" "&=" "%" "%=" "^" "^=" "+" "+="
  "<" "<<" "<<=" "<=" "<>" "=" "==" ">" ">=" ">>" ">>="
  "@" "@=" "|" "|=" "~" "->"
] @operator

["and" "in" "is" "not" "or" "is not" "not in" "del"] @keyword

; String literals

[
  (string)
  (python_string)
  "\""
] @string

(include_path) @string.special

[
  (escape_sequence)
  (escape_interpolation)
] @string.escape

; Punctuation

["(" ")" "{" "}" "[" "]"] @punctuation.bracket

[":" "->" ";" "." "," (ellipsis)] @punctuation.delimiter

(variable_expansion ["${" "}"] @punctuation.special)
(inline_python ["${@" "}"] @punctuation.special)
(interpolation "{" @punctuation.special "}" @punctuation.special)

(type_conversion) @function

; Built-in types

([(identifier) (python_identifier)] @type.builtin
 (#any-of? @type.builtin
   "BaseException" "Exception" "ArithmeticError" "BufferError" "LookupError"
   "AssertionError" "AttributeError" "EOFError" "FloatingPointError"
   "GeneratorExit" "ImportError" "ModuleNotFoundError" "IndexError" "KeyError"
   "KeyboardInterrupt" "MemoryError" "NameError" "NotImplementedError" "OSError"
   "OverflowError" "RecursionError" "ReferenceError" "RuntimeError"
   "StopIteration" "StopAsyncIteration" "SyntaxError" "IndentationError"
   "TabError" "SystemError" "SystemExit" "TypeError" "UnboundLocalError"
   "UnicodeError" "UnicodeEncodeError" "UnicodeDecodeError"
   "UnicodeTranslateError" "ValueError" "ZeroDivisionError" "EnvironmentError"
   "IOError" "WindowsError" "BlockingIOError" "ChildProcessError"
   "ConnectionError" "BrokenPipeError" "ConnectionAbortedError"
   "ConnectionRefusedError" "ConnectionResetError" "FileExistsError"
   "FileNotFoundError" "InterruptedError" "IsADirectoryError"
   "NotADirectoryError" "PermissionError" "ProcessLookupError" "TimeoutError"
   "Warning" "UserWarning" "DeprecationWarning" "PendingDeprecationWarning"
   "SyntaxWarning" "RuntimeWarning" "FutureWarning" "ImportWarning"
   "UnicodeWarning" "BytesWarning" "ResourceWarning"
   "bool" "int" "float" "complex" "list" "tuple" "range" "str"
   "bytes" "bytearray" "memoryview" "set" "frozenset" "dict" "type" "object"))

(comment) @comment

(ERROR) @error
```

- [ ] **Step 2: Rebuild**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -3
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add languages/bitbake/highlights.scm
git commit -m "feat: add BitBake syntax highlighting queries"
```

---

## Task 6: Language injections

**Files:**
- Create: `languages/bitbake/injections.scm`

- [ ] **Step 1: Create `languages/bitbake/injections.scm`**

Adapted from upstream. The `comment` injection (Neovim-specific) is removed. `#lua-match?` replaced with `#match?`.

```scheme
; Adapted from https://github.com/tree-sitter-grammars/tree-sitter-bitbake (MIT)
; Copyright (c) 2023 Amaan Qureshi <amaanq12@gmail.com>

; Inject regex language into re.* string arguments
(call
  function: (attribute object: (python_identifier) @_re)
  arguments: (argument_list
    (python_string (string_content) @injection.content) @_string)
  (#eq? @_re "re")
  (#match? @_string "^r.*")
  (#set! injection.language "regex"))

; Inject bash into shell task bodies
((shell_content) @injection.content
  (#set! injection.language "bash"))
```

- [ ] **Step 2: Rebuild**

```bash
cargo build --target wasm32-wasip1 --release 2>&1 | tail -3
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add languages/bitbake/injections.scm
git commit -m "feat: add bash/regex injection queries"
```

---

## Task 7: Bracket matching

**Files:**
- Create: `languages/bitbake/brackets.scm`

- [ ] **Step 1: Create `languages/bitbake/brackets.scm`**

```scheme
("[" @open "]" @close)
("{" @open "}" @close)
("(" @open ")" @close)
("\"" @open "\"" @close)
```

- [ ] **Step 2: Commit**

```bash
git add languages/bitbake/brackets.scm
git commit -m "feat: add bracket matching queries"
```

---

## Task 8: Auto-indentation

**Files:**
- Create: `languages/bitbake/indents.scm`

- [ ] **Step 1: Create `languages/bitbake/indents.scm`**

Zed uses `@indent` on the block node and `@end` on the closing delimiter. Covers shell task bodies, Python task bodies, and anonymous Python blocks.

```scheme
(function_definition "}" @end) @indent
(python_function_definition "}" @end) @indent
(anonymous_python_function "}" @end) @indent
```

- [ ] **Step 2: Commit**

```bash
git add languages/bitbake/indents.scm
git commit -m "feat: add auto-indentation queries"
```

---

## Task 9: Code outline

**Files:**
- Create: `languages/bitbake/outline.scm`

- [ ] **Step 1: Create `languages/bitbake/outline.scm`**

Exposes BitBake tasks and function definitions in Zed's file outline panel.

```scheme
(function_definition
  (identifier) @name) @item

(python_function_definition
  name: (python_identifier) @name) @item

(anonymous_python_function
  (identifier) @name) @item

(addtask_statement
  (identifier) @name) @item
```

- [ ] **Step 2: Commit**

```bash
git add languages/bitbake/outline.scm
git commit -m "feat: add code outline queries"
```

---

## Task 10: Create a test fixture and load in Zed

**Files:**
- Create: `test/hello.bb`

- [ ] **Step 1: Create `test/hello.bb`**

A sample recipe that exercises all syntax constructs — keywords, variables, strings, shell tasks, Python tasks, `addtask`, comments, variable expansion.

```bitbake
# Sample BitBake recipe for smoke-testing the Zed extension
SUMMARY = "Hello World package"
DESCRIPTION = "A minimal test recipe"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=abc123"

HELLO_VERSION = "1.0"
SRC_URI = "git://github.com/example/hello.git;protocol=https;branch=main"
SRCREV = "abc123def456"

S = "${WORKDIR}/hello-${HELLO_VERSION}"

inherit autotools pkgconfig

do_configure() {
    ./configure --prefix=${D}${prefix} --enable-static
}

do_compile() {
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 hello ${D}${bindir}/hello
}

python do_display_banner() {
    bb.plain("Building hello world")
    version = d.getVar('HELLO_VERSION')
    if version:
        bb.warn("Version: %s" % version)
}

addtask do_display_banner before do_configure after do_fetch

PACKAGES =+ "hello-dev"
FILES:hello-dev = "${includedir}/*"
```

- [ ] **Step 2: Do a final clean build**

```bash
cargo build --target wasm32-wasip1 --release 2>&1
```

Expected: `Finished release profile [optimized]` with no errors or warnings.

- [ ] **Step 3: Install as a dev extension in Zed**

In Zed:
1. Open the command palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)
2. Run `zed: install dev extension`
3. Select the `zed-bitbake` directory (the repo root)

Zed will compile the WASM and load the extension. Watch the bottom status bar — it should show "Installing BitBake Language Server" then go idle.

- [ ] **Step 4: Open the test fixture and verify**

Open `test/hello.bb` in Zed. Check:

| Feature | What to look for |
|---|---|
| Syntax highlighting | Keywords (`inherit`, `addtask`, `python`, `def`) in keyword color; strings in string color; variables (`${D}`, `${prefix}`) with special punctuation color; comments in comment color |
| Bracket matching | Place cursor next to `{` or `(` — matching bracket should highlight |
| LSP | Bottom status bar shows "BitBake Language Server" active; hover over a variable for docs |
| Code outline | Open outline panel — `do_configure`, `do_compile`, `do_install`, `do_display_banner`, `addtask do_display_banner` should appear |
| Bash injection | Inside `do_configure()` body, shell commands should have bash highlighting |

- [ ] **Step 5: Commit the test fixture**

```bash
git add test/hello.bb
git commit -m "test: add hello.bb smoke test fixture"
```

---

## Troubleshooting

**Build fails with `error[E0432]: unresolved import`:**
Run `cargo update` to refresh `Cargo.lock`, then rebuild.

**Zed shows "Extension failed to load":**
Check Zed's extension log: `Help > Toggle Dev Tools > Console`. Likely a missing wasm target or WASM ABI mismatch.

**LSP never activates / stays "Installing":**
Zed downloads Node.js the first time. Open `~/.local/share/zed/node` (Linux) or `~/Library/Application Support/Zed/node` (macOS) — if empty, Zed may be downloading. Wait ~30s, then reopen the file.

**Highlighting looks wrong for a specific construct:**
Open Zed's tree-sitter inspector: `Editor > Open Log > Debug Syntax Tree`. Compare the node names against the patterns in `highlights.scm`.
