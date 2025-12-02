import os
import sys
import shutil
import argparse
import subprocess
from pathlib import Path
from typing import Optional, Tuple
from dataclasses import dataclass

try:
    import tomllib  # Python 3.11+
except ImportError:
    try:
        import tomli as tomllib  # fallback for older Python versions
    except ImportError:
        import toml as tomllib  # alternative fallback


@dataclass
class ModuleInfo:
    """Information about a Gno module."""

    module_path: str
    source_dir: str
    destination_dir: str


class GnoModuleManager:
    """Manages Gno modules and their paths."""

    def __init__(self, workdir: str):
        self.workdir = workdir
        self.gno_dir = os.path.join(workdir, "gno", "examples", "gno.land")
        self.gno_root_dir = os.path.join(workdir, "gno", "gno.land")

    def extract_module_path_from_gnomod(self, file_path: str) -> Optional[str]:
        """Extract module path from gno.mod file (legacy format)."""
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
                import re

                match = re.search(r"module\s+([\w./]+)", content)
                return match.group(1) if match else None
        except (IOError, UnicodeDecodeError):
            print(f"Error reading file: {file_path}")
            return None

    def extract_module_path_from_toml(self, file_path: str) -> Optional[str]:
        """Extract module path from gnomod.toml file."""
        try:
            with open(file_path, "rb") as f:
                data = tomllib.load(f)
                return data.get("module")
        except (IOError, tomllib.TOMLDecodeError, KeyError) as e:
            print(f"Error reading TOML file {file_path}: {e}")
            return None

    def extract_module_path(self, file_path: str) -> Optional[str]:
        """Extract module path from either gno.mod or gnomod.toml file."""
        if file_path.endswith("gnomod.toml"):
            return self.extract_module_path_from_toml(file_path)
        else:  # gno.mod
            return self.extract_module_path_from_gnomod(file_path)

    def find_parent_module(self, directory: str) -> Tuple[Optional[str], Optional[str]]:
        """Find the nearest parent module path and directory."""
        current = directory
        while current != os.path.dirname(current):
            # Check for new TOML format first
            toml_file = os.path.join(current, "gnomod.toml")
            if os.path.exists(toml_file):
                return self.extract_module_path(toml_file), current

            # Fallback to legacy gno.mod format
            mod_file = os.path.join(current, "gno.mod")
            if os.path.exists(mod_file):
                return self.extract_module_path(mod_file), current

            current = os.path.dirname(current)
        return None, None

    def get_module_info(self, src_dir: str, module_path: str) -> Optional[ModuleInfo]:
        """Create ModuleInfo from source directory and module path."""
        if not module_path or not module_path.startswith("gno.land/"):
            return None

        relative_path = module_path.replace("gno.land/", "", 1)
        dest_dir = os.path.join(self.gno_dir, relative_path)
        return ModuleInfo(module_path, src_dir, dest_dir)


