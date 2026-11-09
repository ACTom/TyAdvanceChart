# Contributing

> 中文: [CONTRIBUTING.md](CONTRIBUTING.md)

Bug reports, suggestions and pull requests are all welcome. Please file issues on [GitHub](https://github.com/ACTom/TyAdvanceChart/issues), in English or Chinese.

## Reporting a bug

Check section 12 of [docs/advancechart.md](docs/advancechart.md), "Differences from ECharts", first; it may already be listed there.

Please include:

- The TyAdvanceChart version, and the TyControls, Lazarus and FPC versions (on a `main` branch, the commit)
- Operating system and widgetset (win32 / gtk2 / gtk3 / qt5 / qt6 / cocoa); on Linux, whether it's X11 or Wayland
- Display scaling (100%, 150%, …) and the theme in use
- How to reproduce it: ideally the option itself; otherwise a minimal project that compiles
- What you see and what you expected; for anything drawn wrong, a screenshot, and if you can, one of the same option drawn by ECharts

## Suggesting a feature

Have a look at the [roadmap](https://github.com/ACTom/TyAdvanceChart/milestones) first; it may already be planned.

Tell us what you want to do with it rather than only the solution you have in mind. There is often a better fit for the same need.

## Roadmap and releases

Each version has a Milestone whose description says what the release is mainly about. Each major feature has a tracking issue you can subscribe to and discuss.

Versions are ordered, not dated. A finished Milestone doesn't mean an immediate release: a bug-fix release usually waits a while longer, until no new problem reports come in.

## Versions and support

This project follows TyControls' versions:

- Until TyControls releases 4.0, this project depends on TyControls' `main` branch, makes no formal release, and its version stays 3.99.0.
- Until then there is no long-term support line and no maintenance branch.
- When TyControls 4.0 is out, this project depends on TyControls 4.0 and releases its own 4.0, its first formal release.
- After that, this project's minor versions are its own, but it stays compatible with the latest stable TyControls.

From 4.0 on:

Versions are `major.minor.patch`. Patch releases only fix bugs; minor releases add features but stay compatible, as described below.

**Support window**: the latest minor version gets fixes and releases. The one before it keeps getting fixes and releases too, until the next minor version after that ships; then it gets one last release and support ends. For example, the last 4.0.x comes out together with 4.2. Severe problems are exempt from this.

**Compatibility**: within a major version, a minor release guarantees that:

- Public API is neither removed nor changed in signature. Anything on its way out is marked `deprecated` first and only removed in the next major version.
- Properties stored in form files (`.lfm`) are neither removed nor renamed, and their default values don't change.
- Existing `.tycss` files keep working: the chart's token names are only ever added to.
- The minimum requirements don't go up: Lazarus 3.0, FPC 3.2.2.
- The control keeps its default size, so upgrading doesn't shift your layout. Colors in the built-in styles may be fine-tuned.

Fixing a bug doesn't count as breaking compatibility, even if some code relied on the old, wrong behavior.

## Pull requests

For anything sizeable, open an issue or comment on an existing one first, so the work doesn't end up going in a different direction.

**Branches**: everything goes on `main`; larger features are built on a feature branch and merged back into `main`.

**Build and test**:

```
lazbuild tests/tyadvchart_tests.lpi
tests/tyadvchart_tests --all --format=plain
```

- lazbuild has to find TyControls' packages and this project's: install them in the IDE, or register them with `--add-package-link`.
- A few tests compare the chart with TyControls' source. Set the environment variable `TY_CORE_DIR` to a TyControls checkout; without it they are skipped.

Bug fixes should come with a test that fails without the fix.

**Ground rules**:

- Expected values come from the real ECharts: `tests/fixtures/advchart-*.json` are written by the node scripts in `tools/advchart-oracle/`, run against the ECharts 6.1 dist. Never edit them by hand; change the script and run it again.
- Visual values (colors, sizes) come from theme tokens, never hard-coded. The chart's tokens and rules are in `themes/advchart.tycss`; after changing it, run `powershell -File scripts/gen-advchart-theme.ps1` to regenerate `tyControls.AdvanceChart.Theme.pas`.
- No native LCL controls (`TEdit`, `TButton`, …) inside owner-drawn UI.
- Add new units to `tyadvancechart.lpk` (design-time ones to `tyadvancechart_dt.lpk`); add new test units to `tests/tyadvchart_tests.lpr`.
- `TTyCustomAdvanceChart` holds the implementation and `TTyAdvanceChart` is just a `published` section (see TyControls' [subclassing.en.md](https://github.com/ACTom/TyControls/blob/main/docs/subclassing.en.md)). After changing `TTyAdvanceChart`'s `published` section, do two more steps and read each diff:
  - Run `python scripts/gen-mimic.py` to regenerate `tests/test.advchart.customclasses.mimic.pas`. The diff should only show the lines you changed. The script copies `TTyAdvanceChart`'s *current* published section, so if other lines change, the publish order was changed by accident; regenerating copies the wrong order, it doesn't fix it.
  - From `tests/`, run `TY_WRITE_FRESH_STREAMS=1 ./tyadvchart_tests --suite=TAdvChartCustomClassesGuardTest.TestFreshFormFileTextUnchanged` (in PowerShell, set `$env:TY_WRITE_FRESH_STREAMS='1'` first) to update `tests/fixtures/customclasses/fresh-streams.txt`. Every line in the diff is a change to what a fresh instance writes to a form file.
- User-visible text goes in a `resourcestring` in `tyControls.AdvanceChart.StrConsts`, with the zh_CN `.po` under `languages/` updated to match.
- Examples use `.lfm` forms, have a title bar and can switch themes at runtime.
- Don't use LCL API newer than Lazarus 3.0; where you must, keep a path for older versions behind `LCL_FULLVERSION`.
- Otherwise, follow the code around you.

**Commit messages** are in English, as `type(scope): summary`, e.g. `fix(tooltip): the box leaves the chart at the right edge`. If it fixes an issue, put `Fixes #N` in the body.

## Changelog

Each release's changes go in [CHANGELOG.en.md](CHANGELOG.en.md). It only records changes users can notice, each linked to its issue; docs, refactoring and tests are left out. Don't edit the changelog in a PR; it's written up at release time.
