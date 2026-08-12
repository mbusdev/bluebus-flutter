#!/usr/bin/env bash
#
# MaizeBus release automation.
#
# Bumps the version everywhere it needs bumping, runs pre-flight checks, then
# builds the iOS IPA and the Android app bundle.
#
#   ./scripts/release.sh 2.0.4          # explicit version
#   ./scripts/release.sh patch          # 2.0.3 -> 2.0.4
#   ./scripts/release.sh minor          # 2.0.3 -> 2.1.0
#   ./scripts/release.sh major          # 2.0.3 -> 3.0.0
#   ./scripts/release.sh patch --dry-run
#   ./scripts/release.sh 2.0.4 --build 12
#
# WHERE THE SHIPPED VERSION ACTUALLY COMES FROM
#
# pubspec.yaml is the single source of truth for both platforms:
#
#   iOS      Runner/Info.plist uses $(FLUTTER_BUILD_NAME)/$(FLUTTER_BUILD_NUMBER),
#            which Flutter writes into ios/Flutter/Generated.xcconfig from
#            pubspec.yaml on every build. MARKETING_VERSION and
#            CURRENT_PROJECT_VERSION in project.pbxproj do NOT reach the IPA --
#            they only change what the Xcode GUI displays. We sync them anyway so
#            the project file doesn't lie, and verify the Info.plist wiring below
#            so we find out immediately if that ever stops being true.
#
#   Android  flutter build calls updateLocalProperties(), which rewrites
#            flutter.versionName/flutter.versionCode in android/local.properties
#            from pubspec.yaml. Editing that file by hand is redundant; we write it
#            only so the value is correct before the build rather than after.
#
set -euo pipefail

readonly EXPECTED_BACKEND_URL='https://busapi.maizebus.com/mbus/api/v3'

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

readonly PUBSPEC='pubspec.yaml'
readonly CONSTANTS='lib/constants.dart'
readonly PBXPROJ='ios/Runner.xcodeproj/project.pbxproj'
readonly INFO_PLIST='ios/Runner/Info.plist'
readonly LOCAL_PROPS='android/local.properties'
readonly KEY_PROPS='android/key.properties'

# ---------------------------------------------------------------- output helpers

if [[ -t 1 ]]; then
  readonly C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
  readonly C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_BLUE=$'\033[34m'
else
  readonly C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

step() { printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
ok()   { printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
info() { printf '  %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
die()  { printf '\n%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Bump the MaizeBus version everywhere, run pre-flight checks, then build both stores.

usage: ./scripts/release.sh <version|patch|minor|major> [options]

  2.0.4                  release exactly this version
  patch | minor | major  bump that component of the current version

options
  --build N              set the build number explicitly (default: current + 1)
  -n, --dry-run          show the plan, write nothing
  -y, --yes              don't ask for confirmation
  --skip-ios             don't run flutter build ipa
  --skip-android         don't run flutter build appbundle
  --no-build             bump the version files only, build nothing
  --allow-dirty          release with uncommitted changes
  --allow-debug-signing  build the .aab without android/key.properties
  -h, --help             this text
EOF
  exit "${1:-0}"
}

# ------------------------------------------------------------------ argument parse

TARGET='' BUILD_OVERRIDE='' DRY_RUN=0 ASSUME_YES=0
ALLOW_DIRTY=0 ALLOW_DEBUG_SIGNING=0 SKIP_IOS=0 SKIP_ANDROID=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)             usage 0 ;;
    -n|--dry-run)          DRY_RUN=1 ;;
    -y|--yes)              ASSUME_YES=1 ;;
    --build)               BUILD_OVERRIDE="${2:-}"; shift ;;
    --allow-dirty)         ALLOW_DIRTY=1 ;;
    --allow-debug-signing) ALLOW_DEBUG_SIGNING=1 ;;
    --skip-ios)            SKIP_IOS=1 ;;
    --skip-android)        SKIP_ANDROID=1 ;;
    --no-build)            SKIP_IOS=1; SKIP_ANDROID=1 ;;
    -*)                    die "unknown flag: $1 (try --help)" ;;
    *)
      [[ -n "$TARGET" ]] && die "version specified twice: '$TARGET' and '$1'"
      TARGET="$1"
      ;;
  esac
  shift
