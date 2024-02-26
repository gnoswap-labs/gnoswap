import os
import subprocess
import argparse

# python3 setup.py --workdir /path/to/your/workdir

def clone_and_setup(workdir: str) -> None:
    # Clone and setup gno-for-swap
    os.chdir(workdir)
    subprocess.run(["git", "clone", "https://github.com/gnoswap-labs/gno.git", "gno-for-swap"], check=True)

    os.chdir("gno-for-swap")

    subprocess.run(["git", "checkout", "gs/base_clean"], check=True)
    subprocess.run(["make", "install"], check=True)

def setup_gnoswap_contracts(workdir: str) -> None:
    # Clone gnoswap contracts and copy them to the correct location
    os.chdir(workdir)
    subprocess.run(["git", "clone", "https://github.com/gnoswap-labs/gnoswap.git"], check=True)

    os.chdir("gnoswap")
    contracts_src = os.path.join(workdir, "gnoswap")
    contracts_dest = os.path.join(workdir, "gno-for-swap", "examples", "gno.land", "r", "demo")

    #TODO read the each contract directories from the gnoswap repo and update the below list
    subprocess.run(["cp", "-R", "_setup/*", "consts", "gov", "pool", "position", "router", "staker", contracts_dest], check=True)
    subprocess.run(["cp", "-R", "common", os.path.join(workdir, "gno-for-swap", "examples", "gno.land", "p", "demo")], check=True)

def run_tests(workdir: str) -> None:
    test_dir = os.path.join(workdir, "gno-for-swap", "examples", "gno.land", "r", "demo", "staker")
    subprocess.run(["gno", "test", "-root-dir", os.path.join(workdir, "gno-for-swap"), "-verbose=true", test_dir], check=True)

def main():
    parser = argparse.ArgumentParser(description="Setup and test Gno.land for Gnoswap")
    parser.add_argument(
        "--workdir",
        type=str,
        default=os.getcwd(),
        help="Directory to clone and setup repositories (defaults to current directory)"
    )

    args = parser.parse_args()

    #TODO should be run separately for each command. not sequentially

    print("Setting up Gno.land for Gnoswap...")
    clone_and_setup(args.workdir)
    setup_gnoswap_contracts(args.workdir)

    print("Running tests...")
    run_tests(args.workdir)

    print("Setup and tests completed successfully.")

if __name__ == "__main__":
    main()
