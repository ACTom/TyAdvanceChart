unit test.advchart.theme;
{$mode objfpc}{$H+}

{ The chart's tokens and rules live in its own themes/advchart.tycss, which the generated unit
  tyControls.AdvanceChart.Theme compiles in and registers as an add-on, instead of in the core's
  light.tycss. Three things hold:
    - the generated unit carries that file as it is, and it is the text registered;
    - every built-in theme, in both modes, resolves the chart's tokens and typeKeys as recorded
      in tests/fixtures/advchart-theme-baseline.json, the dump of test.advchart.themedump. It
      was first taken before anything moved, so the move changed nothing a theme draws;
    - light.tycss holds nothing of the chart's. That file is TyControls', so it is read from
      the checkout TY_CORE_DIR names (test.advchart.coredir); unset, the check is ignored.

  The dump's lists are the vocabulary of advchart.tycss, and the item count follows from them and
  from TyBuiltinThemeNames, so a token, typeKey or built-in theme added on either side shows as
  an item the baseline does not record. The chart follows TyControls' main, whose themes may
  change what it resolves. When a change is the point (in TyControls or in advchart.tycss),
  re-record the baseline and read its diff:
    TY_WRITE_BASELINE=1 tyadvchart_tests.exe --suite=TAdvChartThemeTest.TestTheThemesResolveAsBefore
  with the exe in tests/ (the fixture is found from the exe's own location). The test then
  writes the dump to the fixture and passes.

  The 'system' theme seeds its accent and its mode from the OS, so its part of the baseline is
  this machine's: SetUp pins both hooks to what the baseline was taken with, and the comparison
  does not depend on the desktop it runs on. }

interface

uses
  Classes, SysUtils, fpcunit, testregistry, tyControls.StyleModel;

type
  TAdvChartThemeTest = class(TTestCase)
  private
    FSavedAccent: TTySystemAccentHook;
    FSavedMode: TTySystemModeHook;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestTheUnitIsTheTycssFile;
    procedure TestTheThemesResolveAsBefore;
    procedure TestLightHoldsNoAdvChart;
  end;

implementation

uses
  tyControls.Css.AddOns, tyControls.BuiltinThemes, tyControls.AdvanceChart.Theme,
  test.advchart.themedump, test.advchart.coredir;

const
  { What the baseline machine's OS answered when the baseline was taken. }
  cBaselineAccent = '#6B69D6';
  cBaselineMode = 'light';
  cMaxReported = 12;

function BaselineAccent: string;
begin
  Result := cBaselineAccent;
end;

function BaselineMode: string;
begin
  Result := cBaselineMode;
end;

function RepoPath(const ARel: string): string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + ARel;
end;

function BaselinePath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'advchart-theme-baseline.json';
end;

{ The dump's bytes as they are, LF line ends: what a re-record commits. }
procedure WriteBaseline(const AText: string);
var
  fs: TFileStream;
begin
  ForceDirectories(ExtractFilePath(BaselinePath));
  fs := TFileStream.Create(BaselinePath, fmCreate);
  try
    if AText <> '' then
      fs.WriteBuffer(AText[1], Length(AText));
  finally
    fs.Free;
  end;
end;

{ The file's bytes, line endings made LF. }
function FileTextLF(const APath: string): string;
var
  fs: TFileStream;
begin
  Result := '';
  fs := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, fs.Size);
    if fs.Size > 0 then
      fs.ReadBuffer(Result[1], fs.Size);
  finally
    fs.Free;
  end;
  Result := StringReplace(Result, #13#10, #10, [rfReplaceAll]);
end;

{ '' when the two are the same, else where they first part: the line number and both lines. }
function FirstDifference(const AExpected, AActual: string): string;
var
  e, a: TStringList;
  i: Integer;
  le, la: string;
begin
  Result := '';
  if AExpected = AActual then Exit;
  e := TStringList.Create;
  a := TStringList.Create;
  try
    e.Text := AExpected;
    a.Text := AActual;
    for i := 0 to e.Count - 1 do
    begin
      le := e[i];
      if i < a.Count then la := a[i] else la := '<missing>';
      if le <> la then
        Exit(Format('line %d: expected "%s", got "%s"', [i + 1, le, la]));
    end;
    if a.Count > e.Count then
      Exit(Format('line %d: expected the end, got "%s"', [e.Count + 1, a[e.Count]]));
    Result := 'the texts differ in their line ends or a final newline';
  finally
    a.Free;
    e.Free;
  end;
end;

{ The dump's items, keyed '<theme|mode> <tokens|typeKeys> <name>', each with its value as the
  JSON text it is written in. AKeys is sorted; its Objects index AVals. }
procedure ParseDump(const AText: string; AKeys, AVals: TStringList);
var
  lines: TStringList;
  i, q: Integer;
  ln, entry, section, name, value: string;
begin
  lines := TStringList.Create;
  try
    lines.Text := AText;
    entry := '';
    section := '';
    for i := 0 to lines.Count - 1 do
    begin
      ln := lines[i];
      if (Length(ln) > 1) and (ln[1] = '"') then
      begin
        // an entry: "<theme>|<mode>": {
        q := Pos('"', Copy(ln, 2, MaxInt));
        entry := Copy(ln, 2, q - 1);
        section := '';
      end
      else if Copy(ln, 1, 3) = '  "' then
      begin
        // a section: "tokens": {  or  "typeKeys": {
        q := Pos('"', Copy(ln, 4, MaxInt));
        section := Copy(ln, 4, q - 1);
      end
      else if Copy(ln, 1, 5) = '    "' then
      begin
        // an item: "<name>": <value>[,]
        q := Pos('"', Copy(ln, 6, MaxInt));
        name := Copy(ln, 6, q - 1);
        value := Copy(ln, 6 + q + 2, MaxInt);   // past '": '
        if (value <> '') and (value[Length(value)] = ',') then
          SetLength(value, Length(value) - 1);
        AVals.Add(value);
        AKeys.AddObject(entry + ' ' + section + ' ' + name, TObject(PtrInt(AVals.Count - 1)));
      end;
    end;
  finally
    lines.Free;
  end;
end;

function NewKeyList: TStringList;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := True;
  Result.Sorted := True;
  Result.Duplicates := dupError;
end;

{ A typeKey's value is one '<state>: <style>' line per state, joined by an escaped newline: name
  the first state that differs rather than print six of them. }
procedure SplitEscaped(const AValue: string; ADest: TStringList);
var
  rest: string;
  p: Integer;
begin
  rest := AValue;
  p := Pos('\n', rest);
  while p > 0 do
  begin
    ADest.Add(Copy(rest, 1, p - 1));
    Delete(rest, 1, p + 1);
    p := Pos('\n', rest);
  end;
  ADest.Add(rest);
end;

function DescribeValues(const AExpected, AActual: string): string;
var
  e, a: TStringList;
  i: Integer;
begin
  e := TStringList.Create;
  a := TStringList.Create;
  try
    SplitEscaped(AExpected, e);
    SplitEscaped(AActual, a);
    for i := 0 to e.Count - 1 do
      if (i >= a.Count) or (e[i] <> a[i]) then
      begin
        if i < a.Count then
          Exit(Format('expected %s, got %s', [e[i], a[i]]))
        else
          Exit(Format('expected %s, got nothing', [e[i]]));
      end;
    Result := Format('expected %s, got %s', [AExpected, AActual]);
  finally
    a.Free;
    e.Free;
  end;
end;

procedure TAdvChartThemeTest.SetUp;
begin
  FSavedAccent := TySystemAccentHook;
  FSavedMode := TySystemModeHook;
  TySystemAccentHook := @BaselineAccent;
  TySystemModeHook := @BaselineMode;
end;

procedure TAdvChartThemeTest.TearDown;
begin
  TySystemAccentHook := FSavedAccent;
  TySystemModeHook := FSavedMode;
end;

procedure TAdvChartThemeTest.TestTheUnitIsTheTycssFile;
var
  path, fileText, unitText, diff: string;
begin
  path := RepoPath('themes' + PathDelim + 'advchart.tycss');
  AssertTrue('themes/advchart.tycss exists', FileExists(path));
  fileText := FileTextLF(path);
  AssertTrue('and is not empty', Length(fileText) > 1000);
  unitText := StringReplace(TyAdvChartCss, #13#10, #10, [rfReplaceAll]);
  diff := FirstDifference(fileText, unitText);
  AssertEquals('tyControls.AdvanceChart.Theme is themes/advchart.tycss (re-run ' +
    'scripts/gen-advchart-theme.ps1)', '', diff);
  AssertTrue('its initialization registered it as the add-on "advchart"',
    TyAddOnCssOf('advchart') = TyAdvChartCss);
end;

procedure TAdvChartThemeTest.TestTheThemesResolveAsBefore;
var
  eKeys, eVals, aKeys, aVals: TStringList;
  i, k, diffs, expected: Integer;
  ev, av, report, dump: string;
  v: TTyCssVocabulary;

  procedure Note(const AText: string);
  begin
    Inc(diffs);
    if diffs <= cMaxReported then
      report := report + LineEnding + '  ' + AText;
  end;

begin
  dump := TyAdvChartThemeDump;
  if GetEnvironmentVariable('TY_WRITE_BASELINE') = '1' then
  begin
    WriteBaseline(dump);
    Exit;
  end;
  v := TyAdvChartThemeVocabulary;
  AssertTrue('anti-vacuity: advchart.tycss defines tokens', Length(v.Tokens) > 0);
  AssertTrue('anti-vacuity: and names typeKeys', Length(v.TypeKeys) > 0);
  AssertTrue('anti-vacuity: there are built-in themes', Length(TyBuiltinThemeNames) > 0);
  { every built-in theme x 2 modes x (each token + each typeKey) }
  expected := Length(TyBuiltinThemeNames) * 2 * (Length(v.Tokens) + Length(v.TypeKeys));
  eKeys := NewKeyList;
  eVals := TStringList.Create;
  aKeys := NewKeyList;
  aVals := TStringList.Create;
  try
    AssertTrue('the baseline exists: ' + BaselinePath + ' (written with TY_WRITE_BASELINE=1)',
      FileExists(BaselinePath));
    ParseDump(FileTextLF(BaselinePath), eKeys, eVals);
    ParseDump(dump, aKeys, aVals);
    AssertEquals('items in the dump', expected, aKeys.Count);
    diffs := 0;
    report := '';
    for i := 0 to eKeys.Count - 1 do
    begin
      ev := eVals[PtrInt(eKeys.Objects[i])];
      k := aKeys.IndexOf(eKeys[i]);
      if k < 0 then
      begin
        Note(eKeys[i] + ': not in the dump');
        Continue;
      end;
      av := aVals[PtrInt(aKeys.Objects[k])];
      if av <> ev then
        Note(eKeys[i] + ': ' + DescribeValues(ev, av));
    end;
    for i := 0 to aKeys.Count - 1 do
      if eKeys.IndexOf(aKeys[i]) < 0 then
        Note(aKeys[i] + ': not in the baseline');
    AssertEquals(IntToStr(diffs) + ' item(s) resolve differently from the baseline (re-record '
      + 'with TY_WRITE_BASELINE=1 when that is the point of the change)' + report, 0, diffs);
    AssertEquals('items in the baseline: the themes and the vocabulary give these', expected,
      eKeys.Count);
  finally
    aVals.Free;
    aKeys.Free;
    eVals.Free;
    eKeys.Free;
  end;
end;

procedure TAdvChartThemeTest.TestLightHoldsNoAdvChart;
var
  light: string;
begin
  light := FileTextLF(TyCoreDirFor(Self, 'that the core''s light.tycss holds nothing of the chart''s')
    + 'themes' + PathDelim + 'light.tycss');
  AssertTrue('light.tycss was read', Length(light) > 10000);
  AssertEquals('light.tycss holds no --advchart- token', 0, Pos('--advchart-', light));
  AssertEquals('light.tycss holds no TyAdvChart rule', 0, Pos('TyAdvChart', light));
end;

initialization
  RegisterTest(TAdvChartThemeTest);

end.