done

[[ -n "$TARGET" ]] || { printf '%serror:%s no version given\n\n' "$C_RED" "$C_RESET" >&2; usage 1; }

# ------------------------------------------------------------- read current state

step "Reading current version"

for f in "$PUBSPEC" "$CONSTANTS" "$PBXPROJ" "$INFO_PLIST"; do
  [[ -f "$f" ]] || die "missing $f -- are we in the right repo?"
done

# pubspec.yaml is authoritative: `version: <name>+<code>`
pubspec_version_line="$(grep -E '^version:' "$PUBSPEC" || true)"
[[ -n "$pubspec_version_line" ]] || die "no 'version:' line in $PUBSPEC"

current_full="$(printf '%s' "$pubspec_version_line" | sed -E 's/^version:[[:space:]]*//; s/[[:space:]]*$//')"
current_name="${current_full%%+*}"
current_build="${current_full##*+}"

[[ "$current_full" == *+* ]] || die "$PUBSPEC version '$current_full' has no +buildNumber"
[[ "$current_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || die "can't parse version name '$current_name' from $PUBSPEC (want MAJOR.MINOR.PATCH)"
[[ "$current_build" =~ ^[0-9]+$ ]] \
  || die "can't parse build number '$current_build' from $PUBSPEC"

info "current: $current_name+$current_build"

# ------------------------------------------------------------ compute new version

IFS='.' read -r cur_major cur_minor cur_patch <<<"$current_name"

case "$TARGET" in
  major) new_name="$((cur_major + 1)).0.0" ;;
  minor) new_name="${cur_major}.$((cur_minor + 1)).0" ;;
  patch) new_name="${cur_major}.${cur_minor}.$((cur_patch + 1))" ;;
  *)
    [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
      || die "'$TARGET' is not MAJOR.MINOR.PATCH or major/minor/patch"
    new_name="$TARGET"
    ;;
esac

if [[ -n "$BUILD_OVERRIDE" ]]; then
  [[ "$BUILD_OVERRIDE" =~ ^[0-9]+$ ]] || die "--build wants an integer, got '$BUILD_OVERRIDE'"
  new_build="$BUILD_OVERRIDE"
else
  new_build="$((current_build + 1))"
fi

if (( new_build <= current_build )); then
  die "build number must increase: $current_build -> $new_build. App Store Connect and
       Play Console both reject a build number they have already seen."
fi

# A same-or-lower version name is legal (re-uploading a build of the same release),
# but it is almost always a mistake, so say so.
IFS='.' read -r new_major new_minor new_patch <<<"$new_name"
if [[ "$new_name" == "$current_name" ]]; then
  warn "version name unchanged ($new_name); only the build number moves"
elif (( new_major < cur_major
     || (new_major == cur_major && new_minor < cur_minor)
     || (new_major == cur_major && new_minor == cur_minor && new_patch < cur_patch) )); then
  warn "$new_name is LOWER than the current $current_name"
  warn "the stores will reject a release whose version string goes backwards"
  if (( ! ASSUME_YES )); then
    printf '  continue anyway? [y/N] ' >&2
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]] || die "aborted"
  fi
fi

info "new:     $new_name+$new_build"

# ------------------------------------------------------------------- preflight

step "Pre-flight checks"

# Every check runs even after one fails, so a single run tells you everything that
# needs fixing rather than making you rediscover problems one build at a time.
FAILURES=()
fail() { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; FAILURES+=("$2"); }

command -v flutter >/dev/null || die "flutter not on PATH"

