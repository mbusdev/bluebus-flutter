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

# print(os.environ["PR_BODY"])

# Run gh pr diff 119 \
# Description here
# .github/workflows/check-target.yaml
# .github/workflows/pr_description_check.py

pr_body = os.environ["PR_BODY"]
# pr_body = "Description here\nThis is some text, yay!\npr_description_check.py"

all_accounted_for = True

with open("tmp_changed_files.txt") as f:
    lines = f.read().split("\n")
    for line in lines:
        if line.trim() == "":
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
    print("::error::Please make sure all changed files are listed in your pull request description. See above for details")
    exit(1)
