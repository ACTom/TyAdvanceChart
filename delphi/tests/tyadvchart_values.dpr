{ Checks, under Delphi, the values of the helpers that have a branch of their own for it.
  Built and run by scripts/delphi-probe.py --values with dcc32 and dcc64; not compiled by FPC.
  Prints DELPHI VALUES OK as its last line when every check holds, else the failed check and exit code 1. }
program tyadvchart_values;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  tyControls.AdvanceChart.JsMath,
  tyControls.AdvanceChart.NativeStr,
  tyControls.AdvanceChart.Types;

procedure Check(ACond: Boolean; const AWhat: string);
begin
  if not ACond then
  begin
    Writeln('FAILED: ' + AWhat);
    Halt(1);
  end;
end;

procedure CheckSar32;
begin
  Check(TySar32(5, 2) = 1, 'TySar32(5, 2) = 1');
  Check(TySar32(-5, 2) = -2, 'TySar32(-5, 2) = -2');
  Check(TySar32(-1, 31) = -1, 'TySar32(-1, 31) = -1');
  Check(TySar32(Low(Integer), 1) = -1073741824, 'TySar32(Low(Integer), 1) = -1073741824');
  Check(TySar32(High(Integer), 31) = 0, 'TySar32(High(Integer), 31) = 0');
  Check(TySar32(-7, 0) = -7, 'TySar32(-7, 0) = -7');
end;

procedure CheckIntToDouble;
begin
  Check(TyIntToDouble(0) = 0.0, 'TyIntToDouble(0) = 0');
  Check(TyIntToDouble(1) / 3 = Double(1.0) / 3, 'TyIntToDouble(1) / 3 = 1.0 / 3');
  Check(TyIntToDouble(-360) = -360.0, 'TyIntToDouble(-360) = -360');
  Check(TyIntToDouble(High(Integer)) = 2147483647.0, 'TyIntToDouble(High(Integer)) = 2147483647');
  Check(TyIntToDouble(Int64(9007199254740993)) = 9007199254740992.0, 'TyIntToDouble(2^53 + 1) rounds to even');
  Check(TyIntToDouble(Int64(9007199254740995)) = 9007199254740996.0, 'TyIntToDouble(2^53 + 3) rounds to even');
  Check(TyIntToDouble(Low(Int64)) = -9223372036854775808.0, 'TyIntToDouble(Low(Int64)) = -2^63');
end;

procedure CheckFloorCeil64;
begin
  Check(TyFloor64(2.5) = 2, 'TyFloor64(2.5) = 2');
  Check(TyFloor64(-2.5) = -3, 'TyFloor64(-2.5) = -3');
  Check(TyFloor64(-2.0) = -2, 'TyFloor64(-2.0) = -2');
  Check(TyFloor64(4294967296.5) = 4294967296, 'TyFloor64(4294967296.5) = 4294967296');
  Check(TyCeil64(2.5) = 3, 'TyCeil64(2.5) = 3');
  Check(TyCeil64(-2.5) = -2, 'TyCeil64(-2.5) = -2');
  Check(TyCeil64(2.0) = 2, 'TyCeil64(2.0) = 2');
  Check(TyCeil64(-4294967296.5) = -4294967296, 'TyCeil64(-4294967296.5) = -4294967296');
end;

procedure CheckBoolText;
begin
  Check(TyBoolText(True, 'yes', 'no') = 'yes', 'TyBoolText(True, ''yes'', ''no'') = ''yes''');
  Check(TyBoolText(False, 'yes', 'no') = 'no', 'TyBoolText(False, ''yes'', ''no'') = ''no''');
  Check(TyBoolText(False, 'c', '') = '', 'TyBoolText(False, ''c'', '''') = ''''');
end;

{ The same checks as tests/test.advchart.nativestr.pas, in UTF-16: a BMP character is one unit, a surrogate
  pair two. }
procedure CheckNativeStr;
const
  cGuo = #$56FD;
  cEAcute = #$00E9;
  cGrin = #$D83D#$DE00;
var
  u: UnicodeString;
  n: Integer;