# 1. Working tree. A dirty tree is normal mid-release, but releasing off
#    half-finished work is not, and the bump would be tangled up with it.
if ! git diff --quiet HEAD 2>/dev/null; then
  if (( ALLOW_DIRTY )); then
    warn "working tree is dirty (--allow-dirty)"
  else
    fail "working tree has uncommitted changes" \
         "Working tree is dirty -- commit or stash first, or pass --allow-dirty."
    git status --short | sed "s/^/      /" >&2
  fi
else
  ok "working tree clean"
fi

# 2. The load-bearing iOS wiring. If Info.plist stops deferring to Flutter, the
#    pbxproj values become the real shipped version and this script's reasoning is
#    wrong -- so fail loudly rather than silently ship a stale version.
if grep -q '\$(FLUTTER_BUILD_NAME)' "$INFO_PLIST" && grep -q '\$(FLUTTER_BUILD_NUMBER)' "$INFO_PLIST"; then
  ok "$INFO_PLIST defers to Flutter for version strings"
else
  fail "$INFO_PLIST no longer defers to Flutter" \
       "$INFO_PLIST no longer uses \$(FLUTTER_BUILD_NAME)/\$(FLUTTER_BUILD_NUMBER), so the
     shipped iOS version would come from project.pbxproj instead of pubspec.yaml.
     Restore the plist wiring, or rewrite this script's iOS handling before releasing."
fi

# 3. Android release signing. Without key.properties, app/build.gradle.kts falls
#    back to signingConfigs["debug"] -- the build succeeds and Play Console then
#    rejects the bundle. Catch it before the multi-minute build, not after.
if [[ -f "$KEY_PROPS" ]]; then
  ok "$KEY_PROPS present (release signing)"
elif (( SKIP_ANDROID )); then
  info "no $KEY_PROPS, but Android build is skipped"
elif (( ALLOW_DEBUG_SIGNING )); then
  warn "no $KEY_PROPS -- bundle will be DEBUG-SIGNED and Play Console will reject it"
else
  fail "$KEY_PROPS not found (release would be debug-signed)" \
       "$KEY_PROPS not found. android/app/build.gradle.kts falls back to the debug
     signing config when it is missing, producing an .aab that Play Console rejects.
     Restore the file (keyAlias/keyPassword/storeFile/storePassword), or pass
     --skip-android, or --allow-debug-signing to build it unsigned anyway."
fi

# 4. Backend URL. Only the uncommented `defaultValue:` counts -- constants.dart
#    keeps several alternates commented out just above and below it.
backend_hits="$(grep -n 'defaultValue:' "$CONSTANTS" | grep -vE '^[0-9]+:[[:space:]]*//' || true)"
backend_count="$(printf '%s' "$backend_hits" | grep -c . || true)"

FIX_BACKEND_URL=0
backend_lineno=''

if [[ "$backend_count" -ne 1 ]]; then
  # Ambiguous: either several alternates got uncommented at once, or none did.
  # Guessing which one is live risks shipping a dev backend, so refuse.
  fail "found $backend_count active 'defaultValue:' lines in $CONSTANTS (want exactly 1)" \
       "Expected exactly one uncommented 'defaultValue:' in $CONSTANTS, found $backend_count.
     Fix the BACKEND_URL block by hand -- this script will not guess which one is live."
else
  backend_lineno="${backend_hits%%:*}"
  active_backend_url="$(printf '%s' "$backend_hits" | sed -E "s/.*defaultValue:[[:space:]]*'([^']*)'.*/\1/")"

  if [[ "$active_backend_url" == "$EXPECTED_BACKEND_URL" ]]; then
    ok "backend URL is production"
  else
    warn "backend URL is not production -- will rewrite $CONSTANTS:$backend_lineno"
    info "    found: $active_backend_url"
    info "    want:  $EXPECTED_BACKEND_URL"
    FIX_BACKEND_URL=1
  fi
fi

