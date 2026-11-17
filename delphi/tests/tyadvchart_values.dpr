{ Checks, under Delphi, the values of the helpers that have a branch of their own for it.
  Built and run by scripts/delphi-probe.py --values with dcc32 and dcc64; not compiled by FPC.
  Prints DELPHI VALUES OK as its last line when every check holds, else the failed check and exit code 1. }
program tyadvchart_values;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  tyControls.AdvanceChart.JsMath,
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

begin
  CheckSar32;
  CheckIntToDouble;
  Writeln('DELPHI VALUES OK');
end.
