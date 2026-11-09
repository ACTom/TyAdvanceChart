unit test.advchart.i18n;
{$mode objfpc}{$H+}
{ AdvChart's resource strings live in tyControls.AdvanceChart.StrConsts, with a
  catalogue of their own (languages/tycontrols.advancechart.strconsts.<lang>.po,
  languages/tyControls.AdvanceChart.StrConsts.pot). These tests pin the three halves of
  that move: the strings reach the chart's own catalogue and are translated through it,
  the core's catalogue no longer carries them, and every catalogue of the chart (the new
  one and the two design-time ones) is keyed on its own unit's name. The core's catalogues are
  read from the TyControls checkout TY_CORE_DIR names (test.advchart.coredir); unset, that
  check is ignored.
  And the chart's half of TyControls' #68 guard: no unit under source/ holds Chinese text in a
  string literal, but for ECharts' own data in two of them. }
interface
uses
  Classes, SysUtils, fpcunit, testregistry, FileUtil,
  Translations,                      // TPOFile, TranslateUnitResourceStrings (LazUtils)
  tyControls.AdvanceChart.StrConsts, // the unit that DECLARES the chart's resourcestrings
  test.advchart.coredir;             // TY_CORE_DIR, the checkout the core's catalogues are in
type
  TAdvChartI18nTest = class(TTestCase)
  published
    procedure TestTheAdvChartStringsAreTranslated;
    procedure TestNoAdvChartStringLeftInTheCore;
    procedure TestEveryAdvChartResourcestringIsInItsPot;
    procedure TestTheChartCataloguesBindToTheirUnits;
    procedure TestNoUnitHoldsChineseTextInAStringLiteral;
  end;

implementation

const
  CHART_UNIT = 'tyControls.AdvanceChart.StrConsts';

function RepoRoot: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim;
end;

function LanguagesDir: string;
begin
  Result := RepoRoot + 'languages' + PathDelim;
end;

{ The ids ('#: ' lines, lowercase) of a .po / .pot. }
function CatalogueIds(const AFile: string): TStringList;
var
  lines: TStringList;
  i: Integer;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  lines := TStringList.Create;
  try
    lines.LoadFromFile(AFile);
    for i := 0 to lines.Count - 1 do
      if Copy(lines[i], 1, 3) = '#: ' then
        Result.Add(LowerCase(Trim(Copy(lines[i], 4, MaxInt))));
  finally
    lines.Free;
  end;
end;

{ The shipped Chinese catalogue, applied to the chart's string unit the way an
  application does it; the English values are put back at the end (there is no
  untranslate API, so an identity catalogue built from the values saved before). }
