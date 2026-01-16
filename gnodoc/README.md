# GnoDoc

GnoDoc is a local documentation generator for Go and Gno packages that reads source code directly and emits Markdown. Unlike `gno doc`, it does not require deployment on-chain, so it can document packages before release. The goal is to provide pkg.go.dev-like structure and readability while staying lightweight and deterministic.

When you run GnoDoc, it resolves the input package path in a predictable order. A directory path is used as-is, a module-relative path is resolved against a module root, and a Go import path is resolved via `go list` when needed. The module root is detected by walking upward from the package directory until a `gnomod.toml` is found; if `--module-root` is provided, that directory is used instead. The `module` field in `gnomod.toml` is used to build the final import path shown in the rendered Markdown.

File discovery is intentionally simple. GnoDoc looks for `.go` and `.gno` files and optionally includes test files when `--include-tests` is set. File exclusion uses filename glob patterns, and parsing continues in best-effort mode when `--ignore-parse-errors` is enabled. The AST is built with comment parsing enabled and normalized into a DocPackage model that preserves symbol relationships (types, methods, functions, constants, variables), source locations, and structured tags such as Examples and Deprecated blocks.

Markdown rendering follows a consistent section order: Overview, Index, Constants, Variables, Functions, Types, Examples, and Notes. The Index contains exported symbols and stable anchors, while constants and variables are grouped using their original declaration style. Function sections show signatures, description text, and a Returns block that summarizes named return values and concrete return expressions extracted from the function body. Types include fields, methods, and constructors, and examples are emitted as fenced code blocks with output where available. Source links are optionally rendered from file and line information using `--source-link-base`.

## CLI Flags

### Output
| Flag | Default | Description |
| --- | --- | --- |
| `--out=DIR` | current directory | Output directory for generated Markdown. |
| `--output-file=NAME` | `README.md` | Output filename for the default command. |
| `--filename=NAME` | `README.md` | Output filename for `export`. |
| `--format=md` | `md` | Output format for `export` (Markdown only). |

### Parsing and Filtering
| Flag | Default | Description |
| --- | --- | --- |
| `--include-tests` | false | Include `_test.go` / `_test.gno` files. |
| `--ignore-parse-errors` | false | Continue parsing if some files fail. |
| `--exclude=PATTERN` | (none) | Exclude files by filename glob (comma-separated). |
| `--exported-only` | true | Only render exported symbols. |
| `--all` | false | Include unexported symbols. |

### Paths and Links
| Flag | Default | Description |
| --- | --- | --- |
| `--module-root=DIR` | (auto) | Override module root detection. |
| `--source-link-base=URL` | (none) | Base URL for source links. |

## Usage Examples

Generate documentation for a local package directory:
```bash
gnodoc /path/to/package
```

Generate documentation using module-relative path:
```bash
gnodoc --module-root /path/to/module contract/p/gnoswap/int256
```

Export Markdown to a custom file and directory:
```bash
gnodoc export --out docs --filename governance.md contract/r/gnoswap/gov/governance
```

Include tests and tolerate parse errors:
```bash
gnodoc --include-tests --ignore-parse-errors /path/to/package
```

List packages under a directory:
```bash
gnodoc list /path/to/module
```

## Markdown Output Example (Simplified)
~~~plain
# pkgname

`import "module/path/pkgname"`

Package overview text.

## Index
- [TypeA](#typea)
- [FuncX](#funcx)

## Constants
```go
const (
	MAX = 1
)
```

## Functions
### FuncX
```go
func FuncX(arg int) (result int, err error)
```
Description...

#### Returns
- named: result, err
- return: result, nil

## Types
### TypeA
```go
type TypeA struct
```
Description...

#### Methods
##### MethodY
```go
func (t *TypeA) MethodY() error
```

#### Returns
- return: nil
~~~

## Supported Features
GnoDoc currently supports Go and Gno parsing, module detection via `gnomod.toml`, export filtering, stable anchors, example extraction from test files, source links, and return expression tracking.

## Current Limitations
GnoDoc does not render HTML, does not evaluate build tags or platform-specific files, and only supports filename-based exclude patterns. Return analysis is intentionally shallow and does not perform full control-flow or dataflow analysis. Example code formatting is best-effort and may preserve indentation from the source.
