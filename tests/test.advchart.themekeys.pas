unit test.advchart.themekeys;
{$mode objfpc}{$H+}

{ Every typeKey a chart unit names in a string literal is one a theme can style.

  TyControls' theme builder test (test.themebuilder.pick, CV9) reads every unit of its source/
  for the typeKeys it names, and each must be known: in the generated catalog or what an add-on
  registered -- the chart's keys, since its rules moved to themes/advchart.tycss -- on a
  registered typeKey chain, or the start of catalogue keys a unit builds by adding to it. The
  chart's units were read with the core's until they moved here; the same check reads them here.
  Known is what TyCatalogAllTypeKeys answers (the core's catalog united with the registered
  add-ons' vocabularies) and the registered parent chains; the theme builder's own part rows are
  its business and stay with it. }

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TAdvChartThemeKeysTest = class(TTestCase)
  published
    procedure TestEveryChartKeyIsKnown;
  end;

implementation

uses
  tyControls.StyleModel, tyControls.Css.AddOns, tyControls.AdvanceChart.Theme;

function RepoRoot: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim;
end;

function Has(AList: TStrings; const AKey: string): Boolean;
var
  i: Integer;
begin
  for i := 0 to AList.Count - 1 do
    if SameText(AList[i], AKey) then Exit(True);
  Result := False;
end;

{ the typeKeys a unit names in string literals: comments stripped (braces nest in FPC),
  every quoted string that is a whole Ty[A-Z]... identifier, TyControls left out }
function LiteralKeys(const AUnit: string): TStringList;
var
  sl: TStringList;
  t, lit, rest, incName: string;
  i, n, depth, p, q: Integer;

  procedure Take(const S: string);
  var
    k: Integer;
    ok: Boolean;
  begin
    ok := (Length(S) >= 3) and (S[1] = 'T') and (S[2] = 'y') and (S[3] in ['A'..'Z']);
    if ok then
      for k := 4 to Length(S) do
        if not (S[k] in ['A'..'Z', 'a'..'z', '0'..'9']) then
          ok := False;
    if ok and (S <> 'TyControls') and not Has(Result, S) then
      Result.Add(S);
  end;

begin
  Result := TStringList.Create;
  sl := TStringList.Create;
  try
    sl.LoadFromFile(RepoRoot + 'source' + PathDelim + AUnit + '.pas');
    t := sl.Text;
    { the include files are the unit's text too: a unit split into them [S1] names its
      keys there. Each $I directive's file, read from the same directory. }
    rest := t;
    repeat
      p := Pos('{$I ', rest);
      if p = 0 then Break;
      rest := Copy(rest, p + 4, MaxInt);
      q := Pos('}', rest);
      incName := Trim(Copy(rest, 1, q - 1));
      rest := Copy(rest, q + 1, MaxInt);
      sl.LoadFromFile(RepoRoot + 'source' + PathDelim + incName);
      t := t + LineEnding + sl.Text;
    until False;
  finally
    sl.Free;
  end;
  n := Length(t);
  i := 1;
  depth := 0;
  while i <= n do
  begin
    if depth > 0 then
    begin
      if t[i] = '{' then Inc(depth)
      else if t[i] = '}' then Dec(depth);
      Inc(i);
      Continue;
    end;
    if t[i] = '{' then
    begin
      depth := 1;
      Inc(i);
      Continue;
    end;
    if (t[i] = '(') and (i < n) and (t[i + 1] = '*') then
    begin
      i := i + 2;
      while (i < n) and not ((t[i] = '*') and (t[i + 1] = ')')) do Inc(i);
      i := i + 2;
      Continue;
    end;
    if (t[i] = '/') and (i < n) and (t[i + 1] = '/') then
    begin
      while (i <= n) and not (t[i] in [#10, #13]) do Inc(i);
      Continue;
    end;
    if t[i] = '''' then
    begin
      lit := '';
      Inc(i);
      while i <= n do
      begin
        if t[i] = '''' then
        begin
          if (i < n) and (t[i + 1] = '''') then
          begin
            lit := lit + '''';
            i := i + 2;
            Continue;
          end;
          Break;
        end;
        lit := lit + t[i];
        Inc(i);
      end;
      Inc(i);
      Take(lit);
      Continue;
    end;
    Inc(i);
  end;
end;

{ AKey has a registered parent, or is the registered parent of a key (the theme builder's
  IsChainKey). }
function IsChainKey(const AKey: string): Boolean;
var
  reg: TStringList;
  i: Integer;
begin
  if TyTypeKeyParent(AKey) <> '' then
    Exit(True);
  Result := False;
  reg := TStringList.Create;
  try
    TyGetRegisteredTypeKeys(reg);
    for i := 0 to reg.Count - 1 do
      if SameText(TyTypeKeyParent(reg[i]), AKey) then
        Exit(True);
  finally
    reg.Free;
  end;
end;

{ Every typeKey a chart unit names in a string literal is a known one -- or the start of
  catalogue keys it builds by adding to it. A key in no catalogue turns this red: give it a rule
  in themes/advchart.tycss (or, if it is the core's, a row there). }
procedure TAdvChartThemeKeysTest.TestEveryChartKeyIsKnown;
var
  sr: TSearchRec;
  lits, known: TStringList;
  i, k: Integer;
  u: string;
  prefix: Boolean;
  units, keys: Integer;
  catalogue: TStringArray;
begin
  { the generated catalog and what add-ons registered (the chart's keys) }
  catalogue := TyCatalogAllTypeKeys;
  AssertTrue('the chart''s add-on is registered', TyAddOnCssOf('advchart') <> '');
  known := TStringList.Create;
  known.Sorted := True;
  known.Duplicates := dupIgnore;
  known.CaseSensitive := False;
  for k := 0 to High(catalogue) do
    known.Add(catalogue[k]);
  AssertTrue('the catalog carries the chart''s keys', known.IndexOf('TyAdvChartAxisLine') >= 0);
  units := 0;
  keys := 0;
  try
    if FindFirst(RepoRoot + 'source' + PathDelim + 'tyControls.*.pas', faAnyFile, sr) = 0 then
    try
      repeat
        u := ChangeFileExt(sr.Name, '');
        Inc(units);
        lits := LiteralKeys(u);
        try
          for i := 0 to lits.Count - 1 do
          begin
            Inc(keys);
            if known.IndexOf(lits[i]) >= 0 then Continue;
            if IsChainKey(lits[i]) then Continue;
            prefix := False;
            for k := 0 to High(catalogue) do
              if (Length(catalogue[k]) > Length(lits[i]))
                 and SameText(Copy(catalogue[k], 1, Length(lits[i])), lits[i]) then
                prefix := True;
            AssertTrue('CV9: ' + u + ' names ' + lits[i] + ', which is not a known typeKey', prefix);
          end;
        finally
          lits.Free;
        end;
      until FindNext(sr) <> 0;
    finally
      FindClose(sr);
    end;
  finally
    known.Free;
  end;
  AssertTrue('CV9: the units were read: ' + IntToStr(units), units > 100);
  AssertTrue('CV9: they name typeKeys: ' + IntToStr(keys), keys > 0);
end;

initialization
  RegisterTest(TAdvChartThemeKeysTest);
end.
