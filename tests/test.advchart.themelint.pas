{ Copied from TyControls tests/test.themebuilder.golden.pas at 77860b40. }
unit test.advchart.themelint;
{ What TyControls' linter says about themes/advchart.tycss, frozen.

  TyControls' TThemeLintGoldenTests (test.themebuilder.golden) holds TyLintCss's output over
  every theme in its themes/ to tests/fixtures/themebuilder/lint-golden.txt, byte for byte (line
  endings aside), and the chart's stylesheet was the first entry there until it moved here. The
  same check runs here over this repository's only theme: tests/fixtures/advchart-theme-lint.txt
  is that fixture's first entry (its lines 1-163 at 77860b40), unchanged -- the entry header is
  the path relative to the repository root, which is the same here. Linted on its own, the
  add-on's every var() names a token of the base theme, hence the undefined variables.

  Re-record with TY_WRITE_GOLDEN=1 only when a change to what the linter says is the point of
  the commit; the fixture's diff is then the review. Copied from the core: ReadWhole, Unify and
  CheckOrWrite; the corpus is cut to the one file. }
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TAdvChartThemeLintGoldenTest = class(TTestCase)
  private
    procedure CheckOrWrite(const AFixture: string; AActual: TStrings);
  published
    procedure TestTheLintOutputIsUnchanged;
  end;

implementation

uses
  Math, tyControls.ThemeLint;

function RepoDir: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..') + PathDelim;
end;

function FixtureDir: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim;
end;

function ReadWhole(const AFileName: string): string;
var
  fs: TFileStream;
begin
  Result := '';
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, fs.Size);
    if fs.Size > 0 then
      fs.ReadBuffer(Result[1], fs.Size);
  finally
    fs.Free;
  end;
end;

function Unify(const S: string): string;
begin
  Result := StringReplace(S, #13#10, #10, [rfReplaceAll]);
end;

procedure TAdvChartThemeLintGoldenTest.CheckOrWrite(const AFixture: string; AActual: TStrings);
var
  path, actual, expected: string;
  fs: TFileStream;
  a, e: TStringList;
  i: Integer;
begin
  path := FixtureDir + AFixture;
  actual := '';
  for i := 0 to AActual.Count - 1 do
    actual := actual + AActual[i] + #10;
  if GetEnvironmentVariable('TY_WRITE_GOLDEN') = '1' then
  begin
    ForceDirectories(FixtureDir);
    fs := TFileStream.Create(path, fmCreate);
    try
      if actual <> '' then
        fs.WriteBuffer(actual[1], Length(actual));
    finally
      fs.Free;
    end;
    Exit;
  end;
  AssertTrue('the fixture exists: ' + path, FileExists(path));
  expected := Unify(ReadWhole(path));
  actual := Unify(actual);
  if expected = actual then
    Exit;
  a := TStringList.Create;
  e := TStringList.Create;
  try
    a.Text := actual;
    e.Text := expected;
    for i := 0 to Max(a.Count, e.Count) - 1 do
      if (i >= a.Count) or (i >= e.Count) or (a[i] <> e[i]) then
      begin
        if i < e.Count then expected := e[i] else expected := '<end>';
        if i < a.Count then actual := a[i] else actual := '<end>';
        Fail(Format('%s differs at line %d:'#10'  expected: %s'#10'  actual:   %s',
          [AFixture, i + 1, expected, actual]));
      end;
    Fail(AFixture + ' differs (line endings only?)');
  finally
    a.Free;
    e.Free;
  end;
end;

procedure TAdvChartThemeLintGoldenTest.TestTheLintOutputIsUnchanged;
const
  CRel = 'themes/advchart.tycss';
var
  lines: TStringList;
  res: TTyLintResult;
  path: string;
  j: Integer;
begin
  lines := TStringList.Create;
  try
    path := RepoDir + 'themes' + PathDelim + 'advchart.tycss';
    AssertTrue('the stylesheet exists: ' + path, FileExists(path));
    lines.Add('== ' + CRel);
    res := TyLintCss(ReadWhole(path), ExtractFilePath(path));
    for j := 0 to High(res) do
      lines.Add(res[j]);
    AssertTrue('the linter has something to say about the add-on', lines.Count > 1);
    CheckOrWrite('advchart-theme-lint.txt', lines);
  finally
    lines.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartThemeLintGoldenTest);
end.
