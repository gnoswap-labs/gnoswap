## txtar-bless

`txtar-bless` refreshes the expectations in one Gno integration `.txtar`
test. It runs the selected `Testdata/<name>` subtest in the Gno integration
package, parses the command output, and writes new `stdout`/`stderr`
expectations after each command.

## Prerequisites and test names

The integration runner lives in the Gno toolchain checkout, not in this
repository. From the GnoSwap repository root, build the toolchain and link this
repository's contracts and txtars into it first:

```bash
make gno-setup           # once; builds ~/.cache/gno-toolchains/gnoswap-master
make integration-link    # re-run after adding, moving, or removing files

# Names are printed without the .txtar suffix. Nested directories are flattened
# (for example, testdata/pool/create_pool_and_mint.txtar becomes
# pool_create_pool_and_mint.txtar in the Gno integration directory).
make integration-test-list
```

`integration-link` links every `contract/` module (without test files) into
`<toolchain>/src/examples/gno.land` and the txtars into
`<toolchain>/src/gno.land/pkg/integration/testdata`.

## Blessing a test

Run the tool from the GnoSwap repository root and pass the actual integration
package directory explicitly:

```bash
go run ./tests/integration/bless \
  -test pool_create_pool_and_mint \
  -integration-dir ~/.cache/gno-toolchains/gnoswap-master/src/gno.land/pkg/integration
```

The tool invokes the equivalent of `go test -v . -run Testdata/<name>` with its
working directory set to `-integration-dir`. The selected file is therefore
resolved as `<integration-dir>/testdata/<name>.txtar`.

When `integration-link` has linked the test files, those files are symlinks back to
this repository's `tests/integration/testdata/` tree. The tool resolves the
symlink before writing, so normal blessing updates the source `.txtar` in this
repository rather than only changing the Gno checkout. Review the resulting
diff before committing it.

## Command-line options

| Flag | Description |
| ---- | ----------- |
| `-test NAME` | Required test name without the `.txtar` extension. Use `make integration-test-list` to find converted names. |
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
  -integration-dir ~/.cache/gno-toolchains/gnoswap-master/src/gno.land/pkg/integration
```

The root Makefile's report wrappers use the same binary, run
`integration-link` first, and default the integration directory to the toolchain
checkout (`GNO_INTEGRATION_DIR` overrides it):

```bash
make gas-report TEST=base_uint256_gas_measurement
make gas-report-tsv TEST=base_uint256_gas_measurement
```

`gas-report` prints markdown. `gas-report-tsv` writes a file named
`<test>_<short-commit>.tsv` in the repository root. Both wrappers require
`make bless-install` first and run the selected integration test; they do not
refresh the `.txtar` expectations.
