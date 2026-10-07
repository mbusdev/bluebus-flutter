import os
print(os.environ["PR_BODY"])

with open("tmp_changed_files.txt") as f:
    print(f.read())