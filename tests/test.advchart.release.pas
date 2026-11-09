unit test.advchart.release;
{$mode objfpc}{$H+}

{ Three of TyControls' release guards (test.release) covered the chart, and came with it; a
  fourth follows the way TyControls guards the notices of its own ports.

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
  includes plus the two .lrs files the design-time units include.

  EveryUnitOnDiskIsListedInItsPackage: TyControls walked its source/ and designtime/ and asked
  whether each unit is listed in its package -- the chart's units with them, until they moved
  here. The same walk runs here over source/ (tyadvancechart.lpk) and designtime/
  (tyadvancechart_dt.lpk).

  TheThirdPartyNoticeCoversTheEChartsPort: the chart is a port of Apache ECharts and of zrender,
  so THIRD-PARTY-NOTICES.md carries their licence texts in a section whose heading covers the
  ported files, as TyControls' TheThirdPartyNoticeCoversTheTerminalPort does for xterm.js. }

interface

uses
  Classes, SysUtils, StrUtils, fpcunit, testregistry;

type
  TAdvChartReleaseTest = class(TTestCase)
  published
    procedure TheChartOptionEditorStaysAShell;
    procedure EveryIncludeFileAPackagedUnitNamesIsListed;
    procedure EveryUnitOnDiskIsListedInItsPackage;
    procedure TheThirdPartyNoticeCoversTheEChartsPort;
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

procedure TAdvChartReleaseTest.EveryUnitOnDiskIsListedInItsPackage;
var
  listedTotal: Integer;

  procedure CheckDir(const ADir, ALpk: string; ABad: TStrings);
  var
    found: TStringList;
    listed: TStringList;
    rec: TSearchRec;
    i: Integer;
    rel: string;
  begin
    found := TStringList.Create;
    listed := TStringList.Create;
    try
      { CollectLpkFiles prepends RepoRoot itself. }
      CollectLpkFiles(ALpk, listed);
      Inc(listedTotal, listed.Count);
      if FindFirst(RepoRoot + ADir + PathDelim + '*.pas', faAnyFile, rec) = 0 then
      begin
        repeat
          if (rec.Attr and faDirectory) = 0 then found.Add(rec.Name);
        until FindNext(rec) <> 0;
        FindClose(rec);
      end;
      for i := 0 to found.Count - 1 do
      begin
        rel := Slashes(ADir) + '/' + found[i];   { the .lpk's spelling }
        if listed.IndexOf(rel) < 0 then
          ABad.Add(rel + '  (not listed in ' + ALpk + ')');
      end;
    finally
      listed.Free;
      found.Free;
    end;
  end;

var
  bad: TStringList;
begin
  listedTotal := 0;
  { THE DIRECTION NOTHING CHECKED. EveryFileThePackagesNameIsShipped walks the
    .lpk and asks whether each entry exists; this walks the DISK and asks
    whether each unit is listed. They catch opposite mistakes, and the second
    one is the one that actually happens: a new unit compiles perfectly through
    the directory search path, so nothing on the author's machine notices, and
    it is simply absent from the installed package and every release archive.

    Three units were added to this layer by hand in one afternoon. That is the
    rate at which the omission becomes likely. }
  bad := TStringList.Create;
  try
    CheckDir('source', 'tyadvancechart.lpk', bad);
    CheckDir('designtime', 'tyadvancechart_dt.lpk', bad);
    AssertTrue('anti-vacuity: the packages list the units', listedTotal > 100);
    AssertEquals('units on disk that no package lists -- they compile via the '
      + 'search path and then go missing from the installed package:'
      + LineEnding + bad.Text, '', bad.Text);
  finally
    bad.Free;
  end;
end;

procedure TAdvChartReleaseTest.TheThirdPartyNoticeCoversTheEChartsPort;
const
  cHeading = '## Apache ECharts and ZRender';
  cGlob = 'source/tyControls.AdvanceChart*';
  cPrefix = 'tyControls.AdvanceChart';
  { the units ported from the four ECharts files that embed d3.js code (ECharts' LICENSE) }
  cD3Units: array[0..3] of string = ('tyControls.AdvanceChart.Treemap.pas',
    'tyControls.AdvanceChart.Tree.pas', 'tyControls.AdvanceChart.Graph.pas',
    'tyControls.AdvanceChart.Dataset.pas');
  cExts: array[0..1] of string = ('*.pas', '*.inc');
var
  sl: TStringList;
  notice, heading, section, low, bad, ext: string;
  p, ported, i: Integer;
  rec: TSearchRec;
begin
  { Hardcoded on purpose, as TyControls' guards for its own ports are: no manifest declares a
    licence obligation, so it cannot be derived. The chart is ported from ECharts (Apache
    License 2.0, with a NOTICE file) and from zrender (BSD 3-Clause); shipping it obliges
    THIRD-PARTY-NOTICES.md to carry ECharts' LICENSE and NOTICE and zrender's LICENSE. The
    pinned versions are checked too, so a notice left behind by a later re-pin shows.

    What IS derived is which files the heading must cover: every unit and include file under
    source/ that names ECharts or zrender. Today all of them start with the prefix the heading
    names; a ported file added under another name shows here. }
  sl := TStringList.Create;
  try
    sl.LoadFromFile(RepoRoot + 'THIRD-PARTY-NOTICES.md');
    notice := sl.Text;
  finally
    sl.Free;
  end;
  p := Pos(cHeading, notice);
  AssertTrue('the notice has an Apache ECharts and ZRender section', p > 0);
  heading := Copy(notice, p, Pos(#10, Copy(notice, p, MaxInt)));
  AssertTrue('its heading covers `' + cGlob + '`', Pos('`' + cGlob + '`', heading) > 0);
  { the section runs to the next second-level heading }
  section := Copy(notice, p + Length(heading), MaxInt);
  p := Pos(#10'## ', section);
  if p > 0 then
    SetLength(section, p);
  AssertTrue('it pins ECharts 6.1.0', Pos('ECharts 6.1.0', section) > 0);
  AssertTrue('and zrender 6.1.0', Pos('zrender 6.1.0', section) > 0);
  AssertTrue('it carries the Apache License 2.0, from its terms',
    Pos('TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION', section) > 0);
  AssertTrue('to their end', Pos('END OF TERMS AND CONDITIONS', section) > 0);
  AssertTrue('with ECharts'' list of subcomponents', Pos('Apache ECharts Subcomponents:', section) > 0);
  AssertTrue('ECharts'' NOTICE', Pos('This product includes software developed at', section) > 0);
  AssertTrue('and zrender''s BSD 3-Clause licence, with its copyright line',
    (Pos('BSD 3-Clause License', section) > 0) and (Pos('Copyright (c) 2017, Baidu Inc.', section) > 0));
  for i := 0 to High(cD3Units) do
  begin
    AssertTrue('it names ' + cD3Units[i] + ', which carries d3.js code',
      Pos(cD3Units[i], section) > 0);
    AssertTrue(cD3Units[i] + ' is on disk', FileExists(RepoRoot + 'source' + PathDelim + cD3Units[i]));
  end;
  AssertTrue('and the d3 licence text is in the notice',
    Pos('Copyright 2010-2016 Mike Bostock', notice) > 0);

  bad := '';
  ported := 0;
  sl := TStringList.Create;
  try
    for ext in cExts do
      if FindFirst(RepoRoot + 'source' + PathDelim + ext, faAnyFile, rec) = 0 then
      begin
        repeat
          if (rec.Attr and faDirectory) <> 0 then Continue;
          sl.LoadFromFile(RepoRoot + 'source' + PathDelim + rec.Name);
          low := LowerCase(sl.Text);
          if (Pos('echarts', low) = 0) and (Pos('zrender', low) = 0) then Continue;
          Inc(ported);
          if not StartsStr(cPrefix, rec.Name) then
            bad := bad + LineEnding + '  source/' + rec.Name;
        until FindNext(rec) <> 0;
        FindClose(rec);
      end;
  finally
    sl.Free;
  end;
  AssertTrue('anti-vacuity: the files that name ECharts or zrender (' + IntToStr(ported) + ')',
    ported >= 100);
  AssertEquals('ported files the heading''s `' + cGlob + '` does not cover:' + bad, '', bad);
end;

initialization
  RegisterTest(TAdvChartReleaseTest);
end.
