unit tyControls.AdvanceChart.Theme;

{ The chart's own tycss (its --advchart-* tokens and its TyAdvChart* rules), compiled into the
  binary and registered in this unit's initialization as the add-on "advchart", so every
  style model's base layer carries it after light.tycss. GENERATED from themes/advchart.tycss
  by scripts/gen-advchart-theme.ps1 - do NOT edit by hand; edit advchart.tycss and re-run the
  generator. Sync-tested byte-identical to advchart.tycss (test.advchart.theme). }

{$mode objfpc}{$H+}

interface

function TyAdvChartCss: string;

implementation

uses
  tyControls.Css.AddOns;

function TyAdvChartCss: string;
begin
  Result :=
    '/* TyAdvanceChart -- advchart.tycss: the chart''s own tokens and rules.' + sLineBreak +
    '' + sLineBreak +
    '   An add-on of the core''s base layer, not a theme of its own. The generated unit' + sLineBreak +
    '   tyControls.AdvanceChart.Theme compiles this file in (scripts/gen-advchart-theme.ps1; never' + sLineBreak +
    '   edit that unit by hand) and registers it in its initialization as the add-on "advchart"' + sLineBreak +
    '   (TyRegisterAddOnCss). Every style model then loads it into its base layer after the whole' + sLineBreak +
    '   of light.tycss and before the per-mode contrast snippet, so every theme, built-in or not,' + sLineBreak +
    '   inherits these keys and tokens where it says nothing of its own, exactly as it did when' + sLineBreak +
    '   they lived in light.tycss. A skin restyles them the way it restyles any other key.' + sLineBreak +
    '' + sLineBreak +
    '   Everything here is said in light.tycss''s vocabulary (--accent, --surface, --on-surface,' + sLineBreak +
    '   --border, --muted, the type scale ...), so a skin that restyles those gets a matching' + sLineBreak +
    '   chart for nothing. */' + sLineBreak +
    '' + sLineBreak +
    ':root {' + sLineBreak +
    '  /* -- size tokens: the chart''s geometry (density phase 3) --' + sLineBreak +
    '     classic value == the chart''s Pascal constant today; a density pack may override' + sLineBreak +
    '     these names. */' + sLineBreak +
    '  --advchart-label-margin: 8px;' + sLineBreak +
    '  --advchart-minor-tick-length: 3px;' + sLineBreak +
    '  --advchart-name-gap: 15px;' + sLineBreak +
    '  --advchart-single-tick-length: 6px;' + sLineBreak +
    '  --advchart-tick-length: 5px;' + sLineBreak +
    '  --advchart-axispointer-margin: 3px;' + sLineBreak +
    '  --advchart-tooltip-gap: 20px;' + sLineBreak +
    '  --advchart-tooltip-gutter: 20px;' + sLineBreak +
    '  --advchart-tooltip-marker: 10px;' + sLineBreak +
    '  --advchart-tooltip-marker-gap: 6px;' + sLineBreak +
    '}' + sLineBreak +
    '' + sLineBreak +
    '/* The chart control itself: the same frame as a panel''s (light.tycss''s TyPanel group). */' + sLineBreak +
    'TyAdvChart {' + sLineBreak +
    '  background: var(--surface);' + sLineBreak +
    '  color: var(--on-surface);' + sLineBreak +
    '  border-color: var(--border);' + sLineBreak +
    '  border-width: var(--input-border-width);' + sLineBreak +
    '  border-radius: var(--radius);' + sLineBreak +
    '  padding: var(--pad-container);' + sLineBreak +
    '}' + sLineBreak +
    '' + sLineBreak +
    '/* AdvChart: the series palette, DERIVED.' + sLineBreak +
    '' + sLineBreak +
    '   Item 18 asks for a derived ramp and this is what that buys: a skin that' + sLineBreak +
    '   restyles --accent gets a matching chart for nothing, and one that restyles' + sLineBreak +
    '   neither still gets a legible one. The eight TyChartSeries* keys in light.tycss are' + sLineBreak +
    '   the OLD chart''s, and they are eight literals -- exactly what makes a chart look' + sLineBreak +
    '   pasted on top of a theme instead of drawn in it.' + sLineBreak +
    '' + sLineBreak +
    '   The ramp walks away from --accent in both directions rather than around a' + sLineBreak +
    '   hue circle, because a hue rotation has no idea what the theme''s accent is for' + sLineBreak +
    '   and lands on colours a brand would not have chosen. Slot 1 IS the accent, so' + sLineBreak +
    '   a single-series chart is drawn in the theme''s own colour.' + sLineBreak +
    '' + sLineBreak +
    '   Eight slots, cycled by (index mod 8), matching the old chart so nothing has' + sLineBreak +
    '   to learn a second rule. */' + sLineBreak +
    'TyAdvChartSeries1 { background: var(--accent); }' + sLineBreak +
    'TyAdvChartSeries2 { background: mix(var(--accent), var(--on-surface), 35%); }' + sLineBreak +
    'TyAdvChartSeries3 { background: lighten(var(--accent), 22%); }' + sLineBreak +
    'TyAdvChartSeries4 { background: darken(var(--accent), 18%); }' + sLineBreak +
    'TyAdvChartSeries5 { background: mix(var(--accent), var(--surface), 40%); }' + sLineBreak +
    'TyAdvChartSeries6 { background: mix(var(--accent), var(--on-surface), 65%); }' + sLineBreak +
    'TyAdvChartSeries7 { background: lighten(var(--accent), 38%); }' + sLineBreak +
    'TyAdvChartSeries8 { background: darken(var(--accent), 34%); }' + sLineBreak +
    'TyAdvChartSeries9 { background: mix(var(--accent), var(--on-surface), 15%); }' + sLineBreak +
    '' + sLineBreak +
    '/* AdvChart: the axis domain. Eight keys and four metrics, and the COUNT is part' + sLineBreak +
    '   of the design -- twelve things can be checked by eye across seventeen themes' + sLineBreak +
    '   and sixty-four cannot, so this is the smallest set that still lets a skin' + sLineBreak +
    '   restyle an axis without touching the control.' + sLineBreak +
    '' + sLineBreak +
    '   Every colour DERIVES from a semantic token the theme already defines. A skin' + sLineBreak +
    '   that restyled --border or --on-surface gets a matching axis for nothing, and' + sLineBreak +
    '   one that restyled neither still gets a legible one. Not a literal anywhere:' + sLineBreak +
    '   a hardcoded grey is exactly what makes a chart look pasted on top of a dark' + sLineBreak +
    '   theme rather than drawn in it.' + sLineBreak +
    '' + sLineBreak +
    '   These are NEW keys, so every existing skin inherits them from this base layer' + sLineBreak +
    '   untouched -- which is the only reason a change this wide is safe to make in' + sLineBreak +
    '   one pass. A skin that later writes any rule for one of them replaces the' + sLineBreak +
    '   whole key, variants included; that is this library''s rule and it is why the' + sLineBreak +
    '   set is small enough to re-check. */' + sLineBreak +
    'TyAdvChartAxisLine  { border-color: var(--border); border-width: 1px; }' + sLineBreak +
    'TyAdvChartAxisTick  { border-color: var(--border); border-width: 1px; }' + sLineBreak +
    '/* [R5-G] a shown grid''s border (grid.show): upstream''s tokens.color.neutral30 */' + sLineBreak +
    'TyAdvChartGridBorder { border-color: #b7b9be; border-width: 1px; }' + sLineBreak +
    '/* Muted, not full ink: an axis label is a reference, not content. --muted is' + sLineBreak +
    '   already alpha over --on-surface, so it follows a dark theme by itself. */' + sLineBreak +
    'TyAdvChartAxisLabel { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartAxisName  { color: var(--on-surface); font-size: var(--font-size-base); }' + sLineBreak +
    '/* The heavier label a TIME axis gives its coarse ticks -- the `Mar` in a run' + sLineBreak +
    '   of day numbers. Upstream carries it as a rich-text style on the time axis''' + sLineBreak +
    '   own defaults; here it is a key of its own so a skin can make the level' + sLineBreak +
    '   marker darker, or larger, or nothing special at all. */' + sLineBreak +
    'TyAdvChartAxisLabelPrimary { color: var(--muted); font-size: var(--font-size-base);' + sLineBreak +
    '                             font-weight: var(--font-weight-bold); }' + sLineBreak +
    '/* Alpha over --border, NEVER over --surface. On an image theme a translucent' + sLineBreak +
    '   surface reads as a bright halo instead of a faint line -- this library has' + sLineBreak +
    '   shipped that bug once already. */' + sLineBreak +
    'TyAdvChartSplitLine { border-color: alpha(var(--border), 0.6); border-width: 1px; }' + sLineBreak +
    '/* The alternating band. Alpha over the ink rather than a grey, so it darkens a' + sLineBreak +
    '   light theme and lightens a dark one from the same declaration. */' + sLineBreak +
    'TyAdvChartSplitArea { background: alpha(var(--on-surface), 0.04); }' + sLineBreak +
    'TyAdvChartMinorTick { border-color: alpha(var(--border), 0.4); border-width: 1px; }' + sLineBreak +
    'TyAdvChartMinorSplitLine { border-color: alpha(var(--border), 0.35); border-width: 1px; }' + sLineBreak +
    '/* The ring a pie draws when it has no data at all. Upstream hard-codes' + sLineBreak +
    '   lightgray; alpha over the ink instead, so it stays faint on either mode. */' + sLineBreak +
    'TyAdvChartEmptyCircle { background: alpha(var(--on-surface), 0.10); }' + sLineBreak +
    '/* showBackground: the strip behind a bar, the height of the plot. Upstream' + sLineBreak +
    '   writes rgba(180,180,180,0.2) into the series default, which is a pale grey' + sLineBreak +
    '   band across a dark skin; alpha over the ink darkens one and lightens the' + sLineBreak +
    '   other from the same declaration. */' + sLineBreak +
    'TyAdvChartBarBackground { background: alpha(var(--on-surface), 0.10); }' + sLineBreak +
    '/* A TREE''S NODES AND EDGES. Upstream names the colours in the series''' + sLineBreak +
    '   defaults -- lightsteelblue for a node, a light grey for an edge -- and a' + sLineBreak +
    '   tree takes no palette slot; here they are keys, so a skin gives its trees' + sLineBreak +
    '   its own accent and its own line ink. */' + sLineBreak +
    'TyAdvChartTreeNode { background: alpha(var(--accent), 0.55); }' + sLineBreak +
    'TyAdvChartTreeEdge { border-color: var(--border); border-width: 1px; }' + sLineBreak +
    '/* A TREEMAP''S LABELS AND ITS BREADCRUMB. Upstream writes the label white --' + sLineBreak +
    '   a fixed ink over palette fills, which do not change with the mode, so' + sLineBreak +
    '   neither does this -- and draws the breadcrumb as a pale chip with' + sLineBreak +
    '   secondary text: here the chip is alpha over the ink and the text muted,' + sLineBreak +
    '   so a dark skin gets a dark chip. */' + sLineBreak +
    'TyAdvChartTreemapLabel { color: #FFFFFF; font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartBreadcrumb { background: alpha(var(--on-surface), 0.08); color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A hovered breadcrumb item. Upstream lifts it to the page''s own ground' + sLineBreak +
    '   (tokens.color.background); the words keep their colour. */' + sLineBreak +
    'TyAdvChartBreadcrumb:hover { background: var(--surface); color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A SANKEY''S LINKS. Upstream fills them a mid grey at 0.2 opacity; here the' + sLineBreak +
    '   grey is the ink''s own muted tone, so a dark skin''s links stay grey on' + sLineBreak +
    '   its ground. */' + sLineBreak +
    'TyAdvChartSankeyLink { background: var(--muted); }' + sLineBreak +
    '/* The chart''s own title and subtitle. Upstream draws them at 18/bold and' + sLineBreak +
    '   12/regular; the sizes come from the type scale here so a dense skin gets a' + sLineBreak +
    '   proportionate title instead of an 18px one on 11px axis labels. */' + sLineBreak +
    '/* [R5-G] border-color: a title box''s default pen (borderWidth above 0) -- upstream''s tokens.color.primary */' + sLineBreak +
    'TyAdvChartTitle { color: var(--on-surface); font-size: var(--font-size-title); font-weight: 700; border-color: #3c3c41; }' + sLineBreak +
    'TyAdvChartSubtitle { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A label OUTSIDE its mark: the theme''s own ink, not anything derived from the' + sLineBreak +
    '   thing it names. Upstream picks #333 or #ccc by mode; this is the same idea' + sLineBreak +
    '   said in the theme''s vocabulary. */' + sLineBreak +
    'TyAdvChartLabel { color: var(--on-surface); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A label INSIDE its mark is a three-band table, not a light/dark pair, and the' + sLineBreak +
    '   order reads backwards until you see why: on a mid-dark fill you want maximum' + sLineBreak +
    '   contrast, but on a nearly black one the brightest ink glares and the dimmer' + sLineBreak +
    '   one is easier to read. Band 1 is therefore LIGHTER than band 2.' + sLineBreak +
    '     band 0 -- a light mark, so dark ink' + sLineBreak +
    '     band 1 -- a mid mark, so the brightest ink' + sLineBreak +
    '     band 2 -- a dark mark, so a softer light ink' + sLineBreak +
    '   FIXED VALUES, NOT THE SURFACE PAIR: the band is chosen by the MARK''s fill,' + sLineBreak +
    '   which does not change with the mode -- so the ink must not either, or a' + sLineBreak +
    '   dark skin puts light ink on a light bar. Upstream''s #333, #eee, #ccc. */' + sLineBreak +
    'TyAdvChartLabelOnLight { color: #333333; }' + sLineBreak +
    'TyAdvChartLabelOnMid   { color: #EEEEEE; }' + sLineBreak +
    'TyAdvChartLabelOnDark  { color: #CCCCCC; }' + sLineBreak +
    '/* The legend. Upstream inks the words with tokens.color.secondary and greys a' + sLineBreak +
    '   deselected item with tokens.color.disabled. This vocabulary has no disabled' + sLineBreak +
    '   INK token -- only a disabled OPACITY -- so a switched-off item is the chart''s' + sLineBreak +
    '   own ink faded far enough to read as off on either mode. The frame is drawn' + sLineBreak +
    '   only when the option asks for one, so the last two are dormant on almost' + sLineBreak +
    '   every chart. */' + sLineBreak +
    'TyAdvChartLegend { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartLegendInactive { color: alpha(var(--on-surface), 0.25); }' + sLineBreak +
    'TyAdvChartLegendBorder { border-color: var(--border); border-width: 1px; }' + sLineBreak +
    'TyAdvChartLegendBackground { background: var(--surface); }' + sLineBreak +
    '/* The legend''s selector buttons (All / Inv) and the scrolling legend''s pager.' + sLineBreak +
    '   Upstream draws a button as tertiary ink in a pale rounded frame that turns' + sLineBreak +
    '   the lighter quaternary ink under the pointer, the page arrows in its accent' + sLineBreak +
    '   with a pale accent for one that cannot go further, and the page count in' + sLineBreak +
    '   the tertiary ink. Here the ink is the chart''s muted one (fainter when' + sLineBreak +
    '   hovered), the frame the border, and the arrows the skin''s own accent. */' + sLineBreak +
    'TyAdvChartLegendSelector { color: var(--muted); border-color: var(--border); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartLegendSelector:hover { color: alpha(var(--on-surface), 0.35); border-color: var(--border); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartLegendPageIcon { color: var(--accent); }' + sLineBreak +
    'TyAdvChartLegendPageIconInactive { color: alpha(var(--accent), 0.25); }' + sLineBreak +
    'TyAdvChartLegendPageText { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A visualMap''s own picture. Upstream inks its texts with tokens.color.' + sLineBreak +
    '   secondary, the bar''s inactive stretch and the frame with a pale grey, the' + sLineBreak +
    '   handles'' rims white and the box transparent. The inactive stretch is the' + sLineBreak +
    '   chart''s own ink faded, like a switched-off legend item; the rim is the' + sLineBreak +
    '   surface, so a handle reads as cut out of whatever it sits on. The frame is' + sLineBreak +
    '   drawn only when the option gives it a width. */' + sLineBreak +
    'TyAdvChartVisualMap { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartVisualMapInactive { color: alpha(var(--on-surface), 0.2); }' + sLineBreak +
    'TyAdvChartVisualMapBorder { border-color: var(--border); }' + sLineBreak +
    'TyAdvChartVisualMapBackground { background: transparent; }' + sLineBreak +
    'TyAdvChartVisualMapHandle { border-color: var(--surface); }' + sLineBreak +
    '/* A slider dataZoom. Upstream tints the whole component from its accent: a' + sLineBreak +
    '   pale frame, the window filled with the accent at a fifth, handles white' + sLineBreak +
    '   with a pale rim, the brush''s move bar the accent at half with a white' + sLineBreak +
    '   grip, and the data shadow grey outside the window and bluer inside it.' + sLineBreak +
    '   Here the accent is the skin''s own, the grey is the ink faded, and white' + sLineBreak +
    '   is the surface. The labels beside the handles take the muted ink. */' + sLineBreak +
    'TyAdvChartDataZoom { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartDataZoomBorder { border-color: var(--border); }' + sLineBreak +
    'TyAdvChartDataZoomBackground { background: transparent; }' + sLineBreak +
    'TyAdvChartDataZoomFiller { background: alpha(var(--accent), 0.2); }' + sLineBreak +
    'TyAdvChartDataZoomHandle { background: var(--surface); border-color: alpha(var(--accent), 0.35); }' + sLineBreak +
    'TyAdvChartDataZoomMoveHandle { background: alpha(var(--accent), 0.5); color: var(--surface); }' + sLineBreak +
    'TyAdvChartDataZoomShadow { background: alpha(var(--on-surface), 0.06); border-color: alpha(var(--on-surface), 0.3); }' + sLineBreak +
    'TyAdvChartDataZoomShadowSelected { background: alpha(var(--accent), 0.12); border-color: alpha(var(--accent), 0.55); }' + sLineBreak +
    '/* Under the pointer (or while a handle is dragged) a handle''s rim darkens' + sLineBreak +
    '   and the move bar firms up; a brush across the body is the accent faded. */' + sLineBreak +
    'TyAdvChartDataZoomHandle:hover { background: var(--surface); border-color: alpha(var(--accent), 0.55); }' + sLineBreak +
    'TyAdvChartDataZoomMoveHandle:hover { background: alpha(var(--accent), 0.8); color: var(--surface); }' + sLineBreak +
    'TyAdvChartDataZoomBrush { background: alpha(var(--accent), 0.3); }' + sLineBreak +
    '/* The toolbox. Upstream draws its icons as hairline outlines in the accent,' + sLineBreak +
    '   a deeper accent under the pointer, and the title that appears below the' + sLineBreak +
    '   icon takes that same deeper ink; the bar itself has no ground and no' + sLineBreak +
    '   frame unless the option asks. The rectangle a zoom drag sweeps out is the' + sLineBreak +
    '   accent faded right down. */' + sLineBreak +
    'TyAdvChartToolbox { border-color: var(--accent); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartToolbox:hover { border-color: darken(var(--accent), 25%); }' + sLineBreak +
    'TyAdvChartToolboxBackground { background: transparent; }' + sLineBreak +
    'TyAdvChartToolboxBorder { border-color: var(--border); }' + sLineBreak +
    'TyAdvChartToolboxBrush { background: alpha(var(--accent), 0.15); }' + sLineBreak +
    '/* The brush component''s covers. Upstream lays a pale tint over what it' + sLineBreak +
    '   selects and rims it in a light grey; here the ink faded right down and' + sLineBreak +
    '   the skin''s own border colour. */' + sLineBreak +
    'TyAdvChartBrush { background: alpha(var(--on-surface), 0.06); border-color: var(--border); }' + sLineBreak +
    '/* The timeline. Upstream builds the whole slider from its accent in steps:' + sLineBreak +
    '   the axis line palest, the passed part of it a little deeper, the ticks' + sLineBreak +
    '   deeper again and a passed tick deeper still, the checkpoint and the' + sLineBreak +
    '   buttons the accent itself; under the pointer a tick, a button and a label' + sLineBreak +
    '   take a darker accent. The labels are the muted ink; an empty symbol''s' + sLineBreak +
    '   inside is the surface. */' + sLineBreak +
    'TyAdvChartTimeline { border-color: alpha(var(--accent), 0.2); background: var(--surface); }' + sLineBreak +
    'TyAdvChartTimelineProgress { border-color: alpha(var(--accent), 0.45); background: alpha(var(--accent), 0.65); }' + sLineBreak +
    'TyAdvChartTimelineItem { background: alpha(var(--accent), 0.3); }' + sLineBreak +
    'TyAdvChartTimelineItem:hover { background: darken(var(--accent), 10%); border-color: darken(var(--accent), 10%); }' + sLineBreak +
    'TyAdvChartTimelineCheckpoint { background: var(--accent); border-color: var(--accent); }' + sLineBreak +
    'TyAdvChartTimelineControl { background: var(--accent); border-color: var(--accent); }' + sLineBreak +
    'TyAdvChartTimelineControl:hover { background: darken(var(--accent), 25%); border-color: darken(var(--accent), 25%); }' + sLineBreak +
    'TyAdvChartTimelineLabel { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartTimelineLabel:hover { color: darken(var(--accent), 10%); }' + sLineBreak +
    '/* What a brush leaves out. Upstream greys the items outside every cover in a' + sLineBreak +
    '   light neutral; here the skin''s border colour, which is that neutral. */' + sLineBreak +
    'TyAdvChartBrushOut { color: var(--border); }' + sLineBreak +
    '/* A parallel axis'' area select: the band a drag along the axis leaves.' + sLineBreak +
    '   Upstream fills and rims it in one light blue at 30% opacity (the opacity' + sLineBreak +
    '   is the chart''s, not the skin''s); here the accent halfway to the surface. */' + sLineBreak +
    'TyAdvChartParallelSelect { background: mix(var(--accent), var(--surface), 50%); border-color: mix(var(--accent), var(--surface), 50%); }' + sLineBreak +
    '/* A thumbnail''s box: the small copy of a graph in its corner. Upstream fills' + sLineBreak +
    '   it with the option''s backgroundColor, else its neutral00 token, and rims' + sLineBreak +
    '   it in its border token; here the skin''s surface and border. An author''s' + sLineBreak +
    '   itemStyle colours win. */' + sLineBreak +
    'TyAdvChartThumbnail { background: var(--surface); border-color: var(--border); }' + sLineBreak +
    '/* The window over the copy, where the canvas looks. Upstream fills it with' + sLineBreak +
    '   neutral30 and rims it with neutral40 (the 0.3 opacity is the option''s);' + sLineBreak +
    '   here the skin''s border, rimmed a step toward the ink. */' + sLineBreak +
    'TyAdvChartThumbnailWindow { background: var(--border); border-color: mix(var(--on-surface), var(--border), 25%); }' + sLineBreak +
    '/* An axis break''s area: the zigzag band where a stretch of the axis is cut' + sLineBreak +
    '   out, over the series. Upstream fills it white at 60% and rims it in its' + sLineBreak +
    '   border grey, dashed; here the skin''s surface at 60% and its border, so a' + sLineBreak +
    '   dark skin''s breaks are dark. The dash is the option''s (3, 3 by default). */' + sLineBreak +
    'TyAdvChartBreakArea { background: alpha(var(--surface), 0.6); border-color: var(--border); border-width: 1px; }' + sLineBreak +
    '/* A geo component''s map. Upstream fills a region with its backgroundTint' + sLineBreak +
    '   token (a pale blue-grey at half), rims it in its border grey at half a' + sLineBreak +
    '   pixel and, when the option shows them, writes the region names in its' + sLineBreak +
    '   tertiary ink. Here a tenth of the accent in the surface, so a dark' + sLineBreak +
    '   skin''s map is a dark one, the skin''s border, and the muted ink. The' + sLineBreak +
    '   half-pixel rim is the option''s. */' + sLineBreak +
    'TyAdvChartGeoArea { background: mix(var(--accent), var(--surface), 90%); border-color: var(--border); }' + sLineBreak +
    'TyAdvChartGeoLabel { color: var(--muted); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A map series'' regions. Upstream fills them with its background token (a' + sLineBreak +
    '   near-white blue, lighter than a geo component''s tint) and rims them in' + sLineBreak +
    '   the same border grey; here a twentieth of the accent in the surface, a' + sLineBreak +
    '   shade lighter than a geo''s, and the skin''s border. */' + sLineBreak +
    'TyAdvChartMapArea { background: mix(var(--accent), var(--surface), 95%); border-color: var(--border); }' + sLineBreak +
    '/* A hovered or selected region and its name. Upstream fills it with its' + sLineBreak +
    '   highlight token (a warm yellow at 80%) and writes the name in its primary' + sLineBreak +
    '   ink; here a third of the accent in the surface and the skin''s own text' + sLineBreak +
    '   colour, so the region stands out in any skin. */' + sLineBreak +
    'TyAdvChartGeoArea:hover { background: mix(var(--accent), var(--surface), 65%); border-color: var(--border); }' + sLineBreak +
    'TyAdvChartGeoLabel:hover { color: var(--on-surface); font-size: var(--font-size-base); }' + sLineBreak +
    '/* A decal''s symbols, where the decal names no colour of its own -- the aria' + sLineBreak +
    '   decals that tell the series apart without their colours. Upstream draws' + sLineBreak +
    '   them rgba(0, 0, 0, 0.2): the readable ink of the surface at 20%, which on' + sLineBreak +
    '   the light skin''s white is exactly that, and white at 20% on a dark one.' + sLineBreak +
    '   An `empty*` symbol in the pattern is a hollow over the background:' + sLineBreak +
    '   upstream''s neutral00 (#fff), the surface here -- exactly that on the' + sLineBreak +
    '   light skin, and no white hole on a dark one. */' + sLineBreak +
    'TyAdvChartDecal { color: alpha(on(var(--surface)), 0.2); background: var(--surface); }' + sLineBreak +
    '/* The item the keyboard holds. Upstream has no keyboard, so this is the' + sLineBreak +
    '   library''s own focus ring, drawn around the mark: the skin''s focus ring, at' + sLineBreak +
    '   the width the other controls draw theirs. The offset follows the library''s' + sLineBreak +
    '   ring convention (a positive one insets the ring), so a negative one sets it' + sLineBreak +
    '   off the mark. */' + sLineBreak +
    'TyAdvChartFocusItem { outline: 2px var(--focus-ring); outline-offset: -3px; }' + sLineBreak +
    '/* The hover tooltip. TWO keys, because upstream''s whole typographic hierarchy' + sLineBreak +
    '   inside the box is one weight difference -- the name at 400 and the value at' + sLineBreak +
    '   900, in the same grey -- and one style set cannot say two weights. Said here' + sLineBreak +
    '   in this vocabulary''s own terms instead: the name is the muted ink a label' + sLineBreak +
    '   takes, the value is full ink and bold.' + sLineBreak +
    '' + sLineBreak +
    '   The chart paints NO box without a background on the first key (no surface =' + sLineBreak +
    '   nothing to draw on), which is the same rule TyChartTooltip follows, and it' + sLineBreak +
    '   is why both live in the base layer for every theme to inherit. A skin' + sLineBreak +
    '   wanting the box to float adds `shadow:`; the base stays flat like the rest' + sLineBreak +
    '   of light. The BORDER here is only the fallback -- an item tooltip tints its' + sLineBreak +
    '   border with the colour of the datum under the pointer, which is what makes' + sLineBreak +
    '   an ECharts tooltip look attached to the thing it describes. */' + sLineBreak +
    'TyAdvChartTooltip {' + sLineBreak +
    '  background: var(--surface);' + sLineBreak +
    '  color: var(--muted);' + sLineBreak +
    '  border-color: var(--border);' + sLineBreak +
    '  border-width: var(--input-border-width);' + sLineBreak +
    '  border-radius: var(--radius-sm);' + sLineBreak +
    '  padding: var(--pad-tooltip);' + sLineBreak +
    '  font-size: var(--font-size-base);' + sLineBreak +
    '}' + sLineBreak +
    'TyAdvChartTooltipValue {' + sLineBreak +
    '  color: var(--on-surface);' + sLineBreak +
    '  font-size: var(--font-size-base);' + sLineBreak +
    '  font-weight: var(--font-weight-bold);' + sLineBreak +
    '}' + sLineBreak +
    '/* The axis pointer: the line that follows the cursor along an axis, the band' + sLineBreak +
    '   a `shadow` draws instead, and the label at the axis end.' + sLineBreak +
    '' + sLineBreak +
    '   The line reads like a split line and not like an axis line -- it is a' + sLineBreak +
    '   reading aid over the plot, not a piece of the frame -- so it takes the same' + sLineBreak +
    '   --border it does. The BAND is alpha over the ink for the reason every other' + sLineBreak +
    '   band in this chart is: it darkens a light theme and lightens a dark one from' + sLineBreak +
    '   one declaration, where upstream''s literal rgba grey does neither.' + sLineBreak +
    '' + sLineBreak +
    '   The LABEL is the one piece here that is meant to stand out: upstream inks it' + sLineBreak +
    '   white on an indigo chip, which is a colour this vocabulary already has a' + sLineBreak +
    '   name for. Accent, therefore -- so a re-skinned chart labels its pointer in' + sLineBreak +
    '   the skin''s own colour instead of ECharts''. */' + sLineBreak +
    '/* A candlestick''s two directions. NOT "positive and negative" however they are' + sLineBreak +
    '   usually described: both compare a datum against ITSELF -- close above open' + sLineBreak +
    '   against open above close -- and either can happen in a rising market.' + sLineBreak +
    '' + sLineBreak +
    '   Upstream writes #eb5454 and #47b262, which is the East Asian convention' + sLineBreak +
    '   (red up, green down) and the opposite of the North American one. This' + sLineBreak +
    '   library has a --success and a --danger already and they carry exactly the' + sLineBreak +
    '   right meaning in either convention, so a theme that wants the other way' + sLineBreak +
    '   round swaps two lines here instead of restyling a chart. */' + sLineBreak +
    '/* A GAUGE''S READING: the headline number under the needle, and the only thing' + sLineBreak +
    '   in this vocabulary that had no donor. The chart''s own title key is bold but' + sLineBreak +
    '   is sized off the title scale -- a gauge''s reading is the picture, not a' + sLineBreak +
    '   heading over it -- and every label key is base size. Upstream writes 30px' + sLineBreak +
    '   and a literal here is the right place for a literal: a skin that wants a' + sLineBreak +
    '   quieter dial changes this one line. The gauge''s name caption takes' + sLineBreak +
    '   TyAdvChartLabel, its scale takes TyAdvChartAxisLabel, its major ticks take' + sLineBreak +
    '   TyAdvChartAxisTick and its minor ones TyAdvChartMinorTick, so this is the' + sLineBreak +
    '   only key the whole series added. */' + sLineBreak +
    'TyAdvChartGaugeDetail { color: var(--on-surface); font-size: 30px;' + sLineBreak +
    '                        font-weight: var(--font-weight-bold); }' + sLineBreak +
    'TyAdvChartCandleUp { background: var(--danger); }' + sLineBreak +
    'TyAdvChartCandleDown { background: var(--success); }' + sLineBreak +
    'TyAdvChartAxisPointer { border-color: var(--border); border-width: 1px; }' + sLineBreak +
    'TyAdvChartAxisPointerShadow { background: alpha(var(--on-surface), 0.10); }' + sLineBreak +
    '/* [R5-A] upstream''s tokens.color.shadow (light and dark alike): the colour of' + sLineBreak +
    '   the shadows a series or a component casts by default -- a boxplot''s' + sLineBreak +
    '   emphasis, a continuous visualMap''s indicator */' + sLineBreak +
    'TyAdvChartShadow { color: rgba(0, 0, 0, 0.2); }' + sLineBreak +
    'TyAdvChartAxisPointerLabel {' + sLineBreak +
    '  background: var(--accent);' + sLineBreak +
    '  color: var(--on-accent);' + sLineBreak +
    '  border-radius: var(--radius-sm);' + sLineBreak +
    '  padding: 5px 7px;' + sLineBreak +
    '  font-size: var(--font-size-base);' + sLineBreak +
    '}' + sLineBreak +
    '/* The loading effect (showLoading): the mask over the chart, its words, and' + sLineBreak +
    '   the turning arc. Upstream writes a white mask at 0.8, its darkest neutral' + sLineBreak +
    '   for the words and the first palette colour for the arc -- on a light skin' + sLineBreak +
    '   exactly this, and on a dark one a mask of its own surface instead of a' + sLineBreak +
    '   white sheet over a dark chart. The arc''s width and radius are geometry the' + sLineBreak +
    '   cfg sets (5 and 10 by default); only its colour is the skin''s. */' + sLineBreak +
    'TyAdvChartLoading { background: alpha(var(--surface), 0.8); color: var(--on-surface);' + sLineBreak +
    '                    font-size: var(--font-size-base); }' + sLineBreak +
    'TyAdvChartLoadingSpinner { border-color: var(--accent); }' + sLineBreak;
end;

initialization
  TyRegisterAddOnCss('advchart', TyAdvChartCss);

end.