procedure TAdvChartI18nTest.TestTheAdvChartStringsAreTranslated;
const
  NONE = '#untranslated#';
  { the toolbox, the legend's selector, the dataset transforms: one string each }
  ID_TOOLBOX = 'tycontrols.advancechart.strconsts.rstycharttoolboxdataviewtable';
  ID_LEGEND  = 'tycontrols.advancechart.strconsts.rstychartlegendselectall';
  ID_XFORM   = 'tycontrols.advancechart.strconsts.rstydssortempty';
var
  po: TPOFile;
  enToolbox, enLegend, enXform, zhToolbox, zhLegend, zhXform: string;

  function Identity(const AId, AText: string): string;
  begin
    Result := '#: ' + AId + LineEnding + 'msgid "' + AText + '"' + LineEnding
      + 'msgstr "' + AText + '"' + LineEnding + LineEnding;
  end;

begin
  enToolbox := rsTyChartToolboxDataViewTable;
  enLegend  := rsTyChartLegendSelectAll;
  enXform   := rsTyDsSortEmpty;
  AssertEquals('precondition: English default', 'Table', enToolbox);

  po := TPOFile.Create(LanguagesDir + 'tycontrols.advancechart.strconsts.zh_CN.po');
  try
    zhToolbox := po.Translate(ID_TOOLBOX, NONE);
    zhLegend  := po.Translate(ID_LEGEND, NONE);
    zhXform   := po.Translate(ID_XFORM, NONE);
    AssertTrue('the toolbox string is in the chart catalogue', zhToolbox <> NONE);
    AssertTrue('the legend selector string is in the chart catalogue', zhLegend <> NONE);
    AssertTrue('the dataset transform string is in the chart catalogue', zhXform <> NONE);
    AssertTrue('the toolbox string is Chinese', zhToolbox <> enToolbox);
    AssertTrue('the legend selector string is Chinese', zhLegend <> enLegend);
    AssertTrue('the dataset transform string is Chinese', zhXform <> enXform);
    try
      AssertTrue('translate call succeeded', TranslateUnitResourceStrings(CHART_UNIT, po));
      AssertEquals('toolbox', zhToolbox, rsTyChartToolboxDataViewTable);
      AssertEquals('legend selector', zhLegend, rsTyChartLegendSelectAll);
      AssertEquals('dataset transform', zhXform, rsTyDsSortEmpty);
    finally
      po.Free;
      po := TPOFile.Create(True);
      try
        po.ReadPOText('msgid ""' + LineEnding + 'msgstr ""' + LineEnding
          + '"Content-Type: text/plain; charset=UTF-8\n"' + LineEnding + LineEnding
          + Identity(ID_TOOLBOX, enToolbox) + Identity(ID_LEGEND, enLegend)
          + Identity(ID_XFORM, enXform));
        TranslateUnitResourceStrings(CHART_UNIT, po);
      finally
        po.Free;
        po := nil;
      end;
    end;
  finally
    po.Free;
  end;
  AssertEquals('restored: toolbox', enToolbox, rsTyChartToolboxDataViewTable);
  AssertEquals('restored: legend', enLegend, rsTyChartLegendSelectAll);
  AssertEquals('restored: transform', enXform, rsTyDsSortEmpty);
end;

{ The ids the chart's pot lists are the chart's strings. None of them may survive in the
  core's pot, its Chinese or English catalogue, or in the core's string unit; and the
  three anchors keep this from passing vacuously should the pot ever be emptied. The core's
  files are the TyControls checkout's that TY_CORE_DIR names. }
procedure TAdvChartI18nTest.TestNoAdvChartStringLeftInTheCore;
const
  CORE_PREFIX  = 'tycontrols.strconsts.';
  CHART_PREFIX = 'tycontrols.advancechart.strconsts.';
  ANCHORS: array[0..2] of string = ('rstycharttoolboxdataviewtable',
    'rstychartlegendselectall', 'rstydssortempty');
var
  chartIds, coreIds: TStringList;
  i, k, n: Integer;
  names: array[0..2] of string;
  src: TStringList;
  leftover, text, core: string;
begin
  core := TyCoreDirFor(Self, 'that none of the chart''s strings is left in the core');
  names[0] := core + 'languages' + PathDelim + 'tyControls.StrConsts.pot';
  names[1] := core + 'languages' + PathDelim + 'tycontrols.strconsts.zh_CN.po';
  names[2] := core + 'languages' + PathDelim + 'tycontrols.strconsts.en.po';

  chartIds := CatalogueIds(LanguagesDir + 'tyControls.AdvanceChart.StrConsts.pot');
  try
    AssertTrue('the chart pot lists its strings', chartIds.Count > 150);
    for i := 0 to chartIds.Count - 1 do
      AssertEquals('chart pot id is keyed on the chart unit: ' + chartIds[i], 1,
        Pos(CHART_PREFIX, chartIds[i]));
    for k := 0 to High(ANCHORS) do
      AssertTrue('anchor in the chart pot: ' + ANCHORS[k],
        chartIds.IndexOf(CHART_PREFIX + ANCHORS[k]) >= 0);

    leftover := '';
    for n := 0 to High(names) do
    begin
      coreIds := CatalogueIds(names[n]);
      try
        for i := 0 to chartIds.Count - 1 do
          if coreIds.IndexOf(CORE_PREFIX + Copy(chartIds[i], Length(CHART_PREFIX) + 1, MaxInt)) >= 0 then
            leftover := leftover + LineEnding + '  ' + ExtractFileName(names[n]) + ': ' + chartIds[i];
        for k := 0 to High(ANCHORS) do
          if coreIds.IndexOf(CORE_PREFIX + ANCHORS[k]) >= 0 then
            leftover := leftover + LineEnding + '  ' + ExtractFileName(names[n]) + ': ' + ANCHORS[k];
      finally
        coreIds.Free;
      end;
    end;

    { the core's own string unit must not declare any of them either }
    src := TStringList.Create;
    try
      src.LoadFromFile(core + 'source' + PathDelim + 'tyControls.StrConsts.pas');
      text := LowerCase(src.Text);
      for i := 0 to chartIds.Count - 1 do
        if Pos(LineEnding + '  ' + Copy(chartIds[i], Length(CHART_PREFIX) + 1, MaxInt) + ' ', text) > 0 then
          leftover := leftover + LineEnding + '  tyControls.StrConsts.pas declares '
            + Copy(chartIds[i], Length(CHART_PREFIX) + 1, MaxInt);
      AssertTrue('no AdvanceChart section comment is left in the core unit',
        Pos('// --- advancechart', text) = 0);
    finally
      src.Free;
    end;
  finally
    chartIds.Free;
  end;
  AssertEquals('chart strings still in the core:' + leftover, '', leftover);
end;

{ Every resourcestring the chart's unit declares has a .pot entry under the unit's name
  (the extractor skips an empty value, so only a comparison sees it), and the same holds
  for the chart's two design-time units. }
procedure TAdvChartI18nTest.TestEveryAdvChartResourcestringIsInItsPot;
  { A valid Pascal identifier and nothing else -- the guard that keeps prose out. }
  function IsIdent(const S: string): Boolean;
  var
    j: Integer;
  begin
    Result := (S <> '') and (S[1] in ['A'..'Z', 'a'..'z', '_']);
    if not Result then Exit;
    for j := 2 to Length(S) do
      if not (S[j] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit(False);
  end;

  procedure CheckUnit(const AUnitPath, AUnit: string);
  var
    src, pot: TStringList;
    i, k, eq, depth, seen: Integer;
    line, id, missing, potText: string;
    inBlock: Boolean;
  begin
    AssertTrue('found the .pot', FileExists(LanguagesDir + AUnit + '.pot'));
    pot := TStringList.Create;
    src := TStringList.Create;
    try
      pot.LoadFromFile(LanguagesDir + AUnit + '.pot');
      potText := LowerCase(pot.Text);
      src.LoadFromFile(RepoRoot + AUnitPath);
      inBlock := False;
      depth   := 0;
      seen    := 0;
      missing := '';
      for i := 0 to src.Count - 1 do
      begin
        line := src[i];
        { brace depth first: a comment's continuation lines do not start with a brace }
        if depth > 0 then
        begin
          for k := 1 to Length(line) do
            if line[k] = '}' then Dec(depth) else if line[k] = '{' then Inc(depth);
          Continue;
        end;
        for k := 1 to Length(line) do
          if line[k] = '{' then Inc(depth) else if line[k] = '}' then Dec(depth);
        if depth > 0 then Continue;
        line := Trim(line);
        if LowerCase(line) = 'resourcestring' then begin inBlock := True; Continue; end;
        if not inBlock then Continue;
        if (LowerCase(line) = 'implementation') or (LowerCase(line) = 'type')
           or (LowerCase(line) = 'var') or (LowerCase(line) = 'const') then
        begin
          inBlock := False;
          Continue;
        end;
        if (line = '') or (Copy(line, 1, 2) = '//') then Continue;
        eq := Pos('=', line);
        if eq < 2 then Continue;
        id := Trim(Copy(line, 1, eq - 1));
        if not IsIdent(id) then Continue;
        Inc(seen);
        if Pos('#: ' + LowerCase(AUnit) + '.' + LowerCase(id) + LineEnding, potText) = 0 then
          missing := missing + LineEnding + '  ' + id;
      end;
      AssertTrue(AUnit + ': found its resourcestrings at all', seen > 0);
      AssertEquals('resourcestrings declared in ' + AUnit + ' with no .pot entry -- nobody '
        + 'can translate these:' + missing, '', missing);
    finally
      src.Free;
      pot.Free;
    end;
  end;

begin
  CheckUnit('source' + PathDelim + CHART_UNIT + '.pas', CHART_UNIT);
  CheckUnit('designtime' + PathDelim + 'tyControls.Design.AdvanceChart.Editor.pas',
    'tyControls.Design.AdvanceChart.Editor');
  CheckUnit('designtime' + PathDelim + 'tyControls.Design.AdvanceChart.SeriesDialog.pas',
    'tyControls.Design.AdvanceChart.SeriesDialog');
end;

{ A catalogue is applied by `<unit>.<identifier>`, lowercase. An entry under any other
  prefix -- the unit's name before a rename -- loads and is never used: the editor comes up
  in English. So every entry of the chart's three catalogues (its runtime strings and its
  two design-time units) carries its own unit's name and translates by that identifier
  alone (the sentinel original keeps TPOFile's fallback by English text from answering
  instead). }
procedure TAdvChartI18nTest.TestTheChartCataloguesBindToTheirUnits;
const
  UNITS: array[0..2] of string = ('tyControls.AdvanceChart.StrConsts',
    'tyControls.Design.AdvanceChart.Editor', 'tyControls.Design.AdvanceChart.SeriesDialog');
  NONE = '#untranslated#';
var
  f, id, bad: string;
  lines: TStringList;
  po: TPOFile;
  u, i, n: Integer;
begin
  bad := '';
  for u := 0 to High(UNITS) do
  begin
    f := LanguagesDir + LowerCase(UNITS[u]) + '.zh_CN.po';
    AssertTrue('catalogue exists: ' + f, FileExists(f));
    lines := TStringList.Create;
    po := TPOFile.Create(f);
    try
      lines.LoadFromFile(f);
      n := 0;
      for i := 0 to lines.Count - 1 do
        if Copy(lines[i], 1, 3) = '#: ' then
        begin
          Inc(n);
          id := Trim(Copy(lines[i], 4, MaxInt));
          if Pos(LowerCase(UNITS[u]) + '.', id) <> 1 then
            bad := bad + LineEnding + '  ' + ExtractFileName(f) + ': ' + id + ' (other unit)'
          else if po.Translate(id, NONE) = NONE then
            bad := bad + LineEnding + '  ' + ExtractFileName(f) + ': ' + id + ' (no translation)';
        end;
      AssertTrue(ExtractFileName(f) + ' has entries', n > 0);
    finally
      po.Free;
      lines.Free;
    end;
  end;
  AssertEquals('chart catalogue entries that do not bind:', '', bad);
end;

{ True when the UTF-8 bytes of S hold a CJK character: U+3000..U+9FFF (lead bytes E3..E9) or
  a fullwidth form, U+FF00..U+FFEF (EF BC..EF BF). '…' (E2 80 A6) and '»' are not. }
function HoldsCJK(const S: string): Boolean;
var
  i: Integer;
begin
  for i := 1 to Length(S) do
  begin
    if Ord(S[i]) in [$E3..$E9] then Exit(True);
    if (Ord(S[i]) = $EF) and (i < Length(S)) and (Ord(S[i + 1]) in [$BC..$BF]) then
      Exit(True);
  end;
  Result := False;
end;

{ The string literals of the unit at APath that hold CJK text, one 'unit:line: literal' a line.
  Comments are left out: // to the end of the line, (* *), and { } -- which nest in FPC. }
function ChineseLiterals(const APath: string): string;
var
  s, lit: string;
  i, j, n, line, depth: Integer;
  inParen: Boolean;
begin
  Result := '';
  s := ReadFileToString(APath);
  n := Length(s);
  i := 1;
  line := 1;
  depth := 0;
  inParen := False;
  while i <= n do
  begin
    if s[i] = #10 then Inc(line);
    if inParen then
    begin
      if (s[i] = '*') and (i < n) and (s[i + 1] = ')') then
      begin
        inParen := False;
        Inc(i, 2);
      end
      else
        Inc(i);
      Continue;
    end;
    if depth > 0 then
    begin
      if s[i] = '{' then Inc(depth)
      else if s[i] = '}' then Dec(depth);
      Inc(i);
      Continue;
    end;
    if s[i] = '{' then
    begin
      depth := 1;
      Inc(i);
      Continue;
    end;
    if (s[i] = '(') and (i < n) and (s[i + 1] = '*') then
    begin
      inParen := True;
      Inc(i, 2);
      Continue;
    end;
    if (s[i] = '/') and (i < n) and (s[i + 1] = '/') then
    begin
      while (i <= n) and (s[i] <> #10) do Inc(i);   { the #10 is counted on the next pass }
      Continue;
    end;
    if s[i] = '''' then
    begin
      j := i + 1;
      while (j <= n) and (s[j] <> #10) do
      begin
        if s[j] = '''' then
        begin
          if (j < n) and (s[j + 1] = '''') then
          begin
            Inc(j, 2);
            Continue;
          end;
          Break;
        end;
        Inc(j);
      end;
      lit := Copy(s, i, j - i + 1);
      if HoldsCJK(lit) then
        Result := Result + ExtractFileName(APath) + ':' + IntToStr(line) + ': ' + lit
          + LineEnding;
      i := j + 1;
      Continue;
    end;
    Inc(i);
  end;
end;

{ AdvChart's calendar carries ECharts' own name tables -- nameMap 'ZH' is these month and day
  names, picked by the chart's option as upstream picks them -- and recognises the system's
  Chinese day names by their prefix to shorten them. Data, not text written for a user. }
const
  AdvChartCalendarData: array[0..20] of string = (
    '''1月''', '''2月''', '''3月''', '''4月''', '''5月''', '''6月''', '''7月''', '''8月''',
    '''9月''', '''10月''', '''11月''', '''12月''',
    '''日''', '''一''', '''二''', '''三''', '''四''', '''五''', '''六''',
    '''周''', '''星期''');

  { AdvChart's geo carries ECharts' fixes for a map registered as 'china' (src/coord/geo/fix/
    nanhai.ts, textCoord.ts, diaoyuIsland.ts): region names matched against the map's own
    feature names, so they must be the names the map data uses. Data, not text for a user. }
  AdvChartGeoFixData: array[0..6] of string = (
    '''北京''', '''南海诸岛''', '''台湾''', '''天津''', '''广东''', '''澳门''', '''香港''');

{ AFound (ChineseLiterals' lines) without the lines whose literal is one of AExempt. }
function WithoutLiterals(const AFound: string; const AExempt: array of string): string;
var
  lines: TStringList;
  i, j, p: Integer;
  lit: string;
  keep: Boolean;
begin
  Result := '';
  lines := TStringList.Create;
  try
    lines.Text := AFound;
    for i := 0 to lines.Count - 1 do
    begin
      p := Pos(': ', lines[i]);
      lit := Copy(lines[i], p + 2, MaxInt);
      keep := True;
      for j := Low(AExempt) to High(AExempt) do
        if lit = AExempt[j] then keep := False;
      if keep then Result := Result + lines[i] + LineEnding;
    end;
  finally
    lines.Free;
  end;
end;

{ #68, the chart's half: TyControls' test.i18n scans the core's units, this scans the chart's.
  Text a user reads is a resourcestring, so a catalogue can translate it (CONTRIBUTING); an
  error raised at a developer is English, as every other one in the library is. This reads
  every unit under source/ for a string literal holding CJK text, comments left out. Two of
  them carry ECharts' own Chinese data and are let off literal by literal (above). }
procedure TAdvChartI18nTest.TestNoUnitHoldsChineseTextInAStringLiteral;
var
  files: TStringList;
  i, scanned: Integer;
  name, found: string;
begin
  files := FindAllFiles(RepoRoot + 'source', '*.pas;*.inc', True);
  try
    found := '';
    scanned := 0;
    for i := 0 to files.Count - 1 do
    begin
      name := ExtractFileName(files[i]);
      Inc(scanned);
      if SameText(name, 'tyControls.AdvanceChart.Calendar.pas') then
        found := found + WithoutLiterals(ChineseLiterals(files[i]), AdvChartCalendarData)
      else if SameText(name, 'tyControls.AdvanceChart.GeoFix.pas') then
        found := found + WithoutLiterals(ChineseLiterals(files[i]), AdvChartGeoFixData)
      else
        found := found + ChineseLiterals(files[i]);
    end;
    AssertTrue('the scan read the library (' + IntToStr(scanned) + ' units)', scanned > 100);
    AssertEquals('Chinese text in a string literal -- a resourcestring if a user reads it, '
      + 'English if it is an error for a developer:' + LineEnding + found, '', found);
  finally
    files.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartI18nTest);
end.
