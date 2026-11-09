unit test.advchart.controlfont;
{ TyControls #92, for the chart's control unit: a control's own Font is laid over the theme's
  style (TyApplyControlFont), and italic, underline and strikeout ride on the weight every text
  call passes, above the CSS weight's range. So `FontWeight >= 600` would call an italic regular
  font bold: every reading of a weight as a number goes through TyFontWeightOf or
  TyFontStylesOf. TyControls' test.controlfont reads every unit of its source/ for a reader that
  forgot; the chart's control unit was read with them until it moved here.

  The chart's model units (tyControls.AdvanceChart.*.pas, but not the control's own
  tyControls.AdvanceChart.pas) are left out, as they were there: their FontWeight is an ECharts
  text style's CSS weight, read from the option or resolved per chart part through the model --
  never a control's CurrentStyle, the one style the flags are laid on. }
{$mode objfpc}{$H+}
interface

uses
  Classes, SysUtils, FileUtil, fpcunit, testregistry, test.dpi.support;

type
  TAdvChartControlFontTest = class(TTestCase)
  published
    procedure TestNoUnitReadsTheWeightAsANumber;
  end;

implementation

procedure TAdvChartControlFontTest.TestNoUnitReadsTheWeightAsANumber;
var files, sl: TStringList;
  i, j, models: Integer;
  ln, lc, bad: string;
  sawControl: Boolean;

  { `fontweight = ` / `aweight = ` followed by a number }
  function EqualsANumber(const AKey: string): Boolean;
  var k: Integer;
  begin
    k := Pos(AKey, lc);
    Result := (k > 0) and (k + Length(AKey) <= Length(lc))
      and (lc[k + Length(AKey)] in ['0'..'9', '$']);
  end;

begin
  files := FindAllFiles(TyTestRepoRoot + 'source', '*.pas', True);
  sl := TStringList.Create;
  try
    AssertTrue('the sources were found', files.Count > 100);
    bad := '';
    sawControl := False;
    models := 0;
    for i := 0 to files.Count - 1 do
    begin
      if (Pos('tycontrols.advancechart.', LowerCase(ExtractFileName(files[i]))) = 1)
        and not SameText(ExtractFileName(files[i]), 'tyControls.AdvanceChart.pas') then
      begin
        Inc(models);
        Continue;
      end;
      if SameText(ExtractFileName(files[i]), 'tyControls.AdvanceChart.pas') then sawControl := True;
      sl.LoadFromFile(files[i]);
      sl.Text := TyTestCodeOnly(sl.Text);   // prose about a weight is not a reading of one
      for j := 0 to sl.Count - 1 do
      begin
        ln := sl[j];
        lc := LowerCase(Trim(ln));
        if lc = '' then Continue;
        if (Pos('tyfontweightof', lc) > 0) or (Pos('tyfontstylesof', lc) > 0) then Continue;
        if ((Pos('fontweight', lc) > 0) or (Pos('aweight', lc) > 0))
          and ((Pos('>= ', lc) > 0) or (Pos('<= ', lc) > 0) or (Pos(' > ', lc) > 0)
            or (Pos(' < ', lc) > 0) or EqualsANumber('fontweight = ')
            or EqualsANumber('aweight = ')) then
          bad := bad + LineEnding + ExtractFileName(files[i]) + ':' + IntToStr(j + 1) + ': '
            + Trim(ln);
      end;
    end;
    AssertTrue('the control''s own unit was read', sawControl);
    AssertTrue('the units left out are the model''s (' + IntToStr(models) + ')', models > 100);
    AssertEquals('weights read as numbers outside TyFontWeightOf / TyFontStylesOf', '', bad);
  finally
    sl.Free;
    files.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartControlFontTest);
end.
