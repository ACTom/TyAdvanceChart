unit test.advchart.delphisyntax;
{ Counts, in the chart's sources, the constructs Delphi's parser rejects, and pins today's
  counts. Each phase-1a rewrite task changes the one constant of its construct to 0 first (the
  test goes red), rewrites the sources (green), and commits. "In code" means in the result of
  TyPasCodeOnly: nothing inside a comment, a directive or a string counts. Names match whole
  words, ignoring case. A failure lists the first five places as file:line. }
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, fpcunit, testregistry, test.pascalscan;

const
  // The expected counts. Edit these, nothing else, to ratchet.
  ExpNestedBraceComments = 0;
  ExpObjFpcMode = 114;
  ExpFpcTypeNames = 506;
  ExpStringCaseLabels = 22;
  ExpCompoundAssignments = 0;
  ExpFpcOnlyKeywords = 5;
  ExpBarePushPop = 0;
  ExpConditionalSymbols = 0;
  ExpFpcOnlyNames = 417;

type
  TPascalScanTest = class(TTestCase)
  published
    procedure TestSplitsCodeStringComment;
    procedure TestBraceCommentNests;
    procedure TestDirectiveIsNotComment;
    procedure TestParenCommentKeepsBraces;
    procedure TestDoubledQuote;
    procedure TestCodeOnlyKeepsLength;
  end;

  TAdvChartDelphiSyntaxTest = class(TTestCase)
  published
    procedure TestNestedBraceComments;
    procedure TestObjFpcMode;
    procedure TestFpcTypeNames;
    procedure TestStringCaseLabels;
    procedure TestCompoundAssignments;
    procedure TestFpcOnlyKeywords;
    procedure TestBarePushPop;
    procedure TestConditionalSymbols;
    procedure TestFpcOnlyNames;
  end;

implementation

procedure TPascalScanTest.TestSplitsCodeStringComment;
var
  s: TTyPasSegs;
