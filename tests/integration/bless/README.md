## txtarbless

`txtarbless` is a helper similar to Rust's `--bless`: it reruns a single
`Testdata/<name>` test, captures the `[stdout]`/`[stderr]` sections, formats them, and rewrites the corresponding `.txtar` so each command is followed by fresh expectations.

### Usage

```bash
# From the repo root
go run ./gno.land/pkg/integration/cmd/txtarbless \
  -test gnoswap_swap_gns_wugnot
```

Options:

| Flag | Description |
| ---- | ----------- |
| `-test` | Testdata name without extension (required). |
| `-integration-dir` | Path to the integration package (defaults to `gno.land/pkg/integration`). |
| `-mask` | Custom mask list forwarded to `testscriptfmt`. |
| `-dry-run` | Print the updated script instead of writing the file. |

- Before running `go test`, the tool strips any existing `stdout`/`stderr`
  assertions from the target `.txtar`. This avoids immediate test failures due
  to stale expectations and ensures that later commands (e.g. getter queries)
  still execute so their outputs can be refreshed.
- Only the relevant success lines are kept: `OK!`, `GAS USED:`, `STORAGE DELTA:`,
  `TOTAL TX COST:`, and `EVENTS:`. Getter invocations such as
  `gnokey query vm/qeval` retain their full output so the script still checks the
  returned value. Everything else is ignored to avoid noisy expectations.
- `[stderr]` blocks are filtered to drop routine progress (e.g. `Enter password.`,
  headings like `## …`, and harness summaries such as `--- PASS`), so only real
  error messages remain.
