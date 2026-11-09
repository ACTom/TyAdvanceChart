unit test.advchart.release;
{$mode objfpc}{$H+}

{ Two of TyControls' release guards (test.release) were about the chart, and came with it.

  TheChartOptionEditorStaysAShell: the chart's Option editor only puts the layer under it in a
  box. It reads the design-time file, which is all tests/ can do about that directory.

  EveryIncludeFileAPackagedUnitNamesIsListed: no manifest names an include file by itself -- a
  unit split into include files (the chart control, [S1]) keeps most of its code in files only
  its own $I directives name. TyControls checked that its release scripts ship each one, with a
  floor of 40 that counted the chart's 23 includes (18 are the core's own now). This repository
  has no release script: its packages list their include files (Task 11 of the split), and the
  package is what Lazarus, the online package manager and a release copy go by. So each $I of
  each unit the two packages list, followed into the include files it reaches, must name a file
  that is on disk and listed in one of the packages, and there must be at least the chart's 23
  includes plus the two .lrs files the design-time units include. }

interface

uses
  Classes, SysUtils, StrUtils, fpcunit, testregistry;

type
  TAdvChartReleaseTest = class(TTestCase)
  published
    procedure TheChartOptionEditorStaysAShell;
    procedure EveryIncludeFileAPackagedUnitNamesIsListed;
  end;

implementation

function RepoRoot: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim;
end;

function Slashes(const S: string): string;
begin
  Result := StringReplace(S, '\', '/', [rfReplaceAll]);
end;

{ Every <Filename Value="..."/> in a .lpk, repo-relative with forward slashes. }
procedure CollectLpkFiles(const ALpk: string; ADest: TStrings);
var
  sl: TStringList;
  txt, v: string;
  p, q: Integer;
begin
  sl := TStringList.Create;
  try
    sl.LoadFromFile(RepoRoot + ALpk);
    txt := sl.Text;
  finally
    sl.Free;
  end;
  p := 1;
  repeat
    p := PosEx('<Filename Value="', txt, p);
    if p = 0 then Break;
    Inc(p, Length('<Filename Value="'));
    q := PosEx('"', txt, p);
    if q = 0 then Break;
    v := Slashes(Copy(txt, p, q - p));
    p := q + 1;
    { .lpk paths are relative to the package file, which sits at the repo root. }
    while StartsStr('./', v) do Delete(v, 1, 2);
    if (v <> '') and (ExtractFileExt(v) <> '') then ADest.Add(v);
  until False;
end;

procedure TAdvChartReleaseTest.TheChartOptionEditorStaysAShell;
var
  sl: TStringList;
  src, bad, line: string;
  i: Integer;
const
  { The names of the low-level primitives. Every one of them answers a question
    the editor must NOT answer for itself -- where the caret is structurally,
    whether a path resolves, what the schema says about a node. The editor is
    allowed to call the composed ones (TyOptCompletionsAt, TyOptDiagnose,
    TyOptStatusAt, TyOptTreeInsert, TyOptCompletionInsert, TyOptSliceBefore,
    TyOptEdgesOf, TyOptSummary, TyOptDesc) and nothing below them. }
  cReserved: array[0..4] of string = (
    'TyOptContextAt', 'TyOptValidate', 'TyOptFindFor', 'TyOptKeyPositions',
    'TyOptFindNearestKey');
begin
  { THE RULE IS WORTH WHAT ENFORCES IT. 'The dialog only puts the list in a box'
    is the reason four units in source/ exist at all, and nothing checked it --
    designtime/ is outside the test build, so a judgement added in there would
    never be noticed until it was wrong in front of a user.

    This reads the file, which is all tests/ can do about that directory. It is
    a blunt instrument and it is meant to be: the moment the editor needs one of
    these, the answer is to add a composed function beside the others in
    source/, where a test can reach it -- not to reach past them here. }
  sl := TStringList.Create;
  try
    sl.LoadFromFile(RepoRoot + 'designtime' + PathDelim
      + 'tyControls.Design.AdvanceChart.Editor.pas');
    bad := '';
    for i := 0 to sl.Count - 1 do
    begin
      line := Trim(sl[i]);
      { Comments name these deliberately, and a comment decides nothing. }
      if (Copy(line, 1, 1) = '{') or (Copy(line, 1, 2) = '//') then Continue;
      for src in cReserved do
        if Pos(src, line) > 0 then
          bad := bad + LineEnding + '  line ' + IntToStr(i + 1) + ': ' + line;
    end;
    AssertEquals('the option editor reaches past the tested layer -- add a '
      + 'composed function in source/ instead, where a test can see it:'
      + bad, '', bad);
  finally
    sl.Free;
  end;
end;

procedure TAdvChartReleaseTest.EveryIncludeFileAPackagedUnitNamesIsListed;
var
  todo, seen, listed: TStringList;
  sl: TStringList;
  txt, rel, incRel, bad: string;
  p, q, found: Integer;
begin
  todo := TStringList.Create;
  seen := TStringList.Create;
  listed := TStringList.Create;
  sl := TStringList.Create;
  try
    CollectLpkFiles('tyadvancechart.lpk', todo);
    CollectLpkFiles('tyadvancechart_dt.lpk', todo);
    listed.CaseSensitive := False;
    listed.AddStrings(todo);
    bad := '';
    found := 0;
    while todo.Count > 0 do
    begin
      rel := todo[0];
      todo.Delete(0);
      if not (SameText(ExtractFileExt(rel), '.pas') or SameText(ExtractFileExt(rel), '.inc')) then
        Continue;
      if not FileExists(RepoRoot + rel) then Continue;
      sl.LoadFromFile(RepoRoot + rel);
      txt := sl.Text;
      p := 1;
      repeat
        p := PosEx('{$I ', txt, p);
        if p = 0 then Break;
        q := PosEx('}', txt, p);
        if q = 0 then Break;
        incRel := Trim(Copy(txt, p + 4, q - p - 4));
        p := q;
        incRel := ExtractFilePath(rel) + incRel;
        if seen.IndexOf(incRel) >= 0 then Continue;
        seen.Add(incRel);
        Inc(found);
        if not FileExists(RepoRoot + incRel) then
          bad := bad + LineEnding + '  ' + incRel + '  (named by ' + rel + ', not on disk)'
        else
        begin
          if listed.IndexOf(incRel) < 0 then
            bad := bad + LineEnding + '  ' + incRel + '  (named by ' + rel + ', in no package)';
          todo.Add(incRel);
        end;
      until False;
    end;
    AssertTrue('the units name their include files (' + IntToStr(found) + ')', found >= 25);
    AssertEquals('include files a packaged unit needs that no package lists:' + bad, '', bad);
  finally
    sl.Free;
    listed.Free;
    seen.Free;
    todo.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartReleaseTest);
end.
