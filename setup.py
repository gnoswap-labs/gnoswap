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
        self.gno_dir = os.path.join(workdir, "gno", "examples", "gno.land")

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
    """Handles copying of contract files and tests."""

    def __init__(self, module_manager: GnoModuleManager):
        self.module_manager = module_manager

    def copy_module(self, module_info: ModuleInfo) -> None:
        """Copy module files to destination."""
        print(
            f"Copying module from {module_info.source_dir} to {module_info.destination_dir}"
        )
        os.makedirs(os.path.dirname(module_info.destination_dir), exist_ok=True)
        shutil.copytree(
            module_info.source_dir, module_info.destination_dir, dirs_exist_ok=True
        )

    def copy_tests(self, src_test_dir: str, dest_dir: str) -> None:
        """Copy test files to destination."""
        print(f"Copying tests from {src_test_dir} to {dest_dir}")
        if os.path.exists(src_test_dir):
            os.makedirs(dest_dir, exist_ok=True)
            for test_file in os.listdir(src_test_dir):
                src_file = os.path.join(src_test_dir, test_file)
                dest_file = os.path.join(dest_dir, test_file)
                if os.path.isfile(src_file):
                    shutil.copy2(src_file, dest_file)

    def process_directory(self, root: str, dirs: list, files: list) -> None:
        """Process a directory for modules and tests."""
        # Handle modules - check for both new TOML format and legacy format
        module_file = None
        if "gnomod.toml" in files:
            module_file = os.path.join(root, "gnomod.toml")
        elif "gno.mod" in files:
            raise ValueError("gno.mod format is outdated. Please use gnomod.toml instead.")
        
        if module_file:
            module_path = self.module_manager.extract_module_path(module_file)
            if module_info := self.module_manager.get_module_info(root, module_path):
                self.copy_module(module_info)

        # Handle test directories
        if "tests" in dirs:
            parent_module_path, parent_dir = self.module_manager.find_parent_module(
                root
            )
            if module_info := self.module_manager.get_module_info(
                parent_dir, parent_module_path
            ):
                src_test_dir = os.path.join(root, "tests")
                self.copy_tests(src_test_dir, module_info.destination_dir)


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
    print("Setup completed successfully!")


if __name__ == "__main__":
    main()