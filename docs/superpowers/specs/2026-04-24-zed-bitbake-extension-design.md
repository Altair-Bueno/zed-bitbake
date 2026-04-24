# zed-bitbake Extension Design

**Date:** 2026-04-24  
**Status:** Approved

---

## Overview

A Zed editor extension that adds BitBake language support for Yocto/OpenEmbedded development. Covers syntax highlighting, bracket matching, auto-indentation, code outline, bash/Python injection, and a full-featured LSP via `language-server-bitbake`.

---

## Directory Structure

```
zed-bitbake/
├── extension.toml
├── Cargo.toml
├── src/
│   └── lib.rs
└── languages/
    └── bitbake/
        ├── config.toml
        ├── highlights.scm    # adapted from upstream, with attribution
        ├── injections.scm    # adapted from upstream, with attribution
        ├── indents.scm       # hand-written for Zed schema
        ├── brackets.scm      # hand-written
        └── outline.scm       # hand-written
```

---

## extension.toml

```toml
id = "bitbake"
name = "BitBake"
description = "BitBake language support for Yocto/OpenEmbedded."
version = "0.1.0"
schema_version = 1
authors = ["..."]
repository = "https://github.com/..."

[language_servers.bitbake-language-server]
name = "BitBake Language Server"
language = "BitBake"

[grammars.bitbake]
repository = "https://github.com/tree-sitter-grammars/tree-sitter-bitbake"
commit = "a5d04fdb5a69a02b8fa8eb5525a60dfb5309b73b"
```

---

## Language Metadata (`languages/bitbake/config.toml`)

```toml
name = "BitBake"
grammar = "bitbake"
path_suffixes = ["bb", "bbappend", "bbclass", "inc"]
line_comments = ["# "]
tab_size = 4
```

`.conf` is intentionally excluded to avoid collisions with unrelated configuration files.

---

## Rust Crate

### Cargo.toml

```toml
[package]
name = "zed-bitbake"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
zed_extension_api = "0.7.0"
```

### src/lib.rs — LSP wiring (Vue pattern)

Auto-installs `language-server-bitbake` (npm v2.8.0+) into the extension's working directory using Zed's built-in npm API. Zed manages the Node.js binary; no Node on the user's PATH required.

**Key constants:**
- `SERVER_PATH = "node_modules/language-server-bitbake/out/server.js"`
- `PACKAGE_NAME = "language-server-bitbake"`

**Startup sequence:**
1. Check if server file exists at `SERVER_PATH`
2. Fetch `version = zed::npm_package_latest_version(PACKAGE_NAME)?`
3. Compare against `zed::npm_package_installed_version(PACKAGE_NAME)?`
4. If outdated or missing: `zed::npm_install_package(PACKAGE_NAME, &version)`
5. Return `zed::Command { command: zed::node_binary_path()?, args: [abs_server_path, "--stdio"] }`

Cache `did_find_server: bool` to skip the version check on subsequent calls within the same session.

---

## Tree-sitter Grammar

- **Source:** `https://github.com/tree-sitter-grammars/tree-sitter-bitbake`
- **Commit:** `a5d04fdb5a69a02b8fa8eb5525a60dfb5309b73b`
- **License:** MIT — files adapted with attribution header comment

---

## Tree-sitter Queries

### highlights.scm

Adapted from upstream `queries/highlights.scm` (MIT, attributed). Capture name remapping applied:

| Upstream capture | Zed capture |
|---|---|
| `@include`, `@conditional`, `@repeat`, `@exception`, `@keyword.function`, `@keyword.operator`, `@keyword.coroutine`, `@keyword.return`, `@storageclass` | `@keyword` |
| `@type.qualifier`, `@type.definition`, `@namespace` | `@type` |
| `@variable.builtin` | `@variable.special` |
| `@function.call`, `@function.builtin`, `@function.macro`, `@method.call` | `@function` |
| `@field` | `@property` |
| `@parameter` | `@variable.parameter` |
| `@float` | `@number` |
| `@constant.builtin` | `@constant` |
| `@string.documentation` | `@string` |

Additional changes:
- `@spell` directive stripped (Zed ignores it)
- `@none` lines stripped (Zed has no reset capture)
- `#lua-match?` → `#match?` (regex predicate)
- Lua character classes converted: `%l` → `a-z`, `%u` → `[A-Z]`

### injections.scm

Adapted from upstream. The `bash` and `regex` injections work as-is. The `comment` injection (Neovim-style) is removed — Zed handles comment highlighting through `highlights.scm` directly.

### indents.scm (hand-written)

Zed uses `@indent` / `@end` captures. The upstream file uses Helix-style `@indent.begin` / `@indent.align` which is incompatible. Write a minimal version covering:
- `python_function_definition` and `function_definition` → `@indent`
- `anonymous_python_function` body blocks → `@indent`
- Closing `}` → `@end`

### brackets.scm (hand-written)

Standard bracket pairs for BitBake:
- `(` / `)`, `[` / `]`, `{` / `}`, `"` / `"`

### outline.scm (hand-written)

Expose tasks and functions in the file outline:
- `function_definition` — BitBake shell tasks (`do_compile() { ... }`)
- `python_function_definition` — Python tasks (`python do_compile() { ... }`)
- `anonymous_python_function` — inline Python blocks
- `addtask_statement` — task dependency declarations

---

## Update Strategy

To update queries from a new upstream release:
1. Copy the relevant `.scm` files from the grammar repo
2. Re-apply the capture remappings documented above
3. Preserve the attribution header comment
4. Update the `commit` in `extension.toml`

---

## Out of Scope

- `.conf` file association (ambiguous with other tools)
- Debugger support
- Custom completion label formatting (LSP defaults are sufficient)
- Semantic token rules (LSP provides these; no custom mapping needed initially)
