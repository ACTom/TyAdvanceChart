{ The conversions between floating-point numbers and text that the FCL ports in delphi/fcl make: every one
  of them goes through these routines, so that one unit decides how such a number reads and prints.
  Delphi only (Lazarus builds with FPC's own units, which call Val, Str and FloatToStr themselves).

  For now the bodies are Delphi's RTL with the invariant format settings; they are meant to give what FPC
  gives, digit for digit, and the transcript of delphi/tests/tyadvchart_fcl.dpr is where that is checked. }
unit tyfclnum;

interface

{ text of a JSON number -> Double; False when S is not a number }
function TyFclTextToFloat(const S: string; out AValue: Double): Boolean;
{ what FPC's TryStrToFloat(S, AValue) gives: the text read with the current locale's format settings }
function TyFclLocaleTextToFloat(const S: string; out AValue: Double): Boolean;
{ what FPC's Str(AValue, S) gives for a Double, without the leading blank:
  17 significant digits, 'E', a sign, three exponent digits; 'Nan', '+Inf', '-Inf' }
function TyFclFloatToText(AValue: Double): string;
{ what FPC's FloatToStr(AValue) gives with the invariant format settings }
function TyFclFloatToStr(AValue: Double): string;

implementation

uses
  SysUtils, Math;

function TyFclTextToFloat(const S: string; out AValue: Double): Boolean;
begin
  AValue := 0;
  Result := TryStrToFloat(S, AValue, TFormatSettings.Invariant);
end;

function TyFclLocaleTextToFloat(const S: string; out AValue: Double): Boolean;
begin
  AValue := 0;
  Result := TryStrToFloat(S, AValue);
end;

function TyFclFloatToText(AValue: Double): string;
begin
  if IsNan(AValue) then
    Result := 'Nan'
  else if IsInfinite(AValue) then
  begin
    if AValue > 0 then
      Result := '+Inf'
    else
      Result := '-Inf';
  end
  else
    Result := FloatToStrF(AValue, ffExponent, 17, 3, TFormatSettings.Invariant);
end;

function TyFclFloatToStr(AValue: Double): string;
begin
  Result := FloatToStr(AValue, TFormatSettings.Invariant);
end;

end.
