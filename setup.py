import os
import shutil
import argparse
import subprocess

def clone_repo(workdir):
    os.chdir(workdir)
    subprocess.run(["git", "clone", "https://github.com/gnoswap-labs/gnoswap.git"], check=True)
    os.chdir("gnoswap")

def copy_contracts(workdir):
    gno_dir = os.path.join(workdir, "gno", "examples", "gno.land")

    # Copy GRC20 tokens
    shutil.copytree("__local/grc20_tokens", os.path.join(gno_dir, "r", "demo"), dirs_exist_ok=True)
    shutil.copytree("_deploy/r/gnoswap", os.path.join(gno_dir, "r"), dirs_exist_ok=True)

    # Copy gnoswap base packages
    shutil.copytree("_deploy/p/gnoswap", os.path.join(gno_dir, "p", "gnoswap"), dirs_exist_ok=True)

    # Copy gnoswap base realms
    shutil.copytree("_deploy/r/gnoswap", os.path.join(gno_dir, "r", "gnoswap"), dirs_exist_ok=True)

    # Copy gnoswap realms
    for realm in ["pool", "position", "router", "staker"]:
        shutil.copytree(realm, os.path.join(gno_dir, "r", "gnoswap"), dirs_exist_ok=True)

def move_tests(workdir):
    gno_dir = os.path.join(workdir, "gno", "examples", "gno.land", "r")

    for realm in ["pool", "position", "router", "staker"]:
        test_dir = os.path.join(gno_dir, realm, "_TEST_")
        if os.path.exists(test_dir):
            for item in os.listdir(test_dir):
                shutil.move(os.path.join(test_dir, item), os.path.join(gno_dir, realm))

def main():
    parser = argparse.ArgumentParser(description="Set up GnoSwap contracts")
    parser.add_argument("workdir", help="Path to your work directory")
    args = parser.parse_args()

    clone_repo(args.workdir)
    copy_contracts(args.workdir)
    move_tests(args.workdir)

    print("Setup completed successfully!")

if __name__ == "__main__":
    main()
