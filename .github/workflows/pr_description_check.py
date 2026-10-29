import os

BLACK   = "\033[0;30m";
RED     = "\033[0;31m";
GREEN   = "\033[0;32m";
YELLOW  = "\033[0;33m";
BLUE    = "\033[0;34m";
MAGENTA = "\033[0;35m";
CYAN    = "\033[0;36m";
WHITE   = "\033[0;37m";
RESET   = "\033[0m";

pr_body = os.environ["PR_BODY"]

all_accounted_for = True

with open("tmp_changed_files.txt") as f:
    lines = f.read().split("\n")
    for line in lines:
        if line.strip() == "":
            continue # Skip empty lines
        parts = line.split("/")
        filename = parts[len(parts) - 1]
        if filename in pr_body:
            print(GREEN+"✓ Changed file "+filename+" in PR description"+RESET)
        else:
            all_accounted_for = False
            print(RED+"✗ Changed file "+filename+" not found in PR description"+RESET)


if all_accounted_for:
    exit(0)
else:
    print("::error::Please edit your pull request description to make sure it lists all changed files. See above for details")
    exit(1)
