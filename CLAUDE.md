This file provides guidance to AI agents when working with code in this
repository.

# Mandatory References

Before doing any work on this extension you MUST consult the Zed extension
documentation at https://zed.dev/docs/extensions. The API surface changes
frequently and assumptions from other extension ecosystems MUST NOT be applied
without verification.

You MUST use the **Superpowers** skill for any complex multi-step task (grammar
updates, LSP upgrades, new query authoring).

# What This Is

A [Zed editor](https://zed.dev) extension providing BitBake (Yocto/OpenEmbedded)
language support. The reference implementation used as the structural template
is https://github.com/zed-extensions/vue.

Two external dependencies drive the implementation:

- **LSP**: `language-server-bitbake` npm package
  (https://www.npmjs.com/package/language-server-bitbake), sourced from the VS
  Code BitBake extension project at
  https://github.com/yoctoproject/vscode-bitbake. The extension auto-installs it
  at runtime using Zed's bundled Node.js; no external Node.js is required.
- **Grammar**: https://github.com/tree-sitter-grammars/tree-sitter-bitbake,
  pinned to a specific commit in `extension.toml`. The `grammars/bitbake/`
  directory is a git submodule tracking this upstream.

# Build Commands

```bash
# Install the required compilation target (once)
rustup target add wasm32-wasip1

# Build the extension
cargo build --release --target wasm32-wasip1

# Install locally into Zed for manual testing
# In Zed: Extensions → Install Dev Extension → select this directory
```

There is no automated test suite. Verification is manual: open `test/hello.bb`
in Zed with the dev extension loaded and confirm syntax highlighting, outline,
indentation, and LSP features work.

# Architecture

The extension compiles to a single `cdylib` WASM binary (`wasm32-wasip1`). The
only Rust source is `src/lib.rs`, which implements two responsibilities:

1. **LSP lifecycle**: Checks if `language-server-bitbake` is installed, fetches
   the latest version from npm, installs/upgrades it via
   `zed::npm_install_package`, then returns a `zed::Command` pointing to
   `node_modules/language-server-bitbake/out/server.js` with `--stdio`.
2. **Extension registration**: Calls
   `zed::register_extension!(BitBakeExtension)`.

## Two Query Layers — Never Confuse Them

There are two sets of Tree-sitter query files and they are intentionally
different:

| Location                    | Purpose                                                   | Format                   |
| --------------------------- | --------------------------------------------------------- | ------------------------ |
| `grammars/bitbake/queries/` | Upstream queries (submodule). Helix/Neovim capture style. | NOT used by Zed directly |
| `languages/bitbake/*.scm`   | Zed-adapted queries. Must use Zed capture names.          | Used by Zed              |

When updating queries from upstream you MUST translate capture names. Key
remappings required by Zed:

- `@include`, `@conditional`, `@repeat`, `@exception`, `@keyword.*` → `@keyword`
- `@field` → `@property`
- `@variable.builtin` → `@variable.special`
- `@function.*`, `@method.*` → `@function`
- `@parameter` → `@variable.parameter`
- `@float` → `@number`
- `@type.qualifier`, `@type.definition`, `@namespace` → `@type`
- Remove `@spell` and `@none` directives (unsupported in Zed)
- Replace `#lua-match?` with `#match?`; translate Lua character classes (`%l` →
  `[a-z]`, `%u` → `[A-Z]`)

## Indentation Queries Are Not Portable

Zed uses `@indent` / `@end` capture names. Upstream uses `@indent.begin` /
`@indent.align` (Helix-style). These are incompatible. The
`languages/bitbake/indents.scm` MUST be hand-written for Zed and MUST NOT be
copied from `grammars/bitbake/queries/indents.scm`.

## Language Configuration Notes

`languages/bitbake/config.toml` deliberately excludes `.conf` files from
`path_suffixes` to avoid collisions with other languages' config files.

## Grammar Updates

To update the grammar to a newer upstream commit:

1. Update the `commit` field in `[grammars.bitbake]` in `extension.toml`.
2. Update the `grammars/bitbake/` submodule to match.
3. Diff `grammars/bitbake/queries/highlights.scm` against the previous version
   and propagate relevant changes to `languages/bitbake/highlights.scm`,
   applying the capture remappings above.
4. Rebuild and test manually with `test/hello.bb`.
