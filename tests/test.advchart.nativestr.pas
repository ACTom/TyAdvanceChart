unit test.advchart.nativestr;
{$mode objfpc}{$H+}
{ Tests for tyControls.AdvanceChart.NativeStr on FPC, where the native string
  is UTF-8 bytes. The same values are checked under Delphi, in UTF-16, by
  delphi/tests/tyadvchart_values.dpr. Non-ASCII text is written as its bytes. }
interface
uses Classes, SysUtils, fpcunit, testregistry, tyControls.AdvanceChart.NativeStr;
type
  TAdvChartNativeStrTest = class(TTestCase)
  published
    procedure TestJsUnitsCountsUtf16Units;
    procedure TestJsUnitsRoundTrip;
    procedure TestCodePointStr;
    procedure TestFirstCharLen;
    procedure TestLastCharStart;
    procedure TestCodePointAt;
    procedure TestCharStartAt;
  end;
implementation

const
  cGuo = #$E5#$9B#$BD;          // U+56FD
  cEAcute = #$C3#$A9;           // U+00E9
  cGrin = #$F0#$9F#$98#$80;     // U+1F600

procedure TAdvChartNativeStrTest.TestJsUnitsCountsUtf16Units;
var u: UnicodeString;
begin
  AssertEquals('a BMP character is one unit', 3, Length(TyJsUnits('a' + cGuo + cEAcute)));
  AssertEquals('an astral character is two', 2, Length(TyJsUnits(cGrin)));
  AssertEquals('nothing is nothing', 0, Length(TyJsUnits('')));
  AssertEquals('U+56FD', $56FD, Ord(TyJsUnits(cGuo)[1]));
  u := TyJsUnits(cGrin);
  AssertEquals('high surrogate', $D83D, Ord(u[1]));
  AssertEquals('low surrogate', $DE00, Ord(u[2]));
end;

procedure TAdvChartNativeStrTest.TestJsUnitsRoundTrip;
begin
  AssertEquals('empty', '', TyFromJsUnits(TyJsUnits('')));
  AssertEquals('ASCII', 'abc', TyFromJsUnits(TyJsUnits('abc')));
  AssertEquals('BMP', 'a' + cGuo + cEAcute, TyFromJsUnits(TyJsUnits('a' + cGuo + cEAcute)));
  AssertEquals('astral', cGrin + 'x', TyFromJsUnits(TyJsUnits(cGrin + 'x')));
end;

