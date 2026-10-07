<!--
Hey! Thanks for submitting a pull request. Please use this template for all PRs.

*** Please format the title of your PR using the following style: ***

TEMPLATE TITLE: <type>(<scope>): <subject>
       Example title: feat(ui): Add "NEW" button to map screen

       <type> can be one of:
            feat – new feature
            fix – bug fix
            docs – documentation only
            style – formatting, whitespace, missing semicolons
            refactor – code change that neither fixes a bug nor adds a feature
            perf – performance improvement
            test – adding or correcting tests
            chore – maintenance (build scripts, dependencies, CI)
       <scope> can be one of:
            Flutter side: ui, widget, screen, map, bus, route, notif, firebase
            Backend side: backend, api, endpoint, service, db
            Shared: auth
       <subject> is the subject of your PR, e.g. "Add 'NEW' button to map screen"

For more info, please see the Contribution Guide:
https://github.com/mbusdev/maizebus-markdown-docs/blob/main/contribution-guide.md

-->

## Description
(1-2 sentences: what changed and why — e.g., "Added Firebase push notifications for real-time bus arrivals")

## Type of Change
- [ ] New feature (`feat`)
- [ ] Bug fix (`fix`)
- [ ] Refactor / code improvement
- [ ] Dependency / build update
- [ ] Documentation
- [ ] Other (explain)

## Changed Files
(Please list *all* files you changed, each with a description of what you changed and why.)
*Tip: see a list of everything you changed on the "Files changed" tab*

Example:
* `map_screen.dart`
    * Added "New" button to top toolbar
* `bluebus_api.dart`
    * Added try/catch statements to `fetchRoutes()` for better reliability

## Related Issues
Closes #XX

## Does your code rely on another PR
(attach PR number here)

## Testing Done
**Flutter:**
- [ ] Tested on:
  - [ ] iOS Simulator
  - [ ] Android Emulator
  - [ ] Physical device

## Screenshots / Demo (if UI or notification change)
<!-- Drag & drop images or screen recordings here -->

## Checklist
- [ ] Commit messages follow Conventional Commits
- [ ] PR title follows `[type](scope): short description`
- [ ] PR target branch is not `main` and is our current working update branch (e.g. `maizebus2.1`)
- [ ] No `print()` / `debugPrint()` / `console.log()` left in production code
- [ ] Secrets / keys not committed