{ Copied from TyControls tests/test.dpi.controls.pas at 77860b40. }
unit test.advchart.dpicontrols;
{ What the painter scales must not arrive scaled.                    (TyControls #2)

  The painter takes a border width, a corner radius, a glyph's thickness and pad, a font size, a
  line height and a shadow's blur in LOGICAL px and scales them itself; its rectangles are device
  px. So `P.StrokeBorder(R, 0, P.Scale(2), c)` scales the 2 twice, and reads perfectly well.
  TyControls' TTyControlDpiTest.TestNothingScaledIsHandedToAParameterThatScales reads the
  library's own source for that shape, and read the chart's units and include files with the
  core's until the chart moved here. The same reading runs over this repository's source/*.pas
  and *.inc (test.designregistry's LibrarySourceFiles), with the same self-checks on samples
  first. The suite's other tests are the core controls' own, and stay there. }
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, StrUtils, fpcunit, testregistry,
  test.dpi.support, test.designregistry;

type
  TAdvChartDpiControlsTest = class(TTestCase)
  published
    procedure TestNothingScaledIsHandedToAParameterThatScales;
  end;

implementation

{ ===== what the painter scales must not arrive scaled ======================= }

type
  TLogicalCallee = record
    Name: string;                  // lower case
    { 0-based positions of the parameters that are LOGICAL px; -1 unused;
      100 the last argument, 101 the one before it. }
    P: array[0..3] of Integer;
    Font: Integer;                 // which of them is a FONT SIZE, -1 none
  end;

const
  CLogical: array[0..17] of TLogicalCallee = (
    (Name: 'strokeborder';               P: (1, 2, -1, -1);   Font: -1),
    (Name: 'fillbackground';             P: (2, -1, -1, -1);  Font: -1),
    (Name: 'drawedge';                   P: (1, -1, -1, -1);  Font: -1),
    (Name: 'dropshadow';                 P: (1, 3, 4, -1);    Font: -1),
    (Name: 'drawtext';                   P: (3, 12, -1, -1);  Font: 3),
    (Name: 'measuretext';                P: (2, -1, -1, -1);  Font: 2),
    (Name: 'drawglyph';                  P: (3, 4, -1, -1);   Font: -1),
    (Name: 'tydrawglyph';                P: (100, 101, -1, -1); Font: -1),
    (Name: 'drawdropchevron';            P: (2, -1, -1, -1);  Font: -1),
    (Name: 'fillpointershape';           P: (9, -1, -1, -1);  Font: -1),
    (Name: 'drawimagefill';              P: (3, -1, -1, -1);  Font: -1),
    (Name: 'tyuniformcorners';           P: (0, -1, -1, -1);  Font: -1),
    (Name: 'tycorners';                  P: (0, 1, 2, 3);     Font: -1),
    (Name: 'tymeasuretextblock';         P: (2, 6, -1, -1);   Font: 2),
    (Name: 'tymeasurerenderedtextwidth'; P: (2, -1, -1, -1);  Font: 2),
    (Name: 'tyconfiguretextfont';        P: (2, -1, -1, -1);  Font: 2),
    (Name: 'tyconfiguremeasurefont';     P: (2, -1, -1, -1);  Font: 2),
    (Name: 'tyfontheightpx';             P: (0, -1, -1, -1);  Font: 0));

function IsIdentChar(c: Char): Boolean;
begin
  Result := c in ['a'..'z', 'A'..'Z', '0'..'9', '_'];
end;

{ Is there a CALL of AName in S: the whole name, then '(' ? }
function HasCall(const S, AName: string): Boolean;
var
  p, q, n: Integer;
begin
  Result := False;
  n := Length(S);
  p := 1;
  while p <= n do
  begin
    p := Pos(AName, S, p);
    if p = 0 then Exit;
    q := p + Length(AName);
    if ((p = 1) or not IsIdentChar(S[p - 1])) then
    begin
      while (q <= n) and (S[q] in [' ', #9, #13, #10]) do Inc(q);
      if (q <= n) and (S[q] = '(') then Exit(True);
    end;
    Inc(p);
  end;
end;

{ Is there anything in S that is measured in DEVICE px: the size of a control or a side of
  a rectangle. A style's Padding.Left is a side too, and logical -- so the owner is asked. }
function HasGeometry(const S: string): Boolean;
const
  CSides: array[0..3] of string = ('.left', '.top', '.right', '.bottom');
  CSizes: array[0..3] of string = ('clientwidth', 'clientheight', 'width', 'height');
var
  k, p, q, n: Integer;
  owner: string;
begin
  Result := False;
  n := Length(S);
  for k := 0 to High(CSizes) do
  begin
    p := 1;
    while p <= n do
    begin
      p := Pos(CSizes[k], S, p);
      if p = 0 then Break;
      q := p + Length(CSizes[k]);
      if ((p = 1) or not IsIdentChar(S[p - 1])) and ((q > n) or not IsIdentChar(S[q])) then
        Exit(True);
      Inc(p);
    end;
  end;
  for k := 0 to High(CSides) do
  begin
    p := 1;
    while p <= n do
    begin
      p := Pos(CSides[k], S, p);
      if p = 0 then Break;
      q := p + Length(CSides[k]);
      if (q > n) or not IsIdentChar(S[q]) then
      begin
        q := p - 1;
        while (q >= 1) and IsIdentChar(S[q]) do Dec(q);
        owner := Copy(S, q + 1, p - q - 1);
        if (Pos('padding', owner) = 0) and (Pos('margin', owner) = 0)
           and (Pos('inset', owner) = 0) and (Pos('offset', owner) = 0)
           and (owner <> 'pad') and (owner <> 'hpad') then
          Exit(True);
      end;
      Inc(p);
    end;
  end;
end;

{ Is AExpr (lower case) a value in DEVICE px? }
function IsDeviceValue(const AExpr: string; AFont: Boolean): Boolean;
var
  packed_: string;
begin
  { Taken back to logical on the way: P.Unscale(x), MulDiv(x, 96, PPI). }
  if Pos('unscale', AExpr) > 0 then Exit(False);
  packed_ := StringReplace(AExpr, ' ', '', [rfReplaceAll]);
  if Pos(',96,', packed_) > 0 then Exit(False);
  Result := HasCall(AExpr, 'scale') or HasCall(AExpr, 'scalei') or HasCall(AExpr, 'scalepx')
    or HasCall(AExpr, 'px') or HasCall(AExpr, 'dp') or HasCall(AExpr, 'muldiv');
  { A font size worked out from the size of something is device px whoever scaled it. }
  if (not Result) and AFont then Result := HasGeometry(AExpr);
end;

{ The arguments of the call whose '(' is at AOpen. False when it is not a complete call. }
function SplitArguments(const S: string; AOpen: Integer; AArgs: TStrings): Boolean;
var
  i, n, depth, from: Integer;
begin
  Result := False;
  AArgs.Clear;
  n := Length(S);
  depth := 0;
  from := AOpen + 1;
  i := AOpen;
  while i <= n do
  begin
    case S[i] of
      '(', '[': Inc(depth);
      ')', ']':
        begin
          Dec(depth);
          if depth = 0 then
          begin
            AArgs.Add(Trim(Copy(S, from, i - from)));
            Exit(True);
          end;
        end;
      ',':
        if depth = 1 then
        begin
          AArgs.Add(Trim(Copy(S, from, i - from)));
          from := i + 1;
        end;
      ';':
        if depth <= 1 then Exit;
    end;
    Inc(i);
  end;
end;

{ Where the routine that contains APos starts. }
function RoutineStart(const S: string; APos: Integer): Integer;
const
  CHeads: array[0..3] of string = ('procedure ', 'function ', 'constructor ', 'destructor ');
var
  k, p, best: Integer;
begin
  best := 1;
  for k := 0 to High(CHeads) do
  begin
    p := RPosEx(#10 + CHeads[k], S, APos);
    if p > best then best := p;
  end;
  Result := best;
end;

{ What AIdent was given, between AFrom and ATo: the right-hand side of each `AIdent := ...;`
  that is a device value, or ''. }
function DeviceAssignment(const S, AIdent: string; AFrom, ATo: Integer; AFont: Boolean): string;
var
  p, q, e: Integer;
  rhs: string;
begin
  Result := '';
  p := AFrom;
  while True do
  begin
    p := Pos(AIdent, S, p);
    if (p = 0) or (p >= ATo) then Exit;
    q := p + Length(AIdent);
    if ((p = 1) or not (IsIdentChar(S[p - 1]) or (S[p - 1] = '.')))
       and (q <= Length(S)) and not IsIdentChar(S[q]) then
    begin
      while (q <= Length(S)) and (S[q] in [' ', #9, #13, #10]) do Inc(q);
      if Copy(S, q, 2) = ':=' then
      begin
        e := Pos(';', S, q);
        if e = 0 then e := Length(S) + 1;
        rhs := Trim(Copy(S, q + 2, e - q - 2));
        { `for i := a to b do` is not a value. }
        if (Pos(' to ', rhs) = 0) and (Pos(' downto ', rhs) = 0)
           and IsDeviceValue(rhs, AFont) then
          Exit(rhs);
      end;
    end;
    Inc(p);
  end;
end;

{ Every place in ACode where a device value is handed to a parameter that is logical,
  one line each in AOut. ACode: comments and literals already blanked. }
procedure FindScaledArguments(const ACode, AUnit: string; AOut: TStrings);
var
  lc, arg, rhs, head: string;
  args: TStringList;
  k, a, p, q, n, idx, ls, i: Integer;
  simple, font: Boolean;
begin
  lc := LowerCase(ACode);
  n := Length(lc);
  args := TStringList.Create;
  try
    for k := 0 to High(CLogical) do
    begin
      p := 1;
      while p <= n do
      begin
        p := Pos(CLogical[k].Name, lc, p);
        if p = 0 then Break;
        q := p + Length(CLogical[k].Name);
        Inc(p);
        if (p > 2) and IsIdentChar(lc[p - 2]) then Continue;
        while (q <= n) and (lc[q] in [' ', #9, #13, #10]) do Inc(q);
        if (q > n) or (lc[q] <> '(') then Continue;
        { A declaration has the same shape as a call. }
        ls := RPosEx(#10, lc, p - 1);
        head := TrimLeft(Copy(lc, ls + 1, p - 1 - ls - 1));
        if (Copy(head, 1, 9) = 'procedure') or (Copy(head, 1, 8) = 'function') then Continue;
        if not SplitArguments(lc, q, args) then Continue;
        for a := 0 to High(CLogical[k].P) do
        begin
          idx := CLogical[k].P[a];
          if idx < 0 then Continue;
          font := (CLogical[k].Font = idx);
          if idx >= 100 then idx := args.Count - 1 - (idx - 100);
          if (idx < 0) or (idx >= args.Count) then Continue;
          arg := args[idx];
          if arg = '' then Continue;
          if IsDeviceValue(arg, font) then
          begin
            AOut.Add(Format('%s: %s(... %s ...)', [AUnit, CLogical[k].Name, arg]));
            Continue;
          end;
          simple := not (arg[1] in ['0'..'9']);
          for i := 1 to Length(arg) do
            if not IsIdentChar(arg[i]) then simple := False;
          if not simple then Continue;
          rhs := DeviceAssignment(lc, arg, RoutineStart(lc, p), p, font);
          if rhs <> '' then
            AOut.Add(Format('%s: %s(... %s ...)  where  %s := %s', [AUnit, CLogical[k].Name,
              arg, arg, rhs]));
        end;
      end;
    end;
  finally
    args.Free;
  end;
end;

procedure TAdvChartDpiControlsTest.TestNothingScaledIsHandedToAParameterThatScales;
{ The painter takes a border width, a corner radius, a glyph's thickness and pad, a font
  size, a line height and a shadow's blur in LOGICAL px and scales them itself; its
  rectangles are device px. So `P.StrokeBorder(R, 0, P.Scale(2), c)` scales the 2 twice,
  and reads perfectly well. Ten places did, the gauge's figure among them: each was right
  at 100% and 1.75x too thick, too round or too tall at 175%.

  A rule about the SOURCE, because nothing else finds a line that is 7 px where it should
  be 4: no picture test looks that closely at every control. }

  function Count(const ASource: string): Integer;
  var
    sl: TStringList;
  begin
    sl := TStringList.Create;
    try
      FindScaledArguments(TyTestCodeOnly(ASource), 'sample', sl);
      Result := sl.Count;
    finally
      sl.Free;
    end;
  end;

var
  files, sl, bad: TStringList;
  i: Integer;
begin
  AssertEquals('a scaled width', 1, Count('begin P.StrokeBorder(R, 0, P.Scale(2), c); end;'));
  AssertEquals('a scaled radius', 1, Count('begin P.FillBackground(R, fill, ScaleI(3)); end;'));
  AssertEquals('a width that was scaled two lines earlier', 1, Count(#10'procedure A;'#10
    + 'begin w := Max(1, P.Scale(1)); P.StrokeBorder(R, 0, w, c); end;'));
  AssertEquals('a font size taken from the size of the thing', 1, Count(#10'procedure A;'#10
    + 'begin fs := (R.Bottom - R.Top) div 6;'
    + ' P.DrawText(R, s, n, fs, 400, c, taCenter, tlCenter, False); end;'));
  AssertEquals('the thickness of a glyph, through the wrapper', 1,
    Count('begin TyDrawGlyph(P, ctl, R, tgCheck, c, P.Scale(2), 1); end;'));
  AssertEquals('...and what is right: a literal, a style field, a rectangle built from'
    + ' scaled numbers, a value taken back to logical, a declaration', 0,
    Count(#10'procedure TTyPainter.StrokeBorder(const ARect: TRect; ARadiusLogical,'
      + ' AWidthLogical: Integer; AColor: TTyColor);'#10
      + 'begin P.StrokeBorder(R, S.BorderRadius, 2, c);'
      + ' P.FillBackground(Rect(a, b, a + P.Scale(8), b + P.Scale(8)), fill, 3);'
      + ' P.StrokeBorder(R, P.Unscale(h) div 2, 1, c);'
      + ' P.DrawText(R, s, n, Max(9, MulDiv(h div 6, 96, P.PPI)), 400, c, a, l, False);'
      + ' P.DrawText(R, s, n, S.FontSize, 400, c, a, l, False);'
      + ' for i := 0 to Scale(3) do P.DrawEdge(R, i, c, c); end;'));

  files := LibrarySourceFiles;
  sl := TStringList.Create;
  bad := TStringList.Create;
  try
    AssertTrue('the library''s units were found', files.Count > 100);
    files.Sort;
    for i := 0 to files.Count - 1 do
    begin
      sl.LoadFromFile(files[i]);
      FindScaledArguments(TyTestCodeOnly(sl.Text), ExtractFileName(files[i]), bad);
    end;
    AssertEquals('a value that is already device px is handed to a parameter the callee'
      + ' scales. Pass the LOGICAL number (or P.Unscale the device one):' + LineEnding
      + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    sl.Free;
    files.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartDpiControlsTest);

end.
