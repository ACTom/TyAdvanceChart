unit test.advchart.builtinthemes;
{$mode objfpc}{$H+}

{ The chart's axis domain in every theme TyControls compiles in, both modes.

  TyControls' test.builtinthemes held this as TestEveryBuiltinDrawsAVisibleAxis until the chart
  moved here. The themes are the core's (tyControls.BuiltinThemes); the rules that style the
  axis are the chart's own add-on, themes/advchart.tycss, which tyControls.AdvanceChart.Theme
  registers -- a model loaded from a built-in theme resolves them through it. }

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  tyControls.Types, tyControls.StyleModel, tyControls.BuiltinThemes,
  tyControls.AdvanceChart.Theme;

type
  TAdvChartBuiltinThemesTest = class(TTestCase)
  published
    procedure TestEveryBuiltinDrawsAVisibleAxis;
  end;

implementation

{ Asserting merely that these keys RESOLVE would be fake-green: the compiled-in base backs every
  theme.

  "Distinguishable from the surface" was the first attempt and it was fake-green
  too, which a mutation proved: hardcoding the exact grey the spec warns against
  did not fail it, because a mid grey is distinguishable from a light background
  AND from a dark one. It asserted something true and not the thing that
  matters.

  What matters is that the axis chrome FOLLOWS the theme. So this asserts the
  derivation instead: the axis line and the minor tick both come from --border,
  so their colour channels must be identical while their alphas differ, and the
  split line must be fainter than the line it accompanies. A colour hardcoded
  anywhere in that group breaks the relationship in every theme whose --border
  is not that literal -- which is all of them but one. }
procedure TAdvChartBuiltinThemesTest.TestEveryBuiltinDrawsAVisibleAxis;

  function Rgb(c: TTyColor): Cardinal;
  begin
    Result := c and $00FFFFFF;
  end;

  function Alpha(c: TTyColor): Integer;
  begin
    Result := (c shr 24) and $FF;
  end;

  procedure CheckMode(m: TTyStyleModel; const AName, AMode: string);
  var
    line, minor, split, lbl: TTyStyleSet;
  begin
    m.SetMode(AMode);

    line := m.ResolveStyle('TyAdvChartAxisLine', '', []);
    AssertTrue(Format('%s (%s): the axis line has no colour', [AName, AMode]),
      tpBorderColor in line.Present);
    minor := m.ResolveStyle('TyAdvChartMinorTick', '', []);
    AssertTrue(Format('%s (%s): no minor tick colour', [AName, AMode]),
      tpBorderColor in minor.Present);
    split := m.ResolveStyle('TyAdvChartSplitLine', '', []);
    AssertTrue(Format('%s (%s): no split line colour', [AName, AMode]),
      tpBorderColor in split.Present);

    { The derivation, which is the whole claim: all three come from --border, so
      the hue is one hue and only the alpha separates them. }
    AssertEquals(Format('%s (%s): the minor tick is not derived from the same '
      + 'token as the axis line', [AName, AMode]),
      Rgb(line.BorderColor), Rgb(minor.BorderColor));
    AssertEquals(Format('%s (%s): the split line is not derived from it either',
      [AName, AMode]), Rgb(line.BorderColor), Rgb(split.BorderColor));
    AssertTrue(Format('%s (%s): the minor tick is not fainter than the axis line',
      [AName, AMode]), Alpha(minor.BorderColor) < Alpha(line.BorderColor));
    AssertTrue(Format('%s (%s): the split line is not fainter than the axis line',
      [AName, AMode]), Alpha(split.BorderColor) < Alpha(line.BorderColor));

    lbl := m.ResolveStyle('TyAdvChartAxisLabel', '', []);
    AssertTrue(Format('%s (%s): the axis label has no colour', [AName, AMode]),
      tpTextColor in lbl.Present);

    { The remaining three only have to EXIST. }
    AssertTrue(Format('%s (%s): no tick colour', [AName, AMode]),
      tpBorderColor in m.ResolveStyle('TyAdvChartAxisTick', '', []).Present);
    AssertTrue(Format('%s (%s): no axis name colour', [AName, AMode]),
      tpTextColor in m.ResolveStyle('TyAdvChartAxisName', '', []).Present);
    AssertTrue(Format('%s (%s): no split area', [AName, AMode]),
      tpBackground in m.ResolveStyle('TyAdvChartSplitArea', '', []).Present);
    AssertTrue(Format('%s (%s): no minor split line', [AName, AMode]),
      tpBorderColor in m.ResolveStyle('TyAdvChartMinorSplitLine', '', []).Present);
  end;

var n: TStringArray; i: Integer; m: TTyStyleModel;
begin
  n := TyBuiltinThemeNames;
  AssertTrue('there are themes to check', Length(n) > 0);
  for i := 0 to High(n) do
  begin
    m := TTyStyleModel.Create;
    try
      m.LoadFromCss(TyBuiltinThemeCss(n[i]));
      CheckMode(m, n[i], 'light');
      CheckMode(m, n[i], 'dark');
    finally m.Free; end;
  end;
end;

initialization
  RegisterTest(TAdvChartBuiltinThemesTest);
end.