begin
  Check(Length(TyJsUnits('a' + cGuo + cEAcute)) = 3, 'Length(TyJsUnits(a + U+56FD + U+00E9)) = 3');
  Check(Length(TyJsUnits(cGrin)) = 2, 'Length(TyJsUnits(U+1F600)) = 2');
  Check(Length(TyJsUnits('')) = 0, 'Length(TyJsUnits('''')) = 0');
  Check(Ord(TyJsUnits(cGuo)[1]) = $56FD, 'TyJsUnits(U+56FD)[1] = $56FD');
  u := TyJsUnits(cGrin);
  Check((Ord(u[1]) = $D83D) and (Ord(u[2]) = $DE00), 'TyJsUnits(U+1F600) = $D83D $DE00');

  Check(TyFromJsUnits(TyJsUnits('')) = '', 'round trip of ''''');
  Check(TyFromJsUnits(TyJsUnits('abc')) = 'abc', 'round trip of abc');
  Check(TyFromJsUnits(TyJsUnits('a' + cGuo + cEAcute)) = 'a' + cGuo + cEAcute, 'round trip of a + U+56FD + U+00E9');
  Check(TyFromJsUnits(TyJsUnits(cGrin + 'x')) = cGrin + 'x', 'round trip of U+1F600 + x');

  Check(TyCodePointStr($41) = 'A', 'TyCodePointStr($41) = A');
  Check(TyCodePointStr($E9) = cEAcute, 'TyCodePointStr($E9) = U+00E9');
  Check(TyCodePointStr($56FD) = cGuo, 'TyCodePointStr($56FD) = U+56FD');
  Check(TyCodePointStr($1F600) = cGrin, 'TyCodePointStr($1F600) = $D83D $DE00');
  Check(TyCodePointStr($7F) = #$7F, 'TyCodePointStr($7F) = $7F');
  Check(TyCodePointStr($80) = #$0080, 'TyCodePointStr($80) = $0080');
  Check(TyCodePointStr($7FF) = #$07FF, 'TyCodePointStr($7FF) = $07FF');
  Check(TyCodePointStr($800) = #$0800, 'TyCodePointStr($800) = $0800');
  Check(TyCodePointStr($FFFF) = #$FFFF, 'TyCodePointStr($FFFF) = $FFFF');
  Check(TyCodePointStr($10000) = #$D800#$DC00, 'TyCodePointStr($10000) = $D800 $DC00');
  Check(TyCodePointStr($10FFFF) = #$DBFF#$DFFF, 'TyCodePointStr($10FFFF) = $DBFF $DFFF');

  Check(TyFirstCharLen('') = 0, 'TyFirstCharLen('''') = 0');
  Check(TyFirstCharLen('abc') = 1, 'TyFirstCharLen(abc) = 1');
  Check(TyFirstCharLen(cGuo + 'a') = Length(cGuo), 'TyFirstCharLen(U+56FD + a) = Length(U+56FD)');
  Check(TyFirstCharLen(cGrin + 'a') = Length(cGrin), 'TyFirstCharLen(U+1F600 + a) = Length(U+1F600)');
  Check(TyFirstCharLen(cGuo) = 1, 'TyFirstCharLen(U+56FD) = 1');
  Check(TyFirstCharLen(cGrin) = 2, 'TyFirstCharLen(U+1F600) = 2');
  Check(TyFirstCharLen('a' + cGuo) = 1, 'TyFirstCharLen(a + U+56FD) = 1');

  Check(TyLastCharStart('') = 0, 'TyLastCharStart('''') = 0');
  Check(TyLastCharStart('abc') = 3, 'TyLastCharStart(abc) = 3');
  Check(TyLastCharStart('a' + cGuo) = 2, 'TyLastCharStart(a + U+56FD) = 2');
  Check(TyLastCharStart('a' + cGrin) = 2, 'TyLastCharStart(a + U+1F600) = 2');
  Check(TyLastCharStart(cGuo) = 1, 'TyLastCharStart(U+56FD) = 1');
  Check(TyLastCharStart(cGrin) = 1, 'TyLastCharStart(U+1F600) = 1');
  Check(TyLastCharStart(cGuo + 'a') = 2, 'TyLastCharStart(U+56FD + a) = 2');
  Check(TyLastCharStart(cGrin + 'a') = 3, 'TyLastCharStart(U+1F600 + a) = 3');

  Check((TyCodePointAt('A', 1, n) = $41) and (n = 1), 'TyCodePointAt(A, 1) = $41, len 1');
  Check((TyCodePointAt(cEAcute, 1, n) = $E9) and (n = 1), 'TyCodePointAt(U+00E9, 1) = $E9, len 1');
  Check((TyCodePointAt(cGuo, 1, n) = $56FD) and (n = 1), 'TyCodePointAt(U+56FD, 1) = $56FD, len 1');
  Check((TyCodePointAt(cGrin, 1, n) = $1F600) and (n = 2), 'TyCodePointAt(U+1F600, 1) = $1F600, len 2');
  Check((TyCodePointAt('a' + cGuo + 'b', 2, n) = $56FD) and (n = 1), 'TyCodePointAt(a + U+56FD + b, 2) = $56FD, len 1');
  Check((TyCodePointAt('a' + cGuo + 'b', 3, n) = $62) and (n = 1), 'TyCodePointAt(a + U+56FD + b, 3) = $62, len 1');
  Check((TyCodePointAt('a' + cGrin + 'b', 2, n) = $1F600) and (n = 2), 'TyCodePointAt(a + U+1F600 + b, 2) = $1F600, len 2');
  Check((TyCodePointAt('a' + cGrin + 'b', 4, n) = $62) and (n = 1), 'TyCodePointAt(a + U+1F600 + b, 4) = $62, len 1');
  Check((TyCodePointAt('a' + #$D83D, 2, n) = $D83D) and (n = 1), 'TyCodePointAt(a + lone high surrogate at the end, 2) = $D83D, len 1');
  Check((TyCodePointAt(#$D83D + 'a', 1, n) = $D83D) and (n = 1), 'TyCodePointAt(high surrogate + a, 1) = $D83D, len 1');
  Check((TyCodePointAt(#$DE00, 1, n) = $DE00) and (n = 1), 'TyCodePointAt(lone low surrogate, 1) = $DE00, len 1');
  Check((TyCodePointAt(cGrin, 2, n) = $DE00) and (n = 1), 'TyCodePointAt(U+1F600, 2) = $DE00, len 1');

  Check(TyCharStartAt('abc', 3, 1) = 3, 'TyCharStartAt(abc, 3, 1) = 3');
  Check(TyCharStartAt('a' + cGuo, 2, 1) = 2, 'TyCharStartAt(a + U+56FD, 2, 1) = 2');
  Check(TyCharStartAt('a' + cGrin, 3, 1) = 2, 'TyCharStartAt(a + U+1F600, 3, 1) = 2');
  Check(TyCharStartAt('a' + cGrin, 2, 1) = 2, 'TyCharStartAt(a + U+1F600, 2, 1) = 2');
  Check(TyCharStartAt(cGrin, 2, 1) = 1, 'TyCharStartAt(U+1F600, 2, 1) = 1');
  Check(TyCharStartAt(cGrin, 2, 0) = 1, 'TyCharStartAt(U+1F600, 2, 0) = 1');
  Check(TyCharStartAt(cGrin, 2, 2) = 2, 'TyCharStartAt(U+1F600, 2, 2) = 2 (the floor holds)');
  Check(TyCharStartAt(#$DE00, 1, 0) = 1, 'TyCharStartAt(lone low surrogate, 1, 0) = 1');
  Check(TyCharStartAt('a' + #$DE00, 2, 1) = 2, 'TyCharStartAt(a + lone low surrogate, 2, 1) = 2');
end;

begin
  CheckSar32;
  CheckIntToDouble;
  CheckFloorCeil64;
  CheckBoolText;
  CheckNativeStr;
  Writeln('DELPHI VALUES OK');
end.
