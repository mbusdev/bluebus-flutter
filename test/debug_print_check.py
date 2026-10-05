import subprocess
import sys

BLACK   = "\033[0;30m";
RED     = "\033[0;31m";
GREEN   = "\033[0;32m";
YELLOW  = "\033[0;33m";
BLUE    = "\033[0;34m";
MAGENTA = "\033[0;35m";
CYAN    = "\033[0;36m";
WHITE   = "\033[0;37m";
RESET   = "\033[0m";

# #!/bin/bash
# set -Eeuo pipefail

# for path in $(); do
#     echo $path
#     lines=$(grep "debugPrint" $path)
#     echo $lines
# done
# os.system('find . -name "*.dart"')

def checkLineForDebugprint(filename, line, linenum):
    if ".dart_tool" in filename:
        return True #Don't scan Dart framework files

    if "debugPrint(" not in line and " print(" not in line:
        return True

    parts = line.split("debugPrint")
    if parts[0].strip().endswith("//"):
        return True # debugPrint is commented out

    parts = line.split(" print(")
    if parts[0].strip().endswith("//"):
        return True # print is commented out

    if "LINTER_OVERRIDE" in line:
        return True
    print(YELLOW + "   "+str(linenum) + ":\t" + line.strip() + RESET)
    return False

def checkLineForTodo(filename, line, linenum):
    if "TODO" not in line:
        return True
    print(CYAN + "   "+str(linenum) + ":\t" + line.strip() + RESET)

dart_files = subprocess.check_output('find . -name "*.dart"', shell=True, text=True).split("\n")
# print(dart_files)
debugprint_checks_pass = True
for filename in dart_files:
    if filename == "":
        continue
    print("\nChecking", filename)
    with open(filename, "r") as file:
        lines = file.read().split("\n")
        for i in range(0, len(lines)):
            debugprint_check_result = checkLineForDebugprint(filename, lines[i], i)
            debugprint_checks_pass = debugprint_checks_pass and debugprint_check_result
            checkLineForTodo(filename, lines[i], i)

if debugprint_checks_pass:
    print(GREEN + "\n\nAll style checks passed!\n" + RESET)
    sys.exit(0)
else:
    print("\n\n::error::Extra debugPrint() statements found, please resolve these. (Click to see details)")
    print(RED + "\nSome style checks failed! See above for details" + RESET)
    print("Looks like there are extra debugPrint() statements left in your code.")
    print("Tips to fix this:")
    print("    1. Make sure you've removed unnecessary debugging logs")
    print("    2. To log errors, use stderr.writeln(...) instead of debugPrint()")
    print("    3. If you feel like a log message really needs to stay (e.g. for warnings),")
    print("       add the comment // LINTER_OVERRIDE on the same line")
    print("    4. Avoid using the print() statement--use another option instead")
    sys.exit(1)