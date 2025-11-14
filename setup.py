import os
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
        self.gno_dir = os.path.join(workdir, "gno-core", "examples", "gno.land")
        self.gno_root_dir = os.path.join(workdir, "gno-core", "gno.land")

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

    def __init__(self, module_manager: GnoModuleManager):
        self.module_manager = module_manager

    def copy_module(self, module_info: ModuleInfo) -> None:
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

    def process_directory(self, root: str, dirs: list, files: list) -> None:
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
                self.copy_module(module_info)


def clone_repository(workdir: str) -> None:
    """Clone the GnoSwap repository."""
    os.chdir(workdir)
    subprocess.run(
        ["git", "clone", "https://github.com/gnoswap-labs/gnoswap.git"], check=True
    )
    os.chdir("gnoswap")


def setup_contracts(workdir: str) -> None:
    """Set up all contracts and tests."""
    module_manager = GnoModuleManager(workdir)
    copier = ContractCopier(module_manager)

    for root, dirs, files in os.walk("contract"):
        copier.process_directory(root, dirs, files)

    for root, dirs, files in os.walk("tests/scenario"):
        copier.process_directory(root, dirs, files)


def copy_integration_tests(workdir: str) -> None:
    """Copy integration test files from tests/integration to gno-core/gno.land/pkg/integration."""
    module_manager = GnoModuleManager(workdir)

    # Copy testdata txtar files
    src_testdata = "tests/integration/testdata"
    dest_testdata = os.path.join(
        module_manager.gno_root_dir, "pkg", "integration", "testdata"
    )

    if os.path.exists(src_testdata):
        # Create destination directory if it doesn't exist
        if os.path.islink(dest_testdata) or os.path.isfile(dest_testdata):
            os.unlink(dest_testdata)
        elif os.path.isdir(dest_testdata):
            shutil.rmtree(dest_testdata)
        os.makedirs(dest_testdata, exist_ok=True)

        print(f"Copying integration tests from {src_testdata} to {dest_testdata}")

        # Walk through all directories and find txtar files
        for root, _, files in os.walk(src_testdata):
            for file in files:
                if file.endswith(".txtar"):
                    src_file = os.path.abspath(os.path.join(root, file))

                    # Calculate relative path from src_testdata
                    rel_dir = os.path.relpath(root, src_testdata)

                    # If file is in a subdirectory, add directory name as prefix
                    if rel_dir != ".":
                        # Convert nested paths to prefix (e.g., "gov/governance" -> "gov_governance_")
                        prefix = rel_dir.replace(os.sep, "_") + "_"
                        dest_filename = prefix + file
                    else:
                        dest_filename = file

                    dest_file = os.path.join(dest_testdata, dest_filename)

                    # Remove existing file/link if present
                    if os.path.exists(dest_file) or os.path.islink(dest_file):
                        os.unlink(dest_file)

                    # Create symlink
                    os.symlink(src_file, dest_file)
                    print(f"  Linked: {file} -> {dest_filename}")

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

    args = parser.parse_args()

    if args.clone:
        clone_repository(args.workdir)

    setup_contracts(args.workdir)
    copy_integration_tests(args.workdir)
    print("Setup completed successfully!")


if __name__ == "__main__":
    main()
