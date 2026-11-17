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

initialization
  RegisterTest(TAdvChartNativeStrTest);
end.
