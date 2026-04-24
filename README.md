# Zed BitBake

A [BitBake](https://docs.yoctoproject.org/bitbake/) extension for
[Zed](https://zed.dev), providing language support for Yocto/OpenEmbedded
recipes and configuration files.

## Features

- Syntax highlighting for `.bb`, `.bbappend`, `.bbclass`, and `.inc` files
- Code outline and symbol navigation
- Indentation support
- LSP-powered completions, diagnostics, hover, and go-to-definition via
  [`language-server-bitbake`](https://www.npmjs.com/package/language-server-bitbake)

The language server is installed automatically using Zed's bundled Node.js — no
external Node.js installation required.

## Configuration

### File associations for `.conf` files

`.conf` files are intentionally excluded from automatic detection to avoid
conflicts with other languages. In Yocto projects you can opt in by adding file
associations to your Zed settings:

```json
{
  "file_types": {
    "BitBake": [
      "**/conf/*.conf",
      "**/conf/distro/*.conf",
      "**/conf/machine/*.conf"
    ]
  }
}
```

This enables BitBake language support for layer configuration, machine
definitions, and distro configuration files.

### LSP settings

The language server reads settings from the `bitbake` namespace. These can be
set in your Zed project settings under `lsp.bitbake-language-server.settings`:

```json
{
  "lsp": {
    "bitbake-language-server": {
      "settings": {
        "bitbake": {
          "pathToBitbakeFolder": "${workspaceFolder}/sources/poky/bitbake",
          "pathToBuildFolder": "${workspaceFolder}/build",
          "pathToEnvScript": "${workspaceFolder}/sources/poky/oe-init-build-env",
          "workingDirectory": "${workspaceFolder}"
        }
      }
    }
  }
}
```

Key settings:

| Setting                       | Default                | Description                                                                    |
| ----------------------------- | ---------------------- | ------------------------------------------------------------------------------ |
| `bitbake.pathToBitbakeFolder` | `sources/poky/bitbake` | Path to the BitBake installation. Required for Python-based language features. |
| `bitbake.pathToEnvScript`     | —                      | Environment initialization script (e.g. `oe-init-build-env`).                  |
| `bitbake.pathToBuildFolder`   | —                      | Build directory.                                                               |
| `bitbake.workingDirectory`    | `${workspaceFolder}`   | Working directory for BitBake commands.                                        |
| `bitbake.commandWrapper`      | —                      | Command prefix for BitBake invocations (e.g. a container wrapper).             |
| `bitbake.shellEnv`            | `{}`                   | Extra environment variables passed to BitBake.                                 |

For the full list of settings, see the
[upstream extension documentation](https://github.com/yoctoproject/vscode-bitbake).

## Development

To build and test the extension locally:

```bash
# Install the required compilation target (once)
rustup target add wasm32-wasip1

# Build the extension
cargo build --release --target wasm32-wasip1
```

Then in Zed: **Extensions → Install Dev Extension** and select this directory.

Open `test/hello.bb` to verify syntax highlighting, outline, indentation, and
LSP features work.

For more details, see the
[Developing Extensions](https://zed.dev/docs/extensions/developing-extensions)
section of the Zed docs.
