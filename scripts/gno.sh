#!/usr/bin/env bash
# Builds a gno toolchain outside the repo and runs tests straight from contract/,
# which is a gnowork.toml workspace. Package tests link nothing into the gno checkout.
#
#   scripts/gno.sh setup                       clone/update GNO_REPO at GNO_REF and build gno + gnokey
#   scripts/gno.sh test [PKG] [flags]          PKG is a module path or a path under contract/ (default: all)
#   scripts/gno.sh integration-list [--skip]   txtar names, --skip drops tests/integration/testdata-skip.txt
#   scripts/gno.sh integration-link            link contracts and txtars into the toolchain checkout
#   scripts/gno.sh integration TEST | --all [--skip]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GNO_REPO="${GNO_REPO:-https://github.com/gnoswap-labs/gno}"
GNO_REF="${GNO_REF:-master}"
GNO_TOOLCHAIN="${GNO_TOOLCHAIN:-$HOME/.cache/gno-toolchains/gnoswap-$GNO_REF}"
export GNOROOT="$GNO_TOOLCHAIN/src"
export GNOHOME="$GNO_TOOLCHAIN/gnohome"
export PATH="$GNO_TOOLCHAIN/bin:$PATH"

setup() {
	if [ -d "$GNOROOT/.git" ]; then
		git -C "$GNOROOT" fetch -q --depth 1 origin "$GNO_REF"
		# reset and clean also drop what integration-link left behind
		git -C "$GNOROOT" reset -q --hard FETCH_HEAD
		git -C "$GNOROOT" clean -fdq -- examples gno.land/pkg/integration/testdata
	else
		git clone -q --depth 1 --branch "$GNO_REF" "$GNO_REPO" "$GNOROOT"
	fi
	echo "gno source: $(git -C "$GNOROOT" log --oneline -1)"
	(cd "$GNOROOT" && GOBIN="$GNO_TOOLCHAIN/bin" go install ./gnovm/cmd/gno ./gno.land/cmd/gnokey)

	# test deps come from this checkout's examples, not from rpc.gno.land
	local mod="$GNOHOME/pkg/mod"
	mkdir -p "$mod"
	rm -rf "$mod/gno.land" "$mod/.markers"
	cp -R "$GNOROOT/examples/gno.land" "$mod/"
	# gno re-downloads any package without a .markers/<pkg address> file, so mark every copied package
	cat >"$GNO_TOOLCHAIN/markers.go" <<'EOF'
package main

import (
	"io/fs"
	"os"
	"path/filepath"

	"github.com/gnolang/gno/gnovm/pkg/gnolang"
)

func main() {
	mod := os.Args[1]
	os.MkdirAll(filepath.Join(mod, ".markers"), 0o755)
	filepath.WalkDir(filepath.Join(mod, "gno.land"), func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.Name() != "gnomod.toml" {
			return err
		}
		pkg, _ := filepath.Rel(mod, filepath.Dir(p))
		addr := gnolang.DerivePkgBech32Addr(filepath.ToSlash(pkg)).String()
		return os.WriteFile(filepath.Join(mod, ".markers", addr), nil, 0o644)
	})
}
EOF
	(cd "$GNOROOT" && go run "$GNO_TOOLCHAIN/markers.go" "$mod")
	echo "toolchain ready: $GNO_TOOLCHAIN"
}

run_test() {
	[ -x "$GNO_TOOLCHAIN/bin/gno" ] || { echo "gno toolchain missing, run setup first" >&2; exit 1; }
	local pkg="${1:-./...}"
	[ $# -gt 0 ] && shift
	if [[ "$pkg" == gno.land/* ]]; then
		# module paths do not always match directories (e.g. r/scenario -> gno.land/r/gnoswap/scenario)
		local mod
		mod="$(grep -rlx --include=gnomod.toml "module = \"$pkg\"" "$ROOT/contract" | head -1 || true)"
		[ -n "$mod" ] || { echo "module $pkg not found under contract/" >&2; exit 1; }
		pkg="./${mod#"$ROOT/contract/"}"
		pkg="${pkg%/gnomod.toml}"
	fi
	cd "$ROOT/contract"
	gno test "$pkg" "$@"
}

integration_list() {
	local skip=""
	[ "${1:-}" = "--skip" ] && skip="$ROOT/tests/integration/testdata-skip.txt"
	(cd "$ROOT/tests/integration/testdata" && find . -name '*.txtar') |
		sed -e 's|^\./||' -e 's|\.txtar$||' -e 's|/|_|g' | sort |
		if [ -n "$skip" ]; then grep -vxF -f <(grep -v '^#' "$skip" | grep .); else cat; fi
}

# The integration node loads packages from GNOROOT/examples and txtars from its own testdata,
# so these still have to be linked into the toolchain checkout. Test files are left out.
integration_link() {
	[ -d "$GNOROOT/.git" ] || { echo "gno toolchain missing, run setup first" >&2; exit 1; }
	git -C "$GNOROOT" clean -fdq -- examples
	local mod dir dest
	while IFS= read -r mod; do
		dir="$(dirname "$mod")"
		dest="$GNOROOT/examples/$(sed -n 's|^module = "\(gno\.land/.*\)"$|\1|p' "$mod")"
		[ "$dest" != "$GNOROOT/examples/" ] || continue
		mkdir -p "$dest"
		find "$dir" -maxdepth 1 -type f ! -name '*test.gno' -exec ln -s {} "$dest/" \;
	done < <(find "$ROOT/contract" -name gnomod.toml)

	local testdata="$GNOROOT/gno.land/pkg/integration/testdata" src
	rm -rf "$testdata" && mkdir -p "$testdata"
	(cd "$ROOT/tests/integration/testdata" && find . -name '*.txtar') | sed 's|^\./||' | while IFS= read -r src; do
		ln -s "$ROOT/tests/integration/testdata/$src" "$testdata/$(echo "${src%.txtar}" | tr / _).txtar"
	done
	echo "linked contracts and txtars into $GNOROOT"
}

run_integration() {
	[ $# -gt 0 ] || { echo "usage: $0 integration TEST | --all [--skip]" >&2; exit 1; }
	integration_link
	cd "$GNOROOT/gno.land/pkg/integration"
	if [ "$1" != "--all" ]; then
		go test -v . -run "TestTestdata/^$1\$"
		return
	fi
	local t failed=()
	while IFS= read -r t; do
		echo "=== integration: $t"
		go test -v . -run "TestTestdata/^$t\$" || failed+=("$t")
	done < <(integration_list "${2:-}")
	[ ${#failed[@]} -eq 0 ] || { printf 'FAILED: %s\n' "${failed[@]}" >&2; exit 1; }
}

case "${1:-}" in
setup) setup ;;
test) shift && run_test "$@" ;;
integration-list) shift && integration_list "$@" ;;
integration-link) integration_link ;;
integration) shift && run_integration "$@" ;;
*)
	echo "usage: $0 setup | test [PKG] [flags] | integration-list [--skip] | integration-link | integration TEST|--all [--skip]" >&2
	exit 1
	;;
esac
