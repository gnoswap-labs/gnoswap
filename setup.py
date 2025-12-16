from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import FrozenSet, Iterator, List, NamedTuple, Optional, Tuple

try:
    import tomllib  # Python 3.11+
except ImportError:
    try:
        import tomli as tomllib  # type: ignore[import-not-found]
    except ImportError:
        import toml as tomllib  # type: ignore[import-not-found]


GNOSWAP_REPO_URL = "https://github.com/gnoswap-labs/gnoswap.git"
GNO_LAND_PREFIX = "gno.land/"
GNO_REPO_NAME = os.getenv("GNO_REPO_NAME", "gno")

INTEGRATION_TESTDATA_DIR = Path("tests/integration/testdata")
INTEGRATION_SKIP_FILE = Path("tests/integration/testdata-skip.txt")
INTEGRATION_BLESS_DIR = Path("tests/integration/bless")

CONTRACT_DIR = Path("contract")
SCENARIO_DIR = Path("tests/scenario")


class SetupError(Exception):
    """Base exception for setup errors."""


class ModuleFileError(SetupError):
    """Error reading or parsing module files."""


@dataclass(frozen=True)
class ModuleInfo:
    """Information about a Gno module."""

    module_path: str
    source_dir: Path
    destination_dir: Path


class IntegrationTest(NamedTuple):
    """Integration test file information."""

    source_path: Path
    converted_name: str


@dataclass(frozen=True)
class PathConfig:
    """Configuration for directory paths."""

    workdir: Path
    gno_examples_dir: Path
    gno_root_dir: Path

    @classmethod
    def from_workdir(cls, workdir: Path, gno_repo: str = GNO_REPO_NAME) -> PathConfig:
        """Create PathConfig from a working directory.

        if the gno repository name is different, use `export GNO_REPO_NAME=<repository_name>`
        to set the repository name.

        For example, if the gno repository name is `gno-core`, use
        `export GNO_REPO_NAME=gno-core python setup.py` to run the script.

        Args:
            workdir: Working directory path.
            gno_repo: Name of gno repository directory (default: "gno").
        """
        return cls(
            workdir=workdir,
            gno_examples_dir=workdir / gno_repo / "examples" / "gno.land",
            gno_root_dir=workdir / gno_repo / "gno.land",
        )


def convert_txtar_name(file_path: Path, base_dir: Path) -> str:
    rel_path = file_path.relative_to(base_dir)
    name_without_ext = file_path.stem

    if rel_path.parent != Path("."):
        prefix = str(rel_path.parent).replace(os.sep, "_") + "_"
        return prefix + name_without_ext
    return name_without_ext


def build_module_destination(
    module_path: str, gno_examples_dir: Path
) -> Optional[Path]:
    """Calculate destination directory for a module

    Args:
        module_path: Full module path (e.g., "gno.land/p/demo/example").
        gno_examples_dir: Base directory for gno.land examples.

    Returns:
        Destination path if valid gno.land module, None otherwise.
    """
    if not module_path.startswith(GNO_LAND_PREFIX):
        return None

    relative_path = module_path.replace(GNO_LAND_PREFIX, "", 1)
    return gno_examples_dir / relative_path


###### IO / File Operation functions


def read_module_path(file_path: Path) -> Optional[str]:
    """Read and parse module path from toml file"""
    if not file_path.exists():
        raise ModuleFileError(f"File not found: {file_path}")

    try:
        content = file_path.read_bytes()
        data = tomllib.loads(content.decode("utf-8"))
        return data.get("module")

    except (IOError, tomllib.TOMLDecodeError, KeyError) as e:
        raise ModuleFileError(f"Error reading TOML file {file_path}: {e}")


def load_skip_tests(skip_file: Path = INTEGRATION_SKIP_FILE) -> FrozenSet[str]:
    """Load skip list from file"""
    if not skip_file.exists():
        return frozenset()

    skip_tests: set = set()
    for line in skip_file.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            skip_tests.add(line)

    return frozenset(skip_tests)


def remove_path(path: Path) -> None:
    """Remove a file, symlink, or directory"""
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def ensure_clean_directory(path: Path) -> None:
    """Ensure directory exists and is empty"""
    remove_path(path)
    path.mkdir(parents=True, exist_ok=True)


def create_symlink(src: Path, dest: Path) -> None:
    """Create a symlink, removing existing file if present"""
    if dest.exists() or dest.is_symlink():
        dest.unlink()
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.symlink_to(src.resolve())


#### Module discovery


def find_module_file(dir: Path) -> Optional[Path]:
    """Find `gnomod.toml` file in directory"""
    toml_file = dir / "gnomod.toml"
    if toml_file.exists():
        return toml_file
    return None


def discover_modules(
    root_dir: Path,
    config: PathConfig,
) -> Iterator[ModuleInfo]:
    """Discover all modules in a directory tree"""
    for dirpath in root_dir.rglob("*"):
        if not dirpath.is_dir():
            continue

        module_file = find_module_file(dirpath)
        if module_file is None:
            continue

        module_path = read_module_path(module_file)
        if module_path is None:
            continue

        destination = build_module_destination(module_path, config.gno_examples_dir)
        if destination is None:
            continue

        yield ModuleInfo(
            module_path=module_path,
            source_dir=dirpath,
            destination_dir=destination,
        )


### Integration Tests Handler


def discover_integration_tests(
    testdata_dir: Path = INTEGRATION_TESTDATA_DIR,
) -> Iterator[IntegrationTest]:
    """Discover all integration test files."""
    if not testdata_dir.exists():
        return

    for txtar_file in testdata_dir.rglob("*.txtar"):
        yield IntegrationTest(
            source_path=txtar_file.resolve(),
            converted_name=convert_txtar_name(txtar_file, testdata_dir),
        )