# 5. Report everything at once.
if (( ${#FAILURES[@]} > 0 )); then
  printf '\n%s%d pre-flight check(s) failed:%s\n' "$C_RED" "${#FAILURES[@]}" "$C_RESET" >&2
  for f in "${FAILURES[@]}"; do
    printf '\n  %s•%s %s\n' "$C_RED" "$C_RESET" "$f" >&2
  done
  printf '\n' >&2
  exit 1
fi

# --------------------------------------------------------------------- confirm

step "Plan"
printf '  %-34s %s -> %s\n' "$PUBSPEC"    "$current_name+$current_build" "$new_name+$new_build"
printf '  %-34s %s -> %s\n' "$CONSTANTS"  "$current_name"                "$new_name"
printf '  %-34s %s -> %s%s\n' "$PBXPROJ"  "$current_name ($current_build)" "$new_name ($new_build)" \
       "${C_DIM} [cosmetic]${C_RESET}"
printf '  %-34s %s -> %s%s\n' "$LOCAL_PROPS" "$current_name ($current_build)" "$new_name ($new_build)" \
       "${C_DIM} [rewritten by flutter build anyway]${C_RESET}"
(( FIX_BACKEND_URL )) && printf '  %-34s %s\n' "$CONSTANTS" "reset BACKEND_URL to production"
(( SKIP_IOS ))     || printf '  %-34s %s\n' "build" "flutter build ipa"
(( SKIP_ANDROID )) || printf '  %-34s %s\n' "build" "flutter build appbundle"

if (( DRY_RUN )); then
  printf '\n%sdry run -- nothing written.%s\n' "$C_YELLOW" "$C_RESET"
  exit 0
fi

if (( ! ASSUME_YES )); then
  printf '\nProceed? [y/N] '
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]] || die "aborted"
fi

# ----------------------------------------------------------------- edit files

step "Updating version"

# pubspec.yaml -- the source of truth. Anchored to the top-level key so a
# dependency named `version` further down can't be hit.
perl -i -pe "s/^version:.*\$/version: ${new_name}+${new_build}/ if \$. < 20" "$PUBSPEC"
grep -qF "version: ${new_name}+${new_build}" "$PUBSPEC" || die "failed to update $PUBSPEC"
ok "$PUBSPEC"

# lib/constants.dart -- independent Dart constant, used by the in-app update check.
perl -i -pe "s/^(final String currentVersion = ')[^']*(';)\$/\${1}${new_name}\${2}/" "$CONSTANTS"
grep -qF "final String currentVersion = '${new_name}';" "$CONSTANTS" \
  || die "failed to update currentVersion in $CONSTANTS"
ok "$CONSTANTS (currentVersion)"

if (( FIX_BACKEND_URL )); then
  # The URL and line number go through the environment, and the perl program stays
  # fully single-quoted: the URL contains '/', which would otherwise close an s///
  # early, and \x27 stands in for the single quotes around the Dart string literal.
  NEW_URL="$EXPECTED_BACKEND_URL" TARGET_LINE="$backend_lineno" \
    perl -i -pe 's{(defaultValue:\s*\x27)[^\x27]*(\x27)}{$1$ENV{NEW_URL}$2} if $. == $ENV{TARGET_LINE};' \
    "$CONSTANTS"
  grep -qF "defaultValue: '${EXPECTED_BACKEND_URL}'" "$CONSTANTS" \
    || die "failed to reset BACKEND_URL in $CONSTANTS"
  ok "$CONSTANTS (BACKEND_URL reset to production)"
fi

# project.pbxproj -- cosmetic, but scoped carefully. Only XCBuildConfiguration
# blocks belonging to the Runner app target get touched; the RunnerTests target
# keeps its own MARKETING_VERSION = 1.0 / CURRENT_PROJECT_VERSION = 1.
python3 - "$PBXPROJ" "$new_name" "$new_build" <<'PY'
import re, sys

path, new_name, new_build = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path, encoding='utf-8').read()

