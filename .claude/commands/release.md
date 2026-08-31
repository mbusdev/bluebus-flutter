---
description: Bump the version and build MaizeBus for the App Store and Play Store
argument-hint: <version | patch | minor | major> [--dry-run] [--skip-ios] [--skip-android]
allowed-tools: Bash(./scripts/release.sh:*), Bash(git status:*), Bash(git diff:*), Read
---

Run the release for MaizeBus: `./scripts/release.sh $ARGUMENTS`

The script owns every deterministic step — version bump across all four files, the
production backend-URL check, and both builds. Do not perform those edits by hand;
if something is wrong, fix the script rather than working around it.

Your job around it:

1. If no version argument was given, show the current `version:` from `pubspec.yaml`
   and ask which bump they want before running anything.
2. Run with `--dry-run` first and show the plan. Then run for real.
   Pass `-y` on the real run — the user has already confirmed the plan by that point.
3. If a pre-flight check fails, explain the specific cause and what it means for the
   release. Do not retry with `--allow-dirty`, `--allow-debug-signing`, or
   `--skip-android` unless the user asks — those flags suppress checks that exist
   because the resulting build gets rejected at upload.
4. If a build fails, surface the actual compiler or Gradle error. Note that the
   version files are already bumped at that point, so a fixed retry should reuse the
   same version via `--build <same number>` rather than bumping again.
5. On success, report both artifact paths and remind them to commit the bump.

Background, so you don't re-derive it: `pubspec.yaml` is the only load-bearing
version file. iOS reads it through `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`
in `ios/Runner/Info.plist` via the generated xcconfig, and Android reads it through
`updateLocalProperties()`, which rewrites `android/local.properties` on every build.
The `project.pbxproj` and `local.properties` edits are cosmetic — kept in sync so the
Xcode GUI and a bare Gradle invocation don't show a stale version. Opening
`Runner.xcworkspace` by hand is no longer part of the process.
