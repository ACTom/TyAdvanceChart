unit test.advchart.customclasses;
{$mode objfpc}{$H+}

{ The custom-class guards (TyControls issue #8) for TTyAdvanceChart.

  TyControls' test.customclasses holds every split class of the core to these guards, and
  TTyAdvanceChart was in its CSplit list from the day the chart was split (its fourth round, merged
  2026-10-26) until it moved here. The guards that are about the split class itself came with it:

    G1  the final class sits directly on TTyCustomAdvanceChart;
    G2  the custom class publishes nothing beyond its LCL root;
    G3  the final class's declaration is nothing but `published` and `property X;` lines;
    G4  the final class adds no field;
    G5  every class designtime/ registers is split, and every split class is registered;
    G9  a third party publishing what TTyAdvanceChart publishes IS TTyAdvanceChart -- the mimic
        scripts/gen-mimic.py writes (test.advchart.customclasses.mimic) against the final class:
        RTTI rows, fresh stream, type key, default size, resolved style;
    G10 what a fresh instance writes into the .lfm of a form, frozen in
        tests/fixtures/customclasses/fresh-streams.txt (TyControls' fixture's TTyAdvanceChart
        section, taken as it was at 77860b40).

  The rest stays in TyControls: the derivation table (G7) and the demoted base classes (G8) are
  about the core's own classes, and no machine- or locale-dependent value is in the chart's
  fresh stream, so nothing here is masked. The population is whatever designtime/ registers
  (test.designregistry parses it; test.advchart.version registers every name of it). }

interface

uses
  Classes, SysUtils, StrUtils, TypInfo, FileUtil, Controls, Forms, fpcunit, testregistry,
  test.designregistry, test.advchart.version,
  tyControls.Types, tyControls.Base, tyControls.AdvanceChart, test.advchart.customclasses.mimic;

type
  TAdvChartCustomClassesGuardTest = class(TTestCase)
  published
    procedure TestSplitClassesSitOnTheirCustomClass;
    procedure TestCustomClassesPublishNothingNew;
    procedure TestCustomAndFinalAgree;
    procedure TestFinalClassesAddNoFields;
    procedure TestEveryRegisteredClassIsAccountedFor;
    procedure TestGeneratedMimicsMatchTheirFinalClass;
    procedure TestFreshFormFileTextUnchanged;
  end;

{ CSplit, shared with test.advchart.designeditors. }
function CustomClassesSplit: TStrings;

implementation

const
  CFreshStreamsFile = 'tests' + PathDelim + 'fixtures' + PathDelim + 'customclasses' + PathDelim
    + 'fresh-streams.txt';

var
  GSplit: TStringList;

function CustomClassesSplit: TStrings;
begin
  Result := GSplit;
end;

{ ------------------------------------------------------------------ populations }

{ Registered classes, resolved by name (test.advchart.version registers them), sorted by name.
  Objects[] holds the class. }
function RegisteredPopulation: TStringList;
var
  names: TStringList;
  i: Integer;
  c: TPersistentClass;
begin
  Result := TStringList.Create;
  names := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    for i := 0 to names.Count - 1 do
    begin
      if Result.IndexOf(names[i]) >= 0 then Continue;
      c := GetClass(names[i]);
      if c = nil then
        raise Exception.CreateFmt('registered class %s does not resolve with GetClass', [names[i]]);
      Result.AddObject(names[i], TObject(c));
    end;
  finally
    names.Free;
  end;
  Result.Sort;
end;

function PublishedNames(AClass: TClass): TStringList;
var
  pl: PPropList;
  n, i: Integer;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  n := GetPropList(AClass.ClassInfo, pl);
  try
    for i := 0 to n - 1 do
      Result.Add(pl^[i]^.Name);
  finally
    FreeMem(pl);
  end;
end;

function LclRootOf(AClass: TClass): TClass;
begin
  Result := AClass;
  while (Result <> nil) and AnsiStartsStr('TTy', Result.ClassName) do
    Result := Result.ClassParent;
end;

function IsSplitShape(AClass: TClass): Boolean;
begin
  Result := (AClass.ClassParent <> nil)
    and SameText(AClass.ClassParent.ClassName, 'TTyCustom' + Copy(AClass.ClassName, 4, MaxInt));
end;

{ ------------------------------------------------------------------ RTTI rows (G9) }

function StoredCode(PI: PPropInfo): string;
begin
  if ((PI^.PropProcs shr 4) and 3) = ptConst then
  begin
    if PI^.StoredProc <> nil then Result := 'T' else Result := 'F';
  end
  else
    Result := 'D';
end;

function AccessCode(PI: PPropInfo): string;
begin
  Result := '';
  if PI^.GetProc <> nil then Result := Result + 'R';
  if PI^.SetProc <> nil then Result := Result + 'W';
end;

{ Columns 4..9 of a property row: TypeName Kind Default Stored Index Access. }
function AttrColumns(PI: PPropInfo): string;
begin
  Result := PI^.PropType^.Name + #9
    + GetEnumName(TypeInfo(TTypeKind), Ord(PI^.PropType^.Kind)) + #9
    + IntToStr(PI^.Default) + #9
    + StoredCode(PI) + #9
    + IntToStr(PI^.Index) + #9
    + AccessCode(PI);
end;

{ Split lines into sections keyed by class name (G10's fixture). Each section's lines are stored
  as one #10-joined string. A header's chain= is cut off if there is one. }
procedure Sectionize(ALines: TStrings; ADest: TStringList);
var
  i, p: Integer;
  cur, body, line: string;
begin
  cur := '';
  body := '';
  for i := 0 to ALines.Count - 1 do
  begin
    line := ALines[i];
    if AnsiStartsStr('# ', line) then
    begin
      if cur <> '' then ADest.Values[cur] := body;
      cur := ExtractWord(2, line, [' ']);
      p := Pos(' chain=', line);
      if p > 0 then line := Copy(line, 1, p - 1);
      body := line;
    end
    else if cur <> '' then
      body := body + #10 + line;
  end;
  if cur <> '' then ADest.Values[cur] := body;
end;

{ ------------------------------------------------------------------ structural guards }

function SplitClasses: TList;
var
  i: Integer;
  c: TClass;
begin
  Result := TList.Create;
  for i := 0 to GSplit.Count - 1 do
  begin
    c := GetClass(GSplit[i]);
    if c = nil then
      raise Exception.CreateFmt('CSplit names %s, which does not resolve', [GSplit[i]]);
    Result.Add(c);
  end;
end;

procedure TAdvChartCustomClassesGuardTest.TestSplitClassesSitOnTheirCustomClass;
var
  l: TList;
  i: Integer;
  bad: string;
begin
  bad := '';
  l := SplitClasses;
  try
    for i := 0 to l.Count - 1 do
      if not IsSplitShape(TClass(l[i])) then
        bad := bad + ' ' + TClass(l[i]).ClassName + '(parent ' + TClass(l[i]).ClassParent.ClassName + ')';
  finally
    l.Free;
  end;
  AssertEquals('split classes whose direct parent is not TTyCustom<Name>:' + bad, '', bad);
end;

procedure TAdvChartCustomClassesGuardTest.TestCustomClassesPublishNothingNew;
var
  l: TList;
  i, k: Integer;
  bad: string;
  cust, root: TClass;
  cn, rn: TStringList;
begin
  bad := '';
  l := SplitClasses;
  try
    for i := 0 to l.Count - 1 do
    begin
      cust := TClass(l[i]).ClassParent;
      root := LclRootOf(cust);
      cn := PublishedNames(cust);
      rn := PublishedNames(root);
      try
        for k := 0 to cn.Count - 1 do
          if rn.IndexOf(cn[k]) < 0 then
            bad := bad + ' ' + cust.ClassName + ':' + cn[k];
        for k := 0 to rn.Count - 1 do
          if cn.IndexOf(rn[k]) < 0 then
            bad := bad + ' ' + cust.ClassName + ':-' + rn[k];
      finally
        cn.Free;
        rn.Free;
      end;
    end;
  finally
    l.Free;
  end;
  AssertEquals('custom classes publishing more than their LCL root:' + bad, '', bad);
end;

{ Strip Pascal comments, keep line breaks. }
function StripComments(const S: string): string;
var
  i, n: Integer;
begin
  Result := '';
  i := 1;
  n := Length(S);
  while i <= n do
  begin
    if S[i] = '{' then
    begin
      while (i <= n) and (S[i] <> '}') do
      begin
        if S[i] in [#10, #13] then Result := Result + S[i];
        Inc(i);
      end;
      Inc(i);
    end
    else if (S[i] = '(') and (i < n) and (S[i + 1] = '*') then
    begin
      Inc(i, 2);
      while (i < n) and not ((S[i] = '*') and (S[i + 1] = ')')) do
      begin
        if S[i] in [#10, #13] then Result := Result + S[i];
        Inc(i);
      end;
      Inc(i, 2);
    end
    else if (S[i] = '/') and (i < n) and (S[i + 1] = '/') then
    begin
      while (i <= n) and not (S[i] in [#10, #13]) do Inc(i);
    end
    else if S[i] = '''' then
    begin
      Result := Result + S[i];
      Inc(i);
      while (i <= n) and (S[i] <> '''') and not (S[i] in [#10, #13]) do
      begin
        Result := Result + S[i];
        Inc(i);
      end;
      if i <= n then
      begin
        Result := Result + S[i];
        Inc(i);
      end;
    end
    else
    begin
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;

function IsPropertyOnlyLine(const ALine: string): Boolean;
var
  t, rest: string;
  k: Integer;
begin
  t := Trim(ALine);
  if (t = '') or SameText(t, 'published') then Exit(True);
  Result := False;
  if not AnsiStartsText('property', t) then Exit;
  rest := Trim(Copy(t, 9, MaxInt));
  if (Length(t) <= 8) or not (t[9] in [' ', #9]) then Exit;
  if (rest = '') or (rest[Length(rest)] <> ';') then Exit;
  rest := Trim(Copy(rest, 1, Length(rest) - 1));
  if rest = '' then Exit;
  for k := 1 to Length(rest) do
    if not (rest[k] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;
  Result := True;
end;

{ G3 (b): the final class declaration is nothing but `published` and `property X;`. }
procedure TAdvChartCustomClassesGuardTest.TestCustomAndFinalAgree;
var
  l: TList;
  i, k, f, ln: Integer;
  bad, src, code, cname, header, line: string;
  files, lines: TStringList;
  found: Boolean;
begin
  bad := '';
  l := SplitClasses;
  files := LibrarySourceFiles;
  lines := TStringList.Create;
  try
    for i := 0 to l.Count - 1 do
    begin
      cname := TClass(l[i]).ClassName;
      header := cname + ' = class(TTyCustom' + Copy(cname, 4, MaxInt) + ')';
      found := False;
      for f := 0 to files.Count - 1 do
      begin
        src := ReadFileToString(files[f]);
        if Pos(LowerCase(header), LowerCase(src)) = 0 then Continue;
        code := StripComments(src);
        lines.Text := code;
        for ln := 0 to lines.Count - 1 do
        begin
          if not SameText(DelSpace(lines[ln]), DelSpace(header)) then Continue;
          found := True;
          k := ln + 1;
          while k < lines.Count do
          begin
            line := Trim(lines[k]);
            if SameText(line, 'end;') then Break;
            if not IsPropertyOnlyLine(line) then
              bad := bad + LineEnding + '  ' + cname + ': ' + line;
            Inc(k);
          end;
          Break;
        end;
        if found then Break;
      end;
      if not found then
        bad := bad + LineEnding + '  ' + cname + ': declaration `' + header + '` not found in source/';
    end;
    AssertEquals('final classes must hold only `property X;` lines:' + bad, '', bad);
  finally
    l.Free;
    files.Free;
    lines.Free;
  end;
end;

procedure TAdvChartCustomClassesGuardTest.TestFinalClassesAddNoFields;
var
  l: TList;
  i: Integer;
  bad: string;
begin
  bad := '';
  l := SplitClasses;
  try
    for i := 0 to l.Count - 1 do
      if TClass(l[i]).InstanceSize <> TClass(l[i]).ClassParent.InstanceSize then
        bad := bad + ' ' + TClass(l[i]).ClassName;
  finally
    l.Free;
  end;
  AssertEquals('final classes larger than their custom class:' + bad, '', bad);
end;

{ G5. TyControls' version also keeps a list of the classes it does not split; nothing this
  repository registers is one, so here every registered class is split. }
procedure TAdvChartCustomClassesGuardTest.TestEveryRegisteredClassIsAccountedFor;
var
  pop: TStringList;
  i: Integer;
  bad: string;
begin
  bad := '';
  pop := RegisteredPopulation;
  try
    AssertTrue('anti-vacuity: the registrations were parsed', pop.Count > 0);
    for i := 0 to pop.Count - 1 do
      if GSplit.IndexOf(pop[i]) < 0 then
        bad := bad + ' ' + pop[i] + '(registered but not in CSplit)';
    for i := 0 to GSplit.Count - 1 do
      if pop.IndexOf(GSplit[i]) < 0 then
        bad := bad + ' ' + GSplit[i] + '(in CSplit but not registered)';
  finally
    pop.Free;
  end;
  AssertEquals('registered classes not accounted for:' + bad, '', bad);
end;

{ ------------------------------------------------------------------ G9: the generated mimic }

type
  TCtlStyleAccess = class(TTyCustomControl);
  TGfxStyleAccess = class(TTyGraphicControl);

{ Every published property of AClass in RTTI order: name and the snapshot's attribute columns. }
function RttiRows(AClass: TClass): string;
var
  pl: PPropList;
  n, i: Integer;
begin
  Result := '';
  n := GetPropList(AClass.ClassInfo, pl);
  try
    for i := 0 to n - 1 do
      Result := Result + IntToStr(i) + #9 + pl^[i]^.Name + #9 + AttrColumns(pl^[i]) + LineEnding;
  finally
    if n > 0 then FreeMem(pl);
  end;
end;

{ A published date / time a constructor takes from the clock is pinned to one value on both
  instances before they are streamed: two instances made a moment apart can straddle a clock
  tick. Only the value is pinned; whether the line is written at all still comes from each
  class's own stored / default, which is what G9 compares. }
procedure PinClockValues(AComp: TComponent);
const
  CPinned = 36526.5;   // 2000-01-01 12:00
var
  pl: PPropList;
  n, i: Integer;
  tn: string;
begin
  n := GetPropList(AComp.ClassInfo, pl);
  try
    for i := 0 to n - 1 do
    begin
      if pl^[i]^.PropType^.Kind <> tkFloat then Continue;
      tn := pl^[i]^.PropType^.Name;
      if not (SameText(tn, 'TDateTime') or SameText(tn, 'TDate') or SameText(tn, 'TTime')) then
        Continue;
      if (pl^[i]^.SetProc = nil) or (Abs(GetFloatProp(AComp, pl^[i]) - Now) > 1) then Continue;
      SetFloatProp(AComp, pl^[i], CPinned);
    end;
  finally
    if n > 0 then FreeMem(pl);
  end;
end;

const
  CNoChildStreamed = '<the host wrote no child>';

{ What a fresh instance writes into the .lfm of the form it sits on: AHost is streamed the way
  the IDE saves a form, and what is kept is everything the form writes for its children, without
  the first `object` line (it names the class) and the form's own closing `end`. Through the host
  and not with the control as the root: streamed as the root, a control writes the children it
  creates and owns itself, which no .lfm ever carries. }
function FreshStreamBody(AHost: TComponent): string;
var
  ms: TMemoryStream;
  ss: TStringStream;
  p: Integer;
begin
  ms := TMemoryStream.Create;
  ss := TStringStream.Create('');
  try
    ms.WriteComponent(AHost);
    ms.Position := 0;
    ObjectBinaryToText(ms, ss);
    Result := ss.DataString;
  finally
    ms.Free;
    ss.Free;
  end;
  { The first child's `object` line: two spaces in, one level below the form. }
  p := Pos(#10'  object ', Result);
  if p = 0 then Exit(CNoChildStreamed);
  Delete(Result, 1, p);
  p := Pos(#10, Result);
  Delete(Result, 1, p);
  { The form's own `end`, the last line. }
  Result := TrimRight(Result);
  if AnsiEndsStr(#10'end', Result) then
    SetLength(Result, Length(Result) - 3);
end;

{ The resolved theme style, as far as a control's look depends on it. }
function StyleText(AComp: TComponent): string;
var
  s: TTyStyleSet;
begin
  if AComp is TTyCustomControl then
    s := TCtlStyleAccess(AComp).CurrentStyle
  else if AComp is TTyGraphicControl then
    s := TGfxStyleAccess(AComp).CurrentStyle
  else
    Exit('-');
  Result := Format('bg=%d/%x txt=%x bc=%x bw=%d bs=%d rs=%d br=%d pad=%d,%d,%d,%d '
    + 'font=%s/%d/%d op=%.3f sh=%x/%d/%d,%d ol=%x/%d/%d',
    [Ord(s.Background.Kind), s.Background.Color, s.TextColor, s.BorderColor, s.BorderWidth,
     Ord(s.BorderStyle), Ord(s.RenderStyle), s.BorderRadius, s.Padding.Left, s.Padding.Top,
     s.Padding.Right, s.Padding.Bottom, s.FontName, s.FontSize, s.FontWeight, s.Opacity,
     s.ShadowColor, s.ShadowBlur, s.ShadowOffset.X, s.ShadowOffset.Y, s.OutlineColor,
     s.OutlineWidth, s.OutlineOffset]);
end;

{ G9. A third party derives TTyCustomAdvanceChart and publishes what it wants (issue #8). If it
  publishes exactly what TTyAdvanceChart publishes, it must BE TTyAdvanceChart in every way a
  form file and a theme can see: same RTTI rows (order, type, default, stored, index, access),
  same fresh stream, same type key, same default size, same resolved style. The mimic is
  generated from source by scripts/gen-mimic.py; the first check makes a split class without a
  mimic red. Regenerating copies the final class's CURRENT published section, so read the diff
  of test.advchart.customclasses.mimic.pas after every run. }
procedure TAdvChartCustomClassesGuardTest.TestGeneratedMimicsMatchTheirFinalClass;
var
  i: Integer;
  bad, a, b: string;
  gen, fin: TComponent;
  host, host2: TForm;
  sa, sb: ITyStyleable;
  covered: TStringList;
begin
  bad := '';
  covered := TStringList.Create;
  covered.CaseSensitive := False;
  try
    for i := Low(CGenMimics) to High(CGenMimics) do
    begin
      covered.Add(CGenMimics[i, 1].ClassName);
      if GSplit.IndexOf(CGenMimics[i, 1].ClassName) < 0 then
        bad := bad + LineEnding + '  mimic for a class not in CSplit: ' + CGenMimics[i, 1].ClassName;
      if CGenMimics[i, 0].ClassParent <> CGenMimics[i, 1].ClassParent then
        bad := bad + LineEnding + '  ' + CGenMimics[i, 0].ClassName + ' does not derive from '
          + CGenMimics[i, 1].ClassParent.ClassName;
    end;
    for i := 0 to GSplit.Count - 1 do
      if covered.IndexOf(GSplit[i]) < 0 then
        bad := bad + LineEnding + '  split class without a mimic (run scripts/gen-mimic.py, then review its diff): ' + GSplit[i];
  finally
    covered.Free;
  end;
  AssertEquals('the generated mimics do not cover CSplit:' + bad, '', bad);

  { Two hosts, so neither instance's TabOrder reflects the other one sitting next to it. }
  host := TForm.CreateNew(nil);
  host2 := TForm.CreateNew(nil);
  try
    host.SetBounds(0, 0, 640, 480);
    host2.SetBounds(0, 0, 640, 480);
    for i := Low(CGenMimics) to High(CGenMimics) do
    begin
      a := RttiRows(CGenMimics[i, 0]);
      b := RttiRows(CGenMimics[i, 1]);
      if a <> b then
        bad := bad + LineEnding + '  RTTI ' + CGenMimics[i, 1].ClassName + LineEnding + '    mimic: '
          + StringReplace(a, LineEnding, ' | ', [rfReplaceAll]) + LineEnding + '    final: '
          + StringReplace(b, LineEnding, ' | ', [rfReplaceAll]);
      gen := TComponentClass(CGenMimics[i, 0]).Create(host);
      fin := TComponentClass(CGenMimics[i, 1]).Create(host2);
      try
        if gen is TControl then TControl(gen).Parent := host;
        if fin is TControl then TControl(fin).Parent := host2;
        PinClockValues(gen);
        PinClockValues(fin);
        a := FreshStreamBody(host);
        b := FreshStreamBody(host2);
        if a = CNoChildStreamed then
          bad := bad + LineEnding + '  fresh stream ' + CGenMimics[i, 1].ClassName
            + ': the host form wrote nothing for it';
        if a <> b then
          bad := bad + LineEnding + '  fresh stream ' + CGenMimics[i, 1].ClassName + LineEnding
            + '--mimic--' + LineEnding + a + '--final--' + LineEnding + b;
        a := '-';
        b := '-';
        if Supports(gen, ITyStyleable, sa) then a := sa.GetStyleTypeKey;
        if Supports(fin, ITyStyleable, sb) then b := sb.GetStyleTypeKey;
        sa := nil;
        sb := nil;
        if a <> b then
          bad := bad + LineEnding + '  type key ' + CGenMimics[i, 1].ClassName + ': ' + a + ' vs ' + b;
        if (gen is TControl) and ((TControl(gen).Width <> TControl(fin).Width)
           or (TControl(gen).Height <> TControl(fin).Height)) then
          bad := bad + LineEnding + Format('  default size %s: %dx%d vs %dx%d',
            [CGenMimics[i, 1].ClassName, TControl(gen).Width, TControl(gen).Height,
             TControl(fin).Width, TControl(fin).Height]);
        a := StyleText(gen);
        b := StyleText(fin);
        if a <> b then
          bad := bad + LineEnding + '  style ' + CGenMimics[i, 1].ClassName + LineEnding + '    mimic: '
            + a + LineEnding + '    final: ' + b;
      finally
        gen.Free;
        fin.Free;
        host.DestroyComponents;
        host2.DestroyComponents;
      end;
    end;
  finally
    host.Free;
    host2.Free;
  end;
  AssertTrue('anti-vacuity: no mimics were compared', Length(CGenMimics) >= GSplit.Count);
  AssertEquals('a third party publishing what the final class publishes is not that class:' + bad,
    '', bad);
end;

{ G10. What a fresh instance of every registered class writes into the .lfm of the form it is
  dropped on, frozen in tests/fixtures/customclasses/fresh-streams.txt. It covers what G9 cannot
  see: a default, stored clause or constructor value that drifts on the CUSTOM class, which the
  mimic inherits too. The fixture's TTyAdvanceChart section is TyControls' (fixture lines 15-21
  at 77860b40), so a fresh chart still writes what it wrote before it moved. Sizes are measured
  on Windows.

  Rewrite with TY_WRITE_FRESH_STREAMS=1 only when a change to what a form file says is the point
  of the commit (or a new class is registered); the diff of the fixture is then the review:
    TY_WRITE_FRESH_STREAMS=1 tyadvchart_tests.exe --suite=TAdvChartCustomClassesGuardTest.TestFreshFormFileTextUnchanged
  with the exe (or a copy of it) sitting in tests/: the fixture path is found from the exe's own
  location (RepoRoot), not from the working directory. }
procedure TAdvChartCustomClassesGuardTest.TestFreshFormFileTextUnchanged;
var
  reg, cur, gold, curSec, goldSec: TStringList;
  i, diffs: Integer;
  host: TForm;
  inst: TComponent;
  body, path, firstMsg, a, b: string;
begin
  path := RepoRoot + CFreshStreamsFile;
  reg := RegisteredPopulation;
  cur := TStringList.Create;
  gold := TStringList.Create;
  curSec := TStringList.Create;
  goldSec := TStringList.Create;
  try
    cur.LineBreak := #10;
    for i := 0 to reg.Count - 1 do
    begin
      host := TForm.CreateNew(nil);
      try
        host.SetBounds(0, 0, 640, 480);
        try
          inst := TComponentClass(TClass(reg.Objects[i])).Create(host);
          if inst is TControl then TControl(inst).Parent := host;
          PinClockValues(inst);
          body := FreshStreamBody(host);
        except
          on E: Exception do body := '<' + E.ClassName + ': ' + E.Message + '>';
        end;
      finally
        host.Free;
      end;
      AssertTrue('anti-vacuity: the form wrote ' + reg[i], body <> CNoChildStreamed);
      cur.Add('# ' + reg[i]);
      cur.Add(StringReplace(TrimRight(body), #13#10, #10, [rfReplaceAll]));
    end;
    AssertTrue('anti-vacuity: nothing was streamed', reg.Count > 0);
    if GetEnvironmentVariable('TY_WRITE_FRESH_STREAMS') = '1' then
    begin
      ForceDirectories(ExtractFilePath(path));
      cur.SaveToFile(path);
      Exit;
    end;
    AssertTrue('fresh-stream fixture missing: ' + path + ' (written with TY_WRITE_FRESH_STREAMS=1)',
      FileExists(path));
    gold.LoadFromFile(path);
    cur.Text := cur.Text;   // split the joined bodies into lines
    Sectionize(cur, curSec);
    Sectionize(gold, goldSec);
    AssertTrue('anti-vacuity: the fixture has sections', goldSec.Count > 0);
    diffs := 0;
    firstMsg := '';
    for i := 0 to goldSec.Count - 1 do
    begin
      a := goldSec.ValueFromIndex[i];
      b := curSec.Values[goldSec.Names[i]];
      if a = b then Continue;
      Inc(diffs);
      if firstMsg = '' then
        firstMsg := goldSec.Names[i] + #10'--fixture--'#10 + a + #10'--now--'#10 + b;
    end;
    for i := 0 to curSec.Count - 1 do
      if goldSec.IndexOfName(curSec.Names[i]) < 0 then
      begin
        Inc(diffs);
        if firstMsg = '' then
          firstMsg := curSec.Names[i] + ' is not in the fixture (a newly registered class: '
            + 'add its section with TY_WRITE_FRESH_STREAMS=1)';
      end;
    AssertEquals('what a fresh instance writes into a form file changed for ' + IntToStr(diffs)
      + ' class(es); first: ' + firstMsg, 0, diffs);
  finally
    reg.Free;
    cur.Free;
    gold.Free;
    curSec.Free;
    goldSec.Free;
  end;
end;

initialization
  GSplit := TStringList.Create;
  GSplit.CaseSensitive := False;
  { CSplit: the final classes split into TTyCustomXxx + TTyXxx. In TyControls' list since the
    chart's fourth round merged (2026-10-26). }
  GSplit.Add('TTyAdvanceChart');
  RegisterTest(TAdvChartCustomClassesGuardTest);

finalization
  GSplit.Free;
end.
