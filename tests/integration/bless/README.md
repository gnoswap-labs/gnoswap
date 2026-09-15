## txtar-bless

`txtar-bless` refreshes the expectations in one Gno integration `.txtar`
test. It runs the selected `Testdata/<name>` subtest in the Gno integration
package, parses the command output, and writes new `stdout`/`stderr`
expectations after each command.

## Prerequisites and test names

The integration runner lives in a Gno checkout, not in this repository. From
the GnoSwap repository root, set up a Gno checkout under the selected work
directory first:

```bash
# `tmp/gno` must be an existing Gno checkout.
python3 setup.py -w tmp

# Names are printed without the .txtar suffix. Nested directories are flattened
# (for example, testdata/pool/create_pool_and_mint.txtar becomes
# pool_create_pool_and_mint.txtar in the Gno integration directory).
python3 setup.py --list-tests
```

`setup.py -w <workdir>` links this repository's contract modules into
`<workdir>/gno/examples/gno.land` and the integration test resources into
`<workdir>/gno/gno.land/pkg/integration`. If the Gno checkout is elsewhere,
replace `tmp` with its parent work-directory path.

## Blessing a test

Run the tool from the GnoSwap repository root and pass the actual integration
package directory explicitly:

```bash
go run ./tests/integration/bless \
  -test pool_create_pool_and_mint \
  -integration-dir "$PWD/tmp/gno/gno.land/pkg/integration"
```

The tool invokes the equivalent of `go test -v . -run Testdata/<name>` with its
working directory set to `-integration-dir`. The selected file is therefore
resolved as `<integration-dir>/testdata/<name>.txtar`.

When `setup.py` has linked the test files, those files are symlinks back to
this repository's `tests/integration/testdata/` tree. The tool resolves the
symlink before writing, so normal blessing updates the source `.txtar` in this
repository rather than only changing the Gno checkout. Review the resulting
diff before committing it.

## Command-line options

| Flag | Description |
| ---- | ----------- |
| `-test NAME` | Required test name without the `.txtar` extension. Use `python3 setup.py --list-tests` to find converted names. |
| `-integration-dir PATH` | Integration package directory containing `testdata/`; defaults to `gno.land/pkg/integration` relative to the process's current directory. |
| `-mask SPEC` | Replaces the default field-mask list. Use comma-separated one- or two-segment fields, optionally with a replacement regex (`key`, `parent.child`, or `key=regex`). The default is `timestamp,bytes_delta,fee_delta.amount,currentTime,currentHeight,observationTimestamp`. Addresses and numeric values on recognized metric lines are masked independently of this list. |
| `-dry-run` | Print the refreshed script to stdout instead of leaving the source file updated. Existing expectations are sanitized temporarily and restored before the command exits. |
| `-report` | Generate a gas measurement report instead of rewriting the `.txtar`; markdown is printed to stdout unless `-output` is supplied. |
| `-output PATH` | Write a report to `PATH` (report mode only). |
| `-tsv` | Format a report as TSV (report mode only). Without `-output`, the tool writes `<test>.tsv` in the current working directory. |

The tool keeps these stdout lines when blessing:

- `OK!`;
- all output from `gnokey query vm/qeval` commands; and
- lines beginning with `GAS USED:`, `STORAGE DELTA:`, `STORAGE FEE:`,
  `TOTAL TX COST:`, or `EVENTS:`.

It drops the `Enter password.` prompt and routine test-harness stderr lines
beginning with `#`, `--- `, `===`, `PASS`, `FAIL`, `ok `, or `?`; other stderr
is retained. Generated expectations escape text and apply the configured
masks, including the built-in address and metric masking.

In normal blessing mode, existing expectation lines beginning with `stdout`
or `stderr` are removed from the resolved script before fresh output is
inserted. If the test fails, the tool warns but continues with captured output;
review the file and command status rather than treating a generated file as a
passing test. `-dry-run` is the non-writing preview mode.

## Installing the tool and gas reports

The root Makefile can build the tool into `$(go env GOPATH)/bin`:

```bash
make bless-install
"$(go env GOPATH)/bin/txtar-bless" \
  -test pool_create_pool_and_mint \
  -integration-dir "$PWD/tmp/gno/gno.land/pkg/integration"
```

The root Makefile's report wrappers use the same binary and default the
integration directory to `$HOME/gno/gno.land/pkg/integration` (override it when
using `tmp`):

```bash
make gas-report \
  TEST=base_uint256_gas_measurement \
  GNO_INTEGRATION_DIR="$PWD/tmp/gno/gno.land/pkg/integration"

make gas-report-tsv \
  TEST=base_uint256_gas_measurement \
  GNO_INTEGRATION_DIR="$PWD/tmp/gno/gno.land/pkg/integration"
```

`gas-report` prints markdown. `gas-report-tsv` writes a file named
`<test>_<short-commit>.tsv` in the repository root. Both wrappers require
`make bless-install` first and run the selected integration test; they do not
refresh the `.txtar` expectations.