class ContractCopier:
    """Handles linking of contract files and tests."""

    def __init__(self, module_manager: GnoModuleManager, exclude_tests: bool = False):
        self.module_manager = module_manager
        self.exclude_tests = exclude_tests

    def copy_module(self, module_info: ModuleInfo, with_metrics: bool = False) -> None:
        is_metric_module = module_info.destination_dir.endswith("/metric")
        
        if with_metrics and not is_metric_module:
            return
        elif not with_metrics and is_metric_module:
            if os.path.islink(module_info.destination_dir) or os.path.isfile(
                module_info.destination_dir
            ):
                os.unlink(module_info.destination_dir)
            elif os.path.isdir(module_info.destination_dir):
                shutil.rmtree(module_info.destination_dir)
            return
        
        print(
            f"Linking module from {module_info.source_dir} to {module_info.destination_dir}"
        )

        if os.path.islink(module_info.destination_dir) or os.path.isfile(
            module_info.destination_dir
        ):
            os.unlink(module_info.destination_dir)
        elif os.path.isdir(module_info.destination_dir):
            shutil.rmtree(module_info.destination_dir)

        os.makedirs(module_info.destination_dir, exist_ok=True)

        for root, _, files in os.walk(module_info.source_dir):
            rel_path = os.path.relpath(root, module_info.source_dir)
            dest_root = os.path.join(module_info.destination_dir, rel_path)
            os.makedirs(dest_root, exist_ok=True)
            for file in files:
                # Skip test files if exclude_tests option is enabled
                if self.exclude_tests and file.endswith("test.gno"):
                    continue
                
                src_file = os.path.abspath(os.path.join(root, file))
                dest_file = os.path.join(dest_root, file)
                if os.path.exists(dest_file) or os.path.islink(dest_file):
                    os.unlink(dest_file)
                os.symlink(src_file, dest_file)

    def copy_tests(self, src_test_dir: str, dest_dir: str) -> None:
        """Symlink test files into the destination directory."""
        print(f"Linking tests from {src_test_dir} to {dest_dir}")
        if not os.path.exists(src_test_dir):
            return
        if os.path.islink(dest_dir) or os.path.isfile(dest_dir):
            os.unlink(dest_dir)
        elif os.path.isdir(dest_dir):
            shutil.rmtree(dest_dir)
        os.makedirs(dest_dir, exist_ok=True)

        for test_file in os.listdir(src_test_dir):
            src_file = os.path.join(src_test_dir, test_file)
            dest_file = os.path.join(dest_dir, test_file)
            if os.path.isfile(src_file):
                if os.path.islink(dest_file) or os.path.isfile(dest_file):
                    os.unlink(dest_file)
                elif os.path.isdir(dest_file):
                    shutil.rmtree(dest_file)

                os.makedirs(os.path.dirname(dest_file), exist_ok=True)
                os.symlink(src_file, dest_file)

    def process_directory(self, root: str, dirs: list, files: list, with_metrics: bool = False) -> None:
        """Process a directory for modules and tests."""
        module_file = None
        if "gnomod.toml" in files:
            module_file = os.path.join(root, "gnomod.toml")
        elif "gno.mod" in files:
            raise ValueError(
                "gno.mod format is outdated. Please use gnomod.toml instead."
            )

        if module_file:
            module_path = self.module_manager.extract_module_path(module_file)
            if module_info := self.module_manager.get_module_info(root, module_path):
                self.copy_module(module_info, with_metrics=with_metrics)


def clone_repository(workdir: str) -> None:
    """Clone the GnoSwap repository."""
    os.chdir(workdir)
    subprocess.run(
        ["git", "clone", "https://github.com/gnoswap-labs/gnoswap.git"], check=True
    )
    os.chdir("gnoswap")


def setup_contracts(workdir: str, exclude_tests: bool = False, with_metrics: bool = False) -> None:
    """Set up all contracts and tests."""
    module_manager = GnoModuleManager(workdir)
    copier = ContractCopier(module_manager, exclude_tests=exclude_tests)

    for root, dirs, files in os.walk("contract"):
        copier.process_directory(root, dirs, files, with_metrics=with_metrics)

    for root, dirs, files in os.walk("tests/scenario"):
        copier.process_directory(root, dirs, files, with_metrics=with_metrics)


_INTEGRATION_TESTDATA_DIR = "tests/integration/testdata"
_INTEGRATION_SKIP_FILE = "tests/integration/testdata-skip.txt"


