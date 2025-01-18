import os
import shutil
import argparse
import subprocess
from pathlib import Path
import re

def clone_repo(workdir):
    os.chdir(workdir)
    subprocess.run(["git", "clone", "https://github.com/gnoswap-labs/gnoswap.git"], check=True)
    os.chdir("gnoswap")

def get_module_path(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    match = re.search(r'module\s+([\w./]+)', content)
    if match:
        return match.group(1)
    return None

def copy_contracts(workdir):
    gno_dir = os.path.join(workdir, "gno", "examples", "gno.land")

    # Copy GRC20 tokens
    shutil.copytree("__local/grc20_tokens", os.path.join(gno_dir, "r"), dirs_exist_ok=True)

    # Copy gnoswap base packages and realms
    for root, dirs, files in os.walk("_deploy"):
        for file in files:
            if file == "gno.mod":
                src_dir = os.path.dirname(os.path.join(root, file))
                module_path = get_module_path(os.path.join(root, file))
                if module_path:
                    dest_dir = os.path.join(gno_dir, *module_path.split('/')[1:])
                    shutil.copytree(src_dir, dest_dir, dirs_exist_ok=True)

    # Copy gnoswap realms
    # TODO: Detect realms automatically
    for realm in ["pool", "position", "router", "staker", "emission", "community_pool", "protocol_fee", "launchpad", "gov"]:
        shutil.copytree(realm, os.path.join(gno_dir, "r", "gnoswap", "v1", realm), dirs_exist_ok=True)

def move_tests(workdir):
    gno_dir = os.path.join(workdir, "gno", "examples", "gno.land", "r", "gnoswap", "v1")
    print(f"GNO_DIR IS {gno_dir}")

    for realm in ["pool", "position", "router", "staker", "emission", "community_pool", "gns", "gnft", "launchpad", "gov"]:
        test_dir = os.path.join(gno_dir, realm, "tests")
        if os.path.exists(test_dir):
            print(f"{test_dir} exists")
            for item in os.listdir(test_dir):
                shutil.move(os.path.join(test_dir, item), os.path.join(gno_dir, realm))

def main():
    parser = argparse.ArgumentParser(description="Set up GnoSwap contracts")
    parser.add_argument(
        "-w", "--workdir",
        help="Path to your work directory", default=str(Path.home()),
    )
    parser.add_argument("-c", "--clone", action="store_true", help="Clone the repository")
    args = parser.parse_args()

    if args.clone:
        clone_repo(args.workdir)

    copy_contracts(args.workdir)
    move_tests(args.workdir)

    print("Setup completed successfully!")

if __name__ == "__main__":
    main()
