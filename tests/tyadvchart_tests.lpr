program tyadvchart_tests;

{ The TyAdvanceChart test runner. It is TyControls' tests/tytests.lpr (at 77860b40)
  with only the AdvChart test units and their support units: the same console runner,
  the same --list / --suite / --format options, the same pins before the first test. }

{$mode objfpc}{$H+}

uses
  Interfaces, consoletestrunner, Graphics, Forms, tyControls.Painter, tyControls.Controller,
  tyControls.Calendar,
  test.devicescale.support, test.danglingrefs, test.designregistry, test.dpi.support,
  test.advchart.types, test.advchart.scale, test.advchart.scale.break, test.advchart.scale.ordinal,
  test.advchart.coord, test.advchart.layout, test.advchart.axis, test.advchart.measure,
  test.advchart.shape, test.advchart.paint, test.advchart.marks, test.advchart.barlayout,
  test.advchart.stack, test.advchart.symbol, test.advchart.pie, test.advchart.title,
  test.advchart.labels, test.advchart.pielabel, test.advchart.legend, test.advchart.dataset,
  test.advchart.furniture, test.advchart.color, test.advchart.multiaxis, test.advchart.time,
  test.advchart.axislabel, test.advchart.gallery, test.advchart.hostileoptions, test.advchart.hit,
  test.advchart.tooltip, test.advchart.axispointer, test.advchart.emphasis,
  test.advchart.candlestick, test.advchart.funnel, test.advchart.gauge, test.advchart.radar,
  test.advchart.pictorial, test.advchart.graph, test.advchart.graphforce,
  test.advchart.graphlegend, test.advchart.graphcartesian, test.advchart.valueaxis,
  test.advchart.labeltext, test.advchart.seriestext, test.advchart.bargeometry,
  test.advchart.gridbounds, test.advchart.axisnames, test.advchart.jsmath,
  test.advchart.labelthinning, test.advchart.containshape, test.advchart.coordaffine,
  test.advchart.categoryminmax, test.advchart.graphroam, test.advchart.graphfocus,
  test.advchart.insidelabel, test.advchart.scalealign, test.advchart.rawvalue,
  test.advchart.subrows, test.advchart.boxmerge, test.advchart.parsevalue, test.advchart.visualmap,
  test.advchart.visualmapview, test.advchart.visualmapchannels, test.advchart.visualmappiecewise,
  test.advchart.visualmappiecewiseview, test.advchart.datazoomwindow, test.advchart.datazoomslider,
  test.advchart.datazoominteract, test.advchart.linesmooth, test.advchart.markerslayout,
  test.advchart.markline, test.advchart.markpoint, test.advchart.markarea, test.advchart.heatmap,
  test.advchart.calendar, test.advchart.heatmapcal, test.advchart.seriescal, test.advchart.tree,
  test.advchart.treeinteract, test.advchart.handlerwiring, test.advchart.textstyle,
  test.advchart.mouseevents, test.advchart.richtext, test.advchart.richwiring,
  test.advchart.axisstringsize, test.advchart.sunburst, test.advchart.treemap,
  test.advchart.sankey, test.advchart.select, test.advchart.focusblur, test.advchart.legendact,
  test.advchart.legendscroll, test.advchart.tooltipfinish, test.advchart.axisfinish,
  test.advchart.animengine, test.advchart.animenter, test.advchart.animupdate,
  test.advchart.animlabels, test.advchart.optionmerge, test.advchart.animstate,
  test.advchart.animstate2, test.advchart.statesmisc, test.advchart.statesmarks,
  test.advchart.animfullupdate, test.advchart.animmerge, test.advchart.sampling,
  test.advchart.timeformat, test.advchart.palettefill, test.advchart.exportloading,
  test.advchart.media, test.advchart.candleboxplot, test.advchart.labellayout,
  test.advchart.convertjitter, test.advchart.polaraxes, test.advchart.polarseries,
  test.advchart.pieavoid, test.advchart.labelline, test.advchart.graphsankeyinteract,
  test.advchart.visualmapinteract, test.advchart.largemode, test.advchart.progressive,
  test.advchart.lines, test.advchart.toolbox, test.advchart.dataviewhandlers,
  test.advchart.brushcover, test.advchart.brushselect, test.advchart.parallel,
  test.advchart.parallelbrush, test.advchart.decalaria, test.advchart.axisbreaks,
  test.advchart.sunbursttreemapinteract, test.advchart.singlethemeriver, test.advchart.chord,
  test.advchart.graphic, test.advchart.customseries, test.advchart.customseries2,
  test.advchart.timeline, test.advchart.timelinemulti, test.advchart.datasettransform,
  test.advchart.stattransforms, test.advchart.morph, test.advchart.universaltransition,
  test.advchart.universaltransition2, test.advchart.universaltransition3,
  test.advchart.realtimesort, test.advchart.thumbnailaxisexpand, test.advchart.keyframeanimation,
  test.advchart.connectlink, test.advchart.coarsedirty, test.advchart.keyboard,
  test.advchart.matrix, test.advchart.matrix2, test.advchart.matrix3, test.advchart.boxusage,
  test.advchart.boxusage2, test.advchart.tooltipactions, test.advchart.geo,
  test.advchart.geointeract, test.advchart.georoam, test.advchart.geoseries, test.advchart.geosvg,
  test.advchart.stateshier, test.advchart.cursor, test.advchart.decalseries,
  test.advchart.axisbreaks2, test.advchart.compkeys, test.advchart.animengine2,
  test.advchart.animupdate2, test.advchart.graphdrag2, test.advchart.chordselect,
  test.advchart.universaltransition4, test.advchart.animupdate3, test.advchart.animupdate4,
  test.advchart.animupdate5, test.advchart.animupdate6, test.advchart.universaltransition5,
  test.advchart.universaltransition6, test.advchart.seriespenends, test.advchart.seriesborders,
  test.advchart.gaugetext, test.advchart.hitstroke, test.advchart.linescanvas,
  test.advchart.viewlayers, test.advchart.canvasborders, test.advchart.canvasstates,
  test.advchart.pathicons, test.advchart.penmap, test.advchart.gaugereads,
  test.advchart.sankeyroamtween, test.advchart.galleryrenderitem, test.advchart.callbacks,
  test.advchart.titlelist, test.advchart.render, test.advchart.proglayers,
  test.advchart.traillayer, test.advchart.stringidentity, test.advchart.p2perf,
  test.advchart.tooltipkeep, test.advchart.axisownpointer, test.advchart.tiphtml,
  test.advchart.tooltipparams, test.advchart.actionsbatch, test.advchart.rootinherit,
  test.advchart.dataedge, test.advchart.axistooltip, test.advchart.visualmaptext,
  test.advchart.fontstyle, test.advchart.labelhalo, test.advchart.textdash,
  test.advchart.authorstyles, test.advchart.richimage, test.advchart.halokeep,
  test.advchart.faststrokes, test.advchart.shadows, test.advchart.edgesgeo,
  test.advchart.largespeed, test.advchart.parsekeep, test.advchart.speedkeep,
  test.advchart.hoverlayer, test.advchart.edgesseries, test.advchart.edgesinteract,
  test.advchart.edgesinteract2, test.advchart.radarlabel, test.advchart.pieitemlabel,
  test.advchart.labelfontstates, test.advchart.labelstatecfg, test.advchart.linetempsymbol,
  test.advchart.labellinestates, test.advchart.legenditemown, test.advchart.legendstyles,
  test.advchart.rootstyles, test.advchart.reachstyles, test.advchart.imageshadow,
  test.advchart.legendtooltip, test.advchart.animedges, test.advchart.timelinetick,
  test.advchart.axisemphasis, test.advchart.brushstyle, test.advchart.loadingpointer,
  test.advchart.handleemphasis, test.advchart.toolboxextra, test.advchart.edgesaxes,
  test.advchart.edgesmisc, test.advchart.backwardcompat, test.advchart.labelguides,
  test.advchart.effecthover, test.advchart.labellayoutsize, test.advchart.geolabels,
  test.advchart.georoamtween, test.advchart.timelinelabels, test.advchart.multiline,
  test.advchart.jsregexp, test.advchart.graphictip, test.advchart.rendergaps,
  test.advchart.axisevents, test.advchart.option, test.advchart.catalog, test.advchart.complete,
  test.advchart.locate, test.advchart.diagnose, test.advchart.serieseditor, test.advchart.handlers,
  test.advchart.data, test.advchart.builder, test.advchart.series, test.advchart.style,
  test.advancechart, test.advchart.devicescale, test.advchart.themedump, test.advchart.theme,
  test.advchart.i18n,
  test.advchart.coredir, test.advchart.version, test.advchart.customclasses.mimic,
  test.advchart.customclasses, test.advchart.designeditors, test.advchart.defaults,
  test.advchart.tabstop, test.advchart.controlfont, test.advchart.release, test.advchart.themekeys,
  test.advchart.builtinthemes, test.advchart.themelint, test.advchart.danglingrefs,
  test.advchart.componentleaks, test.advchart.freewhileownerlives, test.advchart.wheelevents,
  test.advchart.measurefont, test.advchart.paletteicons, test.advchart.dpicontrols,
  test.advchart.runnerstate;