procedure TAdvChartNativeStrTest.TestCodePointStr;
begin
  AssertEquals('$41', 'A', TyCodePointStr($41));
  AssertEquals('$E9', cEAcute, TyCodePointStr($E9));
  AssertEquals('$56FD', cGuo, TyCodePointStr($56FD));
  AssertEquals('$1F600', cGrin, TyCodePointStr($1F600));
  { The edges of each length, as TextPatch's AddCode encodes them. }
  AssertEquals('$7F', #$7F, TyCodePointStr($7F));
  AssertEquals('$80', #$C2#$80, TyCodePointStr($80));
  AssertEquals('$7FF', #$DF#$BF, TyCodePointStr($7FF));
  AssertEquals('$800', #$E0#$A0#$80, TyCodePointStr($800));
  AssertEquals('$FFFF', #$EF#$BF#$BF, TyCodePointStr($FFFF));
  AssertEquals('$10000', #$F0#$90#$80#$80, TyCodePointStr($10000));
  AssertEquals('$10FFFF', #$F4#$8F#$BF#$BF, TyCodePointStr($10FFFF));
end;

procedure TAdvChartNativeStrTest.TestFirstCharLen;
begin
  AssertEquals('empty', 0, TyFirstCharLen(''));
  AssertEquals('ASCII', 1, TyFirstCharLen('abc'));
  AssertEquals('BMP then ASCII', Length(cGuo), TyFirstCharLen(cGuo + 'a'));
  AssertEquals('astral then ASCII', Length(cGrin), TyFirstCharLen(cGrin + 'a'));
  AssertEquals('one BMP character', Length(cGuo), TyFirstCharLen(cGuo));
  AssertEquals('one astral character', Length(cGrin), TyFirstCharLen(cGrin));
  AssertEquals('ASCII then BMP', 1, TyFirstCharLen('a' + cGuo));
end;

procedure TAdvChartNativeStrTest.TestLastCharStart;
begin
  AssertEquals('empty', 0, TyLastCharStart(''));
  AssertEquals('ASCII', 3, TyLastCharStart('abc'));
  AssertEquals('ASCII then BMP', 2, TyLastCharStart('a' + cGuo));
  AssertEquals('ASCII then astral', 2, TyLastCharStart('a' + cGrin));
  AssertEquals('one BMP character', 1, TyLastCharStart(cGuo));
  AssertEquals('one astral character', 1, TyLastCharStart(cGrin));
  AssertEquals('BMP then ASCII', Length(cGuo) + 1, TyLastCharStart(cGuo + 'a'));
  AssertEquals('astral then ASCII', Length(cGrin) + 1, TyLastCharStart(cGrin + 'a'));
end;

procedure TAdvChartNativeStrTest.TestCodePointAt;
var n: Integer;
begin
  AssertEquals('A', $41, TyCodePointAt('A', 1, n)); AssertEquals('A len', 1, n);
  AssertEquals('U+00E9', $E9, TyCodePointAt(cEAcute, 1, n)); AssertEquals('U+00E9 len', 2, n);
  AssertEquals('U+56FD', $56FD, TyCodePointAt(cGuo, 1, n)); AssertEquals('U+56FD len', 3, n);
  AssertEquals('U+1F600', $1F600, TyCodePointAt(cGrin, 1, n)); AssertEquals('U+1F600 len', 4, n);
  AssertEquals('U+56FD inside', $56FD, TyCodePointAt('a' + cGuo + 'b', 2, n));
  AssertEquals('U+56FD inside len', 3, n);
  AssertEquals('b after U+56FD', $62, TyCodePointAt('a' + cGuo + 'b', 5, n));
  AssertEquals('b after U+56FD len', 1, n);
  { Cut short or malformed: these pin what Data's CodePointAt returned
    before it moved here -- the lead byte itself, one byte long. }
  AssertEquals('U+56FD cut short', $E5, TyCodePointAt(#$E5#$9B, 1, n));
  AssertEquals('U+56FD cut short len', 1, n);
  AssertEquals('U+1F600 cut short', $F0, TyCodePointAt(#$F0#$9F, 1, n));
  AssertEquals('U+1F600 cut short len', 1, n);
  AssertEquals('a lone lead byte', $C3, TyCodePointAt(#$C3, 1, n));
  AssertEquals('a lone lead byte len', 1, n);
  AssertEquals('a lone continuation byte', $80, TyCodePointAt(#$80, 1, n));
  AssertEquals('a lone continuation byte len', 1, n);
end;

procedure TAdvChartNativeStrTest.TestCharStartAt;
begin
  AssertEquals('ASCII', 3, TyCharStartAt('abc', 3, 1));
  AssertEquals('last byte of U+56FD', 2, TyCharStartAt('a' + cGuo, 4, 1));
  AssertEquals('middle byte of U+56FD', 2, TyCharStartAt('a' + cGuo, 3, 1));
  AssertEquals('first byte of U+56FD', 2, TyCharStartAt('a' + cGuo, 2, 1));
  AssertEquals('last byte of U+1F600', 2, TyCharStartAt('a' + cGrin, 5, 1));
  AssertEquals('U+56FD alone', 1, TyCharStartAt(cGuo, 3, 1));
  { The floor holds. }
  AssertEquals('floor inside U+56FD', 2, TyCharStartAt(cGuo, 3, 2));
  AssertEquals('continuation bytes down to the floor', 1, TyCharStartAt(#$80#$80, 2, 1));
  AssertEquals('at the floor', 2, TyCharStartAt(#$80#$80, 2, 2));
end;

initialization
  RegisterTest(TAdvChartNativeStrTest);
end.