# Each build configuration is a `<id> /* Name */ = {\n ... \n};` block at one
# indent level. Split on the closing brace of a block to walk them individually.
block_re = re.compile(
    r'(\t\t[0-9A-F]{24} /\* \w+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};\n)',
    re.DOTALL,
)

edits = 0

def patch(match):
    global edits
    block = match.group(1)
    # The Runner app target's configs are the ones pointing at Runner/Info.plist.
    # RunnerTests uses GENERATE_INFOPLIST_FILE instead, so it never matches.
    if 'INFOPLIST_FILE = Runner/Info.plist;' not in block:
        return block
    out, n1 = re.subn(r'(\n\t+MARKETING_VERSION = )[^;]*;', rf'\g<1>{new_name};', block)
    out, n2 = re.subn(r'(\n\t+CURRENT_PROJECT_VERSION = )[^;]*;', rf'\g<1>{new_build};', out)
    if n1 != 1 or n2 != 1:
        sys.exit(f'error: expected 1 MARKETING_VERSION and 1 CURRENT_PROJECT_VERSION '
                 f'per Runner config, got {n1} and {n2}')
    edits += 1
    return out

result = block_re.sub(patch, src)

# Debug + Release + Profile.
if edits != 3:
    sys.exit(f'error: expected to patch 3 Runner build configurations, patched {edits}. '
             f'{path} layout may have changed -- inspect it by hand.')

open(path, 'w', encoding='utf-8').write(result)
PY
ok "$PBXPROJ (3 Runner configs)"

# android/local.properties -- gitignored; flutter build rewrites it from pubspec
# regardless, but keep it consistent so a bare `gradlew` invocation agrees too.
if [[ -f "$LOCAL_PROPS" ]]; then
  perl -i -pe "s/^flutter\.versionName=.*\$/flutter.versionName=${new_name}/;
               s/^flutter\.versionCode=.*\$/flutter.versionCode=${new_build}/" "$LOCAL_PROPS"
  ok "$LOCAL_PROPS"
else
  info "no $LOCAL_PROPS yet -- flutter build will create it"
fi

# ---------------------------------------------------------------------- build

ios_artifact='' android_artifact=''

if (( ! SKIP_IOS )); then
  step "Building iOS (flutter build ipa)"
  flutter build ipa
  ios_artifact="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
fi

if (( ! SKIP_ANDROID )); then
  step "Building Android (flutter build appbundle)"
  flutter build appbundle
  android_artifact="$(ls -t build/app/outputs/bundle/release/*.aab 2>/dev/null | head -1 || true)"
fi

# --------------------------------------------------------------------- summary

step "Released $new_name+$new_build"

if (( ! SKIP_IOS )); then
  if [[ -n "$ios_artifact" ]]; then
    ok "iOS      $ios_artifact"
  else
    warn "iOS build reported success but no .ipa found in build/ios/ipa/"
  fi
fi

if (( ! SKIP_ANDROID )); then
  if [[ -n "$android_artifact" ]]; then
    ok "Android  $android_artifact"
  else
    warn "Android build reported success but no .aab found in build/app/outputs/bundle/release/"
  fi
fi

printf '\n%sNext%s\n' "$C_BOLD" "$C_RESET"
n=0
if [[ -n "$ios_artifact" ]]; then
  printf '  %d. Upload to App Store Connect -- Transporter, or:\n' "$((++n))"
  printf '       xcrun altool --upload-app -t ios -f "%s" --apiKey ... --apiIssuer ...\n' "$ios_artifact"
fi
if [[ -n "$android_artifact" ]]; then
  printf '  %d. Upload to Play Console -- Production > Create new release:\n' "$((++n))"
  printf '       %s\n' "$android_artifact"
fi
cat <<EOF
  $((++n)). Commit the bump:
       git add $PUBSPEC $CONSTANTS $PBXPROJ
       git commit -m "release: $new_name+$new_build"
       git tag v$new_name
EOF
