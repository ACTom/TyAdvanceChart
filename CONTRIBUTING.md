# 参与贡献

> English: [CONTRIBUTING.en.md](CONTRIBUTING.en.md)

欢迎报告问题、提建议、提交代码。issue 统一提在 [GitHub](https://github.com/ACTom/TyAdvanceChart/issues)，中英文都可以。

## 报告 bug

先看一眼 [docs/advancechart.md](docs/advancechart.md) 第 12 节「与 ECharts 的差异」，那里可能已经写了。

提 issue 时请写上：

- TyAdvanceChart 的版本，TyControls、Lazarus、FPC 的版本（用 `main` 分支的话写提交号）
- 操作系统和 widgetset（win32 / gtk2 / gtk3 / qt5 / qt6 / cocoa）；Linux 请注明是 X11 还是 Wayland
- 显示缩放比例（100%、150%……）和所用主题
- 怎么复现：最好附上那份 option；做不到的话，附一个能编译的最小工程
- 看到的和期望的；画得不对的附截图，最好再附一张同一份 option 在 ECharts 里画出来的图

## 功能建议

先看[路线图](https://github.com/ACTom/TyAdvanceChart/milestones)，也许已经在计划里。

说清楚你要用它做什么，比直接给出方案更有用：同一个需求往往有更合适的做法。

## 路线图与发版

每个版本对应一个 Milestone，描述里写这一版主要解决什么；每个大功能有一个跟踪 issue，可以订阅、在下面讨论。

版本只排先后，不定日期。Milestone 做完也不一定马上发版：修复版通常会再等一段时间，确认没有新的问题反馈再发。

## 版本与维护

本项目跟着 TyControls 的版本走：

- TyControls 发布 4.0 之前，本项目依赖 TyControls 的 `main` 分支，不发正式版，版本号一直是 3.99.0。
- 这段时间没有长期支持线，也没有维护分支。
- TyControls 发布 4.0 后，本项目改为依赖 TyControls 4.0，同时发布自己的 4.0，这是第一个正式版。
- 从那以后，本项目的次版本自己安排，但一直兼容 TyControls 最新的稳定版。

4.0 发布以后：

版本号是 `主版本.次版本.修订号`。修订版只修 bug；次版本加新功能，但保持兼容，见下文。

**维护周期**：最新发布的次版本持续修复和发版。上一个次版本也继续收到修复和发版，直到再下一个次版本发布时，发最后一版后停止维护：比如 4.2 发布时发最后一个 4.0.x。严重问题不受此限。

**兼容承诺**：同一主版本内，次版本保证：

- 公开 API 不删、不改签名；要淘汰的先标 `deprecated`，到下一个主版本才删。
- 窗体文件（`.lfm`）里的属性不删、不改名，默认值也不变。
- 老的 `.tycss` 照样能用：图表的 token 名只增不删。
- 不提高最低要求：Lazarus 3.0、FPC 3.2.2。
- 控件的默认尺寸不变，升级不会让界面错位；内置样式的颜色可能微调。

修 bug 不算破坏兼容，哪怕有代码依赖了原来的错误行为。

## 提交代码

改动较大的话，先开 issue 或在已有的 issue 下说一声，免得做完发现方向不合。

**分支**：改动都基于 `main`；较大的功能在特性分支上做完再 merge 回 `main`。

**编译和测试**：

```
lazbuild tests/tyadvchart_tests.lpi
tests/tyadvchart_tests --all --format=plain
```

- lazbuild 要能找到 TyControls 和本项目的包：在 IDE 里装过，或者用 `--add-package-link` 登记过。
- 有几个测试要和 TyControls 的源码对照。把环境变量 `TY_CORE_DIR` 设成 TyControls 的检出目录；不设时这几个测试跳过。

修 bug 请附一个修复前会失败的测试。

**几条硬规矩**：

- 期望值来自真的 ECharts：`tests/fixtures/advchart-*.json` 由 `tools/advchart-oracle/` 下的 node 脚本对 ECharts 6.1 的 dist 跑出来，不要手改；要改就改脚本，再重跑它。
- 颜色、尺寸等视觉值走主题 token，不写死在代码里。图表的 token 和规则写在 `themes/advchart.tycss`，改完跑 `powershell -File scripts/gen-advchart-theme.ps1` 重新生成 `tyControls.AdvanceChart.Theme.pas`。下面两份 fixture 记着 TyControls 读它得出的结果；只有本来就要改变结果时才重新记录，记完看一遍 diff：
  - `tests/fixtures/advchart-theme-baseline.json` 记着每个内置主题在亮、暗两种模式下，对图表每个 token 和主题键解析出的值。`advchart.tycss` 改了，或者 TyControls 的主题改了，它都可能跟着变。在 `tests/` 下跑 `TY_WRITE_BASELINE=1 ./tyadvchart_tests --suite=TAdvChartThemeTest.TestTheThemesResolveAsBefore`（PowerShell 里先 `$env:TY_WRITE_BASELINE='1'`）。
  - `tests/fixtures/advchart-theme-lint.txt` 记着 TyControls 的主题检查器对 `advchart.tycss` 的输出。在 `tests/` 下跑 `TY_WRITE_GOLDEN=1 ./tyadvchart_tests --suite=TAdvChartThemeLintGoldenTest`（PowerShell 里先 `$env:TY_WRITE_GOLDEN='1'`）。
- 自绘界面里不用原生 LCL 控件（`TEdit`、`TButton` 等）。
- 新单元要加进 `tyadvancechart.lpk`（设计期的加进 `tyadvancechart_dt.lpk`）；新测试单元加进 `tests/tyadvchart_tests.lpr`。
- `TTyCustomAdvanceChart` 放全部实现，`TTyAdvanceChart` 只有一段 `published`（做法见 TyControls 的 [subclassing.md](https://github.com/ACTom/TyControls/blob/main/docs/subclassing.md)）。改了 `TTyAdvanceChart` 的 `published` 段，再做两步，各看一遍 diff：
  - 跑 `python scripts/gen-mimic.py`，重新生成 `tests/test.advchart.customclasses.mimic.pas`。diff 里只该有你改的那几行。脚本照抄 `TTyAdvanceChart` **当前**的发布段，别的行变了，说明发布顺序被意外改了——重新生成只会把错的顺序抄过去，不会让它变对。
  - 在 `tests/` 下跑 `TY_WRITE_FRESH_STREAMS=1 ./tyadvchart_tests --suite=TAdvChartCustomClassesGuardTest.TestFreshFormFileTextUnchanged`（PowerShell 里先 `$env:TY_WRITE_FRESH_STREAMS='1'`），更新 `tests/fixtures/customclasses/fresh-streams.txt`。diff 里的每一行，都是新实例写进窗体文件的东西变了。
- 用户可见的文字用 `resourcestring`，放在 `tyControls.AdvanceChart.StrConsts`，并同步更新 `languages/` 下的 zh_CN `.po`。
- 示例用 `.lfm` 窗体，带标题栏，能在运行时换主题。
- 不用比 Lazarus 3.0 更新的 LCL API；必须用时，按 `LCL_FULLVERSION` 给旧版本留一条路。
- 其余照周围代码的写法来。

**提交信息**用英文，格式 `类型(范围): 说明`，例如 `fix(tooltip): the box leaves the chart at the right edge`。修复某个 issue 的，正文里写 `Fixes #N`。

## 更新日志

每个版本的变化记在 [CHANGELOG.md](CHANGELOG.md)。只记用户能感受到的变化，每条都链接对应的 issue；文档、重构、测试这类改动不记。PR 里不用改 CHANGELOG，发版时统一整理。
