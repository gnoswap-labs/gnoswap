#!/usr/bin/env bash
#
# setup-upgrade-test-impl.sh
#
# Populates contract/r/scenario/upgrade/implements/v2_valid/{contract} with
# symbolic links to the production v1 implementation sources, so the upgrade
# scenario tests can register a "v2_valid" implementation that is byte-for-byte
# identical to v1 (only the module path differs).
#
# For each contract:
#   - the destination dir is WIPED and recreated
#   - every non-test *.gno file from the matching v1 dir is symlinked
#     (relative symlinks, so the repo stays relocatable)
#   - _test.gno files and README.md are skipped
#   - a fresh gnomod.toml is generated with module path
#     gno.land/r/gnoswap/{contract}/v2_valid
#
# The symlinked sources keep their original `package v1` declaration; gno
# allows the directory name to differ from the package name, so the module
# at .../v2_valid builds fine as package v1.
#
# Usage (run from anywhere; paths resolve relative to this script):
#   ./scripts/setup-upgrade-test-impl.sh
#
set -euo pipefail

# relpath FROM TO
# Pure-shell relative path from directory $1 to path $2 (both must be absolute).
# Avoids depending on GNU realpath --relative-to (absent on macOS/BSD).
relpath() {
  local from="$1" to="$2" up="" common
  common="${from%/}"
  # Walk up from `from` until it is a prefix of `to`.
  while [[ "${to#"${common}"/}" == "${to}" && "${common}" != "/" ]]; do
    common="$(dirname "${common}")"
    up="../${up}"
  done
  local rest="${to#"${common}"/}"
  printf '%s%s\n' "${up}" "${rest}"
}

# Resolve repo-relative anchors from this script's location:
#   <repo>/scripts/setup-upgrade-test-impl.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The contract/ root is the sibling of scripts/ (one level up, then contract).
CONTRACT_ROOT="$(cd "${SCRIPT_DIR}/../contract" && pwd)"

SRC_BASE="${CONTRACT_ROOT}/r/gnoswap"
DEST_BASE="${CONTRACT_ROOT}/r/scenario/upgrade/implements/v2_valid"

# Contracts to mirror (path relative to r/gnoswap, v1 dir is appended).
CONTRACTS=(
  "pool"
  "position"
  "protocol_fee"
  "router"
  "staker"
  "gov/governance"
  "gov/staker"
  "launchpad"
)

GNO_VERSION="0.9"

for contract in "${CONTRACTS[@]}"; do
  src_dir="${SRC_BASE}/${contract}/v1"
  dest_dir="${DEST_BASE}/${contract}"
  module_path="gno.land/r/gnoswap/${contract}/v2_valid"

  if [[ ! -d "${src_dir}" ]]; then
    echo "ERROR: source dir not found: ${src_dir}" >&2
    exit 1
  fi

  # Wipe and recreate the destination directory.
  rm -rf "${dest_dir}"
  mkdir -p "${dest_dir}"

  # Symlink every non-test .gno source with a relative target.
  linked=0
  for src_file in "${src_dir}"/*.gno; do
    [[ -e "${src_file}" ]] || continue          # guard against no-match glob
    base="$(basename "${src_file}")"
    case "${base}" in
      *_test.gno) continue ;;                    # skip tests
    esac
    # Relative path from dest_dir to the source file.
    rel_target="$(relpath "${dest_dir}" "${src_file}")"
    ln -s "${rel_target}" "${dest_dir}/${base}"
    linked=$((linked + 1))
  done

  # Generate a fresh gnomod.toml with the v2_valid module path.
  cat > "${dest_dir}/gnomod.toml" <<EOF
module = "${module_path}"
gno = "${GNO_VERSION}"
EOF

  echo "v2_valid/${contract}: ${linked} source(s) linked  (module ${module_path})"
done

echo "Done. Generated $(printf '%s\n' "${CONTRACTS[@]}" | wc -l | tr -d ' ') v2_valid contract dir(s) under ${DEST_BASE}"