type
  TTyTestRunner = class(TTestRunner)
  protected
  end;

var
  Application: TTyTestRunner;

begin
  // FIFTH, and done FIRST: the WIDGETSET. The console runner never initialises it on its
  // own, so a window class is not registered and the first CreateHandle fails with
  // "Failed to create win32 control" (1407). Tests used to initialise it lazily, each unit
  // through its own NeedWidgetSet -- so a suite that forgot passed in the full run only
  // because an earlier suite had done it, and every suite after the first initialiser
  // measured its text with the real fonts while the ones before it did not. Initialise it
  // here, before any test, so every process starts in the same state whichever suite it
  // runs first: a suite run on its own sees what it sees in the full run. It goes before
  // the pins below because initialising reads the desktop into ScreenInfo (its PPI among
  // them); the pins must be what is left standing. tests/test.advchart.runnerstate holds the
  // runner to all of it. (Forms. because Application below is the test runner.)
  Forms.Application.Initialize;
  // Headless determinism: keep the empty-FontName render path so position-
  // sensitive pixel tests are unaffected by the real system font. Disable the
  // controller's system-font fallback BEFORE any controller is created, and
  // force the fallback name empty. (The runner links the LCL widgetset, so
  // Screen.SystemFont is real here -- without this gate it would leak in.)
  TyAutoSystemFontFallback := False;
  TyFallbackFontName := '';
  // Same reason, second source of machine-dependence: TTyCalendar.FirstDayOfWeek
  // defaults to wdLocaleDefault, which tyControls.Calendar resolves from the OS at
  // unit start. Every calendar geometry assertion would otherwise be measuring the
  // developer's Control Panel -- a Monday-first machine shifts the whole day grid by
  // one column. Pin it here so a new calendar test cannot inherit the machine's
  // answer by omission; the one test that is ABOUT locale resolution overrides this
  // variable itself and restores it.
  //
  // The THIRD source of machine-dependence -- month/weekday NAMES -- needs no pin
  // here, because its default already resolves deterministically in this process:
  // TyDateTimeNameSource = dnAuto renders DefaultFormatSettings' names unless a
  // catalogue is loaded, and no test leaves one loaded (test.calendar's
  // TearDown restores the rsTyDateTimeNamesLang sentinel it translates; the
  // AutoWithNothingLoadedFollowsTheLocale precondition enforces the contract).
  // A test whose ASSERTION mentions a month or weekday name must not read the
  // machine's names into its expected value blind: either force
  // TyDateTimeNameSource := dnTranslation (fixed English resourcestrings,
  // machine-independent) or pin DefaultFormatSettings locally -- save, poke,
  // restore, as test.chart does for the numeric separators. Both knobs are
  // plain globals precisely so tests can inject them.
  TyLocaleFirstDayOfWeek := wdSunday;
  // FOURTH: the SCREEN. LCL creates every TFont at ScreenInfo's PPI, a form built with
  // CreateNew keeps the one it was born with, and its ParentFont children take it over --
  // so the screen decides the PPI of every control a test did not pin. Left alone it is
  // whatever this machine's desktop is (initialising the widgetset, FIFTH above, reads it
  // in; before that, the LCL default of 72, a desktop nobody has). Make it the 96-PPI
  // desktop the expectations in these suites are written for. A test that is ABOUT
  // another scaling sets these itself and puts them back (tests/test.dpi.measurefont).
  ScreenInfo.PixelsPerInchX := 96;
  ScreenInfo.PixelsPerInchY := 96;
  Screen.UpdateScreen;
  Application := TTyTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'TyAdvanceChart Test Runner';
  Application.Run;
  Application.Free;
end.