def get_integration_tests(
    skip: bool = False,
    testdata_dir: Path = INTEGRATION_TESTDATA_DIR,
    skip_file: Path = INTEGRATION_SKIP_FILE,
) -> List[IntegrationTest]:
    """Get integration tests, optionally excluding those in skip list.

    Args:
        skip: If True, exclude tests listed in skip file.
        testdata_dir: Directory containing test files.
        skip_file: Path to skip list file.

    Returns:
        List of IntegrationTest objects.
    """
    tests = list(discover_integration_tests(testdata_dir))

    if not skip:
        return tests

    skip_tests = load_skip_tests(skip_file)
    return [test for test in tests if test.converted_name not in skip_tests]


### Module Linking


def link_module(module_info: ModuleInfo, exclude_tests: bool = False) -> None:
    """Link a module's files to destination directory."""
    print(
        f"Linking module from {module_info.source_dir} to {module_info.destination_dir}"
    )

    ensure_clean_directory(module_info.destination_dir)

    for source_file in module_info.source_dir.rglob("*"):
        if not source_file.is_file():
            continue

        if exclude_tests and source_file.name.endswith("test.gno"):
            continue

        relative = source_file.relative_to(module_info.source_dir)
        destination = module_info.destination_dir / relative
        create_symlink(source_file, destination)


def link_integration_tests(config: PathConfig, skip: bool = False) -> None:
    """Link integration test files to gno integration directory."""
    dest_testdata = config.gno_root_dir / "pkg" / "integration" / "testdata"

    tests = get_integration_tests(skip=skip)
    if not tests:
        return

    ensure_clean_directory(dest_testdata)
    print(
        f"Linking integration tests from {INTEGRATION_TESTDATA_DIR} to {dest_testdata}"
    )

    for test in tests:
        dest_file = dest_testdata / f"{test.converted_name}.txtar"
        create_symlink(test.source_path, dest_file)
        print(f"  Linked: {test.source_path.name} -> {test.converted_name}.txtar")


def link_bless_directory(config: PathConfig) -> None:
    """Link bless directory for integration tests."""
    if not INTEGRATION_BLESS_DIR.exists():
        return

    dest_bless = config.gno_root_dir / "pkg" / "integration" / "bless"
    ensure_clean_directory(dest_bless)
    print(f"Linking bless directory from {INTEGRATION_BLESS_DIR} to {dest_bless}")

    for source_file in INTEGRATION_BLESS_DIR.iterdir():
        if source_file.is_file():
            dest_file = dest_bless / source_file.name
            create_symlink(source_file.resolve(), dest_file)
            print(f"  Linked: {source_file.name}")


### Main Operations


def clone_repository(workdir: Path) -> None:
    """Clone the GnoSwap repository.

    Args:
        workdir: Working directory for clone.
    """
    os.chdir(workdir)
    subprocess.run(["git", "clone", GNOSWAP_REPO_URL], check=True)
    os.chdir("gnoswap")


def setup_contracts(config: PathConfig, exclude_tests: bool = False) -> None:
    """Set up all contracts by linking modules.

    Args:
        config: Path configuration.
        exclude_tests: If True, exclude test files.
    """
    search_dirs = [CONTRACT_DIR, SCENARIO_DIR]

    for search_dir in search_dirs:
        if not search_dir.exists():
            continue

        for module_info in discover_modules(search_dir, config):
            link_module(module_info, exclude_tests=exclude_tests)


def copy_integration_tests(config: PathConfig, skip: bool = False) -> None:
    """Copy all integration test resources.

    Args:
        config: Path configuration.
        skip: If True, exclude tests in skip list.
    """
    link_integration_tests(config, skip=skip)
    link_bless_directory(config)


def list_integration_tests(skip: bool = False) -> None:
    """Print all integration tests with their converted names.

    Args:
        skip: If True, exclude tests in skip list.
    """
    tests = get_integration_tests(skip=skip)

    if not tests:
        raise SetupError("No integration tests found")

    for test in sorted(tests, key=lambda t: t.converted_name):
        print(test.converted_name)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    """Parse command line arguments.

    Args:
        argv: Command line arguments (defaults to sys.argv).

    Returns:
        Parsed arguments namespace.
    """
    parser = argparse.ArgumentParser(
        description="Set up GnoSwap contracts",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "-w",
        "--workdir",
        type=Path,
        default=Path.home(),
        help="Path to your work directory (default: home directory)",
    )
    parser.add_argument(
        "-c",
        "--clone",
        action="store_true",
        help="Clone the GnoSwap repository before setup",
    )
    parser.add_argument(
        "--exclude-tests",
        action="store_true",
        help="Exclude *test.gno files from linking",
    )
    parser.add_argument(
        "--list-tests",
        action="store_true",
        help="List all integration tests with converted names and exit",
    )
    parser.add_argument(
        "--skip",
        action="store_true",
        help="Exclude tests listed in testdata-skip.txt",
    )

    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    """Main entry point for the script.

    Args:
        argv: Command line arguments.

    Returns:
        Exit code (0 for success).
    """
    args = parse_args(argv)

    if args.list_tests:
        list_integration_tests(skip=args.skip)
        return 0

    if args.clone:
        clone_repository(args.workdir)

    config = PathConfig.from_workdir(args.workdir)

    setup_contracts(config, exclude_tests=args.exclude_tests)
    copy_integration_tests(config, skip=args.skip)

    print("Setup completed successfully!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