def _load_skip_tests() -> set:
    """Load skip list from file."""
    skip_tests = set()
    if os.path.exists(_INTEGRATION_SKIP_FILE):
        with open(_INTEGRATION_SKIP_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    skip_tests.add(line)
    return skip_tests


def _get_all_integration_tests() -> list:
    """Get all integration tests with their source paths and converted names.

    Returns:
        List of tuples: (src_file_path, converted_name)
    """
    if not os.path.exists(_INTEGRATION_TESTDATA_DIR):
        return []

    tests = []
    for root, _, files in os.walk(_INTEGRATION_TESTDATA_DIR):
        for file in files:
            if file.endswith(".txtar"):
                src_file = os.path.abspath(os.path.join(root, file))
                rel_dir = os.path.relpath(root, _INTEGRATION_TESTDATA_DIR)
                name_without_ext = file.replace(".txtar", "")

                if rel_dir != ".":
                    prefix = rel_dir.replace(os.sep, "_") + "_"
                    converted_name = prefix + name_without_ext
                else:
                    converted_name = name_without_ext

                tests.append((src_file, converted_name))

    return tests


def get_integration_tests(skip: bool = False) -> list:
    """Get integration tests, optionally excluding those in skip list.

    Args:
        skip: If True, exclude tests listed in testdata-skip.txt

    Returns:
        List of tuples: (src_file_path, converted_name)
    """
    tests = _get_all_integration_tests()
    if not skip:
        return tests

    skip_tests = _load_skip_tests()
    return [(src, name) for src, name in tests if name not in skip_tests]


def copy_integration_tests(workdir: str, skip: bool = False) -> None:
    """Copy integration test files from tests/integration to gno/gno.land/pkg/integration."""
    module_manager = GnoModuleManager(workdir)

    # Copy testdata txtar files
    dest_testdata = os.path.join(
        module_manager.gno_root_dir, "pkg", "integration", "testdata"
    )

    if os.path.exists(_INTEGRATION_TESTDATA_DIR):
        # Create destination directory if it doesn't exist
        if os.path.islink(dest_testdata) or os.path.isfile(dest_testdata):
            os.unlink(dest_testdata)
        elif os.path.isdir(dest_testdata):
            shutil.rmtree(dest_testdata)
        os.makedirs(dest_testdata, exist_ok=True)

        print(f"Copying integration tests from {_INTEGRATION_TESTDATA_DIR} to {dest_testdata}")

        for src_file, converted_name in get_integration_tests(skip=skip):
            dest_file = os.path.join(dest_testdata, converted_name + ".txtar")

            # Remove existing file/link if present
            if os.path.exists(dest_file) or os.path.islink(dest_file):
                os.unlink(dest_file)

            # Create symlink
            os.symlink(src_file, dest_file)
            print(f"  Linked: {os.path.basename(src_file)} -> {converted_name}.txtar")

    # Copy bless directory
    src_bless = "tests/integration/bless"
    dest_bless = os.path.join(
        module_manager.gno_root_dir, "pkg", "integration", "bless"
    )

    if os.path.exists(src_bless):
        # Create destination directory if it doesn't exist
        if os.path.islink(dest_bless) or os.path.isfile(dest_bless):
            os.unlink(dest_bless)
        elif os.path.isdir(dest_bless):
            shutil.rmtree(dest_bless)
        os.makedirs(dest_bless, exist_ok=True)

        print(f"Copying bless directory from {src_bless} to {dest_bless}")

        # Copy all files from bless directory
        for file in os.listdir(src_bless):
            src_file = os.path.abspath(os.path.join(src_bless, file))
            dest_file = os.path.join(dest_bless, file)

            if os.path.isfile(src_file):
                # Remove existing file/link if present
                if os.path.exists(dest_file) or os.path.islink(dest_file):
                    os.unlink(dest_file)

                # Create symlink
                os.symlink(src_file, dest_file)
                print(f"  Linked: {file}")


def list_integration_tests(skip: bool = False) -> None:
    """List all integration tests with their converted names."""
    tests = get_integration_tests(skip=skip)
    if not tests:
        print("Error: Test directory not found", file=sys.stderr)
        sys.exit(1)

    for _, converted_name in sorted(tests, key=lambda x: x[1]):
        print(converted_name)


def main() -> None:
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description="Set up GnoSwap contracts")
    parser.add_argument(
        "-w",
        "--workdir",
        help="Path to your work directory",
        default=str(Path.home()),
    )
    parser.add_argument(
        "-c", "--clone", action="store_true", help="Clone the repository"
    )
    parser.add_argument(
        "--exclude-tests",
        action="store_true",
        help="Exclude *test.gno files from linking",
    )
    parser.add_argument(
        "--list-tests",
        action="store_true",
        help="List all integration tests with converted names",
    )
    parser.add_argument(
        "--skip",
        action="store_true",
        help="Exclude tests listed in testdata-skip.txt",
    )
    parser.add_argument(
        "--with-metrics",
        action="store_true",
        help="Include metrics in the output",
        default=False,
    )

    args = parser.parse_args()

    if args.list_tests:
        list_integration_tests(skip=args.skip)
        return

    if args.clone:
        clone_repository(args.workdir)

    setup_contracts(args.workdir, exclude_tests=args.exclude_tests, with_metrics=args.with_metrics)
    copy_integration_tests(args.workdir, args.skip)
    print("Setup completed successfully!")


if __name__ == "__main__":
    main()
