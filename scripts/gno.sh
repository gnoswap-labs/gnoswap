#!/usr/bin/env bash
# Builds a gno toolchain outside the repo and runs tests straight from contract/,
# which is a gnowork.toml workspace. No files are linked into a gno checkout.
#
#   scripts/gno.sh setup                 clone/update GNO_REPO at GNO_REF and build gno + gnokey
#   scripts/gno.sh test [PKG] [flags]    PKG is a module path or a path under contract/ (default: all)
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
		git -C "$GNOROOT" checkout -q --detach FETCH_HEAD
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

case "${1:-}" in
setup) setup ;;
test) shift && run_test "$@" ;;
*)
	echo "usage: $0 setup | test [PKG] [gno test flags]" >&2
	exit 1
	;;
esac