begin
  s := TyPasScan('a := ''x{y}''; // {z' + #10 + 'b');
  AssertEquals('segments', 5, Length(s));
  AssertTrue(s[0].Kind = pskCode);
  AssertTrue(s[1].Kind = pskString);
  AssertTrue(s[2].Kind = pskCode);
  AssertTrue(s[3].Kind = pskLineComment);
  AssertTrue(s[4].Kind = pskCode);
  AssertEquals('string length', 6, s[1].Len);
  AssertEquals('string start', 6, s[1].Start);
  AssertEquals('line of the code segment that starts at the line end', 1, s[4].Line);
  AssertEquals('line of a comment on line 2', 2, TyPasScan('a' + #10 + '{x}')[1].Line);
end;

procedure TPascalScanTest.TestBraceCommentNests;
var
  s: TTyPasSegs;
begin
  s := TyPasScan('{ a { b } c } x');
  AssertEquals('segments', 2, Length(s));
  AssertTrue(s[0].Kind = pskBraceComment);
  AssertEquals(13, s[0].Len);
  AssertTrue(s[0].Nested);
  AssertTrue(s[1].Kind = pskCode);
end;

procedure TPascalScanTest.TestDirectiveIsNotComment;
var
  s: TTyPasSegs;
begin
  s := TyPasScan('{$IFDEF FPC}x{$ENDIF}');
  AssertEquals('segments', 3, Length(s));
  AssertTrue(s[0].Kind = pskDirective);
  AssertTrue(s[1].Kind = pskCode);
  AssertTrue(s[2].Kind = pskDirective);
end;

procedure TPascalScanTest.TestParenCommentKeepsBraces;
var
  s: TTyPasSegs;
begin
  s := TyPasScan('(* a { b *) x');
  AssertEquals('segments', 2, Length(s));
  AssertTrue(s[0].Kind = pskParenComment);
  AssertFalse(s[0].Nested);
  AssertEquals(11, s[0].Len);
  AssertTrue(s[1].Kind = pskCode);
end;

procedure TPascalScanTest.TestDoubledQuote;
var
  s: TTyPasSegs;
begin
  // 'it''s' and '''' with a space between (without it they would read as one string)
  s := TyPasScan('''it''''s'' ' + '''''''''');
  AssertEquals('segments', 3, Length(s));
  AssertTrue(s[0].Kind = pskString);
  AssertTrue(s[1].Kind = pskCode);
  AssertTrue(s[2].Kind = pskString);
  AssertEquals(7, s[0].Len);
  AssertEquals(4, s[2].Len);
end;

procedure TPascalScanTest.TestCodeOnlyKeepsLength;
const
  Src = 'x{c}y''ab''//z';
begin
  AssertEquals('x   y''SS''   ', TyPasCodeOnly(Src));
  AssertEquals(Length(Src), Length(TyPasCodeOnly(Src)));
end;

{ ---- the sources, scanned once for the life of the process ---- }

type
  TSourceFile = class
    Name: string;
    Text: string;
    Code: string;
    Segs: TTyPasSegs;
    LineStarts: array of Integer;   // offset of the first character of each line
  end;

var
  Files: TList = nil;

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

function Lower(const S: string): string;
var
  i: Integer;
begin
  Result := S;
  for i := 1 to Length(Result) do
    if Result[i] in ['A'..'Z'] then
      Inc(Result[i], 32);
end;

function NoSpaces(const S: string): string;
var
  i, k: Integer;
begin
  SetLength(Result, Length(S));
  k := 0;
  for i := 1 to Length(S) do
    if not (S[i] in [' ', #9]) then
    begin
      Inc(k);
      Result[k] := S[i];
    end;
  SetLength(Result, k);
end;

procedure Load;
var
  names: TStringList;
  sr: TSearchRec;
  dir: string;
  pat: array[0..1] of string = ('*.pas', '*.inc');
  i, p, n, k: Integer;
  f: TSourceFile;
begin
  if Files <> nil then
    Exit;
  Files := TList.Create;
  dir := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + 'source') + PathDelim;
  names := TStringList.Create;
  try
    for k := 0 to 1 do
      if FindFirst(dir + pat[k], faAnyFile, sr) = 0 then
      begin
        repeat
          names.Add(sr.Name);
        until FindNext(sr) <> 0;
        FindClose(sr);
      end;
    names.Sort;
    for i := 0 to names.Count - 1 do
    begin
      f := TSourceFile.Create;
      f.Name := names[i];
      f.Text := ReadWhole(dir + names[i]);
      f.Segs := TyPasScan(f.Text);
      f.Code := TyPasCodeOnly(f.Text);
      n := 1;
      for p := 1 to Length(f.Text) do
        if f.Text[p] = #10 then
          Inc(n);
      SetLength(f.LineStarts, n);
      f.LineStarts[0] := 1;
      n := 0;
      for p := 1 to Length(f.Text) do
        if f.Text[p] = #10 then
        begin
          Inc(n);
          f.LineStarts[n] := p + 1;
        end;
      Files.Add(f);
    end;
  finally
    names.Free;
  end;
  if Files.Count = 0 then
    TTestCase.Fail('no source files found next to the tests');
end;

function FileAt(AIndex: Integer): TSourceFile;
begin
  Result := TSourceFile(Files[AIndex]);
end;

function LineOf(AFile: TSourceFile; APos: Integer): Integer;
var
  lo, hi, mid: Integer;
begin
  lo := 0;
  hi := High(AFile.LineStarts);
  while lo < hi do
  begin
    mid := (lo + hi + 1) div 2;
    if AFile.LineStarts[mid] <= APos then
      lo := mid
    else
      hi := mid - 1;
  end;
  Result := lo + 1;
end;

function LineText(AFile: TSourceFile; ALine: Integer): string;
var
  a, b: Integer;
begin
  a := AFile.LineStarts[ALine - 1];
  b := a;
  while (b <= Length(AFile.Text)) and (AFile.Text[b] <> #10) do
    Inc(b);
  Result := Copy(AFile.Text, a, b - a);
end;

function LineHasIfdefFpc(AFile: TSourceFile; ALine: Integer): Boolean;
begin
  Result := Pos('{$ifdeffpc}', NoSpaces(Lower(LineText(AFile, ALine)))) > 0;
end;

function DirectiveText(AFile: TSourceFile; const ASeg: TTyPasSeg): string;
begin
  Result := NoSpaces(Lower(Copy(AFile.Text, ASeg.Start, ASeg.Len)));
end;

function IsIdentChar(C: Char): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

type
  { The places a construct was found. }
  TFinds = class
    Count: Integer;
    First: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Add(AFile: TSourceFile; ALine: Integer);
    procedure Check(const AWhat: string; AExpected: Integer);
  end;

constructor TFinds.Create;
begin
  inherited Create;
  First := TStringList.Create;
end;

destructor TFinds.Destroy;
begin
  First.Free;
  inherited Destroy;
end;

procedure TFinds.Add(AFile: TSourceFile; ALine: Integer);
begin
  Inc(Count);
  if First.Count < 5 then
    First.Add(AFile.Name + ':' + IntToStr(ALine));
end;

procedure TFinds.Check(const AWhat: string; AExpected: Integer);
var
  s: string;
  i: Integer;
begin
  s := '';
  for i := 0 to First.Count - 1 do
  begin
    if s <> '' then
      s := s + ', ';
    s := s + First[i];
  end;
  if Count <> AExpected then
    TTestCase.Fail(Format('%s: expected %d, found %d; first places: %s',
      [AWhat, AExpected, Count, s]));
end;

type
  { Walks the identifiers of the code-only text of every file; a descendant says what it counts. }
  TWordWalker = class
    Finds: TFinds;
    constructor Create;
    destructor Destroy; override;
    procedure OnWord(AFile: TSourceFile; const AWord: string; AStart, AEnd: Integer); virtual; abstract;
    procedure Walk;
  end;

  TNameCounter = class(TWordWalker)
    Wanted: array of string;
    SkipFpcLines: Boolean;
    constructor Create(const AWanted: array of string; ASkipFpcLines: Boolean);
    procedure OnWord(AFile: TSourceFile; const AWord: string; AStart, AEnd: Integer); override;
  end;

  TKeywordCounter = class(TWordWalker)
    procedure OnWord(AFile: TSourceFile; const AWord: string; AStart, AEnd: Integer); override;
  end;

constructor TWordWalker.Create;
begin
  inherited Create;
  Finds := TFinds.Create;
end;

destructor TWordWalker.Destroy;
begin
  Finds.Free;
  inherited Destroy;
end;

procedure TWordWalker.Walk;
var
  f: TSourceFile;
  c: string;
  k, i, j, n: Integer;
begin
  Load;
  for k := 0 to Files.Count - 1 do
  begin
    f := FileAt(k);
    c := f.Code;
    n := Length(c);
    i := 1;
    while i <= n do
      if IsIdentChar(c[i]) then
      begin
        j := i;
        while (j <= n) and IsIdentChar(c[j]) do
          Inc(j);
        OnWord(f, Lower(Copy(c, i, j - i)), i, j);
        i := j;
      end
      else
        Inc(i);
  end;
end;

constructor TNameCounter.Create(const AWanted: array of string; ASkipFpcLines: Boolean);
var
  i: Integer;
begin
  inherited Create;
  SetLength(Wanted, Length(AWanted));
  for i := 0 to High(AWanted) do
    Wanted[i] := Lower(AWanted[i]);
  SkipFpcLines := ASkipFpcLines;
end;

procedure TNameCounter.OnWord(AFile: TSourceFile; const AWord: string; AStart, AEnd: Integer);
var
  i, ln: Integer;
begin
  for i := 0 to High(Wanted) do
    if Wanted[i] = AWord then
    begin
      ln := LineOf(AFile, AStart);
      if not (SkipFpcLines and LineHasIfdefFpc(AFile, ln)) then
        Finds.Add(AFile, ln);
      Exit;
    end;
end;

procedure TKeywordCounter.OnWord(AFile: TSourceFile; const AWord: string; AStart, AEnd: Integer);
var
  j: Integer;
begin
  if (AWord = 'specialize') or (AWord = 'generic') then
    Finds.Add(AFile, LineOf(AFile, AStart))
  else if AWord = 'is' then
  begin
    j := AEnd;
    while (j <= Length(AFile.Code)) and (AFile.Code[j] in [' ', #9, #10, #13]) do
      Inc(j);
    // is + white space + the whole word nested
    if (j > AEnd) and (Lower(Copy(AFile.Code, j, 6)) = 'nested') and
       ((j + 6 > Length(AFile.Code)) or not IsIdentChar(AFile.Code[j + 6])) then
      Finds.Add(AFile, LineOf(AFile, AStart));
  end;
end;

procedure CountNames(const AWhat: string; const AWanted: array of string; ASkipFpcLines: Boolean;
  AExpected: Integer);
var
  w: TNameCounter;
begin
  w := TNameCounter.Create(AWanted, ASkipFpcLines);
  try
    w.Walk;
    w.Finds.Check(AWhat, AExpected);
  finally
    w.Free;
  end;
end;

{ ---- the tests ---- }

procedure TAdvChartDelphiSyntaxTest.TestNestedBraceComments;
var
  finds: TFinds;
  i, k: Integer;
begin
  Load;
  finds := TFinds.Create;
  try
    for i := 0 to Files.Count - 1 do
      for k := 0 to High(FileAt(i).Segs) do
        if (FileAt(i).Segs[k].Kind = pskBraceComment) and FileAt(i).Segs[k].Nested then
          finds.Add(FileAt(i), FileAt(i).Segs[k].Line);
    finds.Check('brace comments with a { inside', ExpNestedBraceComments);
  finally
    finds.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestObjFpcMode;
var
  finds: TFinds;
  i, k: Integer;
  f: TSourceFile;
begin
  Load;
  finds := TFinds.Create;
  try
    for i := 0 to Files.Count - 1 do
    begin
      f := FileAt(i);
      for k := 0 to High(f.Segs) do
        if (f.Segs[k].Kind = pskDirective) and (DirectiveText(f, f.Segs[k]) = '{$modeobjfpc}') then
          finds.Add(f, f.Segs[k].Line);
    end;
    finds.Check('{$mode objfpc}', ExpObjFpcMode);
  finally
    finds.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestFpcTypeNames;
begin
  CountNames('FPC type names', ['QWord', 'PQWord', 'PtrInt', 'PtrUInt', 'SizeInt', 'LongWord',
    'LongInt'], False, ExpFpcTypeNames);
end;

{ The unescaped length of a string literal, given the text between its outer quotes. }
function UnescapedLength(const AInner: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  i := 1;
  while i <= Length(AInner) do
  begin
    if (AInner[i] = '''') and (i < Length(AInner)) and (AInner[i + 1] = '''') then
      Inc(i);
    Inc(i);
    Inc(Result);
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestStringCaseLabels;
{ A line that starts with 'x'[, 'y']: (not :=) in code, with a literal that is not one character
  long. The line is found in the code-only text, where a literal is two quotes around S
  characters; the length is taken from the original text at the same place. }
var
  finds: TFinds;
  i, ln, p, q, lineEnd: Integer;
  f: TSourceFile;
  code: string;
  ok, odd: Boolean;
begin
  Load;
  finds := TFinds.Create;
  try
    for i := 0 to Files.Count - 1 do
    begin
      f := FileAt(i);
      code := f.Code;
      for ln := 1 to Length(f.LineStarts) do
      begin
        p := f.LineStarts[ln - 1];
        lineEnd := p;
        while (lineEnd <= Length(code)) and (code[lineEnd] <> #10) do
          Inc(lineEnd);
        while (p < lineEnd) and (code[p] in [' ', #9]) do
          Inc(p);
        odd := False;
        ok := False;
        while (p < lineEnd) and (code[p] = '''') do
        begin
          q := p + 1;
          while (q < lineEnd) and (code[q] = 'S') do
            Inc(q);
          if (q >= lineEnd) or (code[q] <> '''') then
            Break;
          if UnescapedLength(Copy(f.Text, p + 1, q - p - 1)) <> 1 then
            odd := True;
          p := q + 1;
          while (p < lineEnd) and (code[p] in [' ', #9]) do
            Inc(p);
          if (p < lineEnd) and (code[p] = ',') then
          begin
            Inc(p);
            while (p < lineEnd) and (code[p] in [' ', #9]) do
              Inc(p);
            Continue;
          end;
          ok := (p < lineEnd) and (code[p] = ':') and
            not ((p + 1 < lineEnd) and (code[p + 1] = '='));
          Break;
        end;
        if ok and odd then
          finds.Add(f, ln);
      end;
    end;
    finds.Check('case labels that are strings of other than one character', ExpStringCaseLabels);
  finally
    finds.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestCompoundAssignments;
var
  finds: TFinds;
  i, p: Integer;
  f: TSourceFile;
begin
  Load;
  finds := TFinds.Create;
  try
    for i := 0 to Files.Count - 1 do
    begin
      f := FileAt(i);
      for p := 1 to Length(f.Code) - 1 do
        if (f.Code[p] in ['+', '-', '*', '/']) and (f.Code[p + 1] = '=') then
          finds.Add(f, LineOf(f, p));
    end;
    finds.Check('+= -= *= /=', ExpCompoundAssignments);
  finally
    finds.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestFpcOnlyKeywords;
var
  w: TKeywordCounter;
begin
  w := TKeywordCounter.Create;
  try
    w.Walk;
    w.Finds.Check('specialize, generic, is nested', ExpFpcOnlyKeywords);
  finally
    w.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestBarePushPop;
var
  finds: TFinds;
  i, k: Integer;
  f: TSourceFile;
  d: string;
begin
  Load;
  finds := TFinds.Create;
  try
    for i := 0 to Files.Count - 1 do
    begin
      f := FileAt(i);
      for k := 0 to High(f.Segs) do
        if f.Segs[k].Kind = pskDirective then
        begin
          d := DirectiveText(f, f.Segs[k]);
          if ((d = '{$push}') or (d = '{$pop}')) and not LineHasIfdefFpc(f, f.Segs[k].Line) then
            finds.Add(f, f.Segs[k].Line);
        end;
    end;
    finds.Check('{$push} / {$pop} outside {$IFDEF FPC}', ExpBarePushPop);
  finally
    finds.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestConditionalSymbols;
var
  finds: TFinds;
  i, k: Integer;
  f: TSourceFile;
  d: string;
begin
  Load;
  finds := TFinds.Create;
  try
    for i := 0 to Files.Count - 1 do
    begin
      f := FileAt(i);
      for k := 0 to High(f.Segs) do
        if f.Segs[k].Kind = pskDirective then
        begin
          d := DirectiveText(f, f.Segs[k]);
          if (d = '{$ifdefcpux86_64}') or (d = '{$ifndefcpux86_64}') or
             (d = '{$ifdefwindows}') or (d = '{$ifndefwindows}') then
            finds.Add(f, f.Segs[k].Line);
        end;
    end;
    finds.Check('{$IFDEF/IFNDEF CPUX86_64 or WINDOWS}', ExpConditionalSymbols);
  finally
    finds.Free;
  end;
end;

procedure TAdvChartDelphiSyntaxTest.TestFpcOnlyNames;
begin
  CountNames('FPC-only names outside {$IFDEF FPC} lines', ['DefaultFormatSettings', 'LineEnding',
    'SarLongint', 'StrToQWord'], True, ExpFpcOnlyNames);
end;

initialization
  RegisterTest(TPascalScanTest);
  RegisterTest(TAdvChartDelphiSyntaxTest);
end.
