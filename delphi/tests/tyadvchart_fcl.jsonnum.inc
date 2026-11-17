(* Section jsonnum: JSON numbers. Every input is read with GetJSON and prints the same six lines: 'input',
  'type' (the NumberType, or the exception), 'bits' (the 64 bits of AsFloat in hexadecimal), 'asjson',
  'asstring', and 'roundtrip same' or 'roundtrip changed': whether the 64 bits of AsFloat survive
  AsJSON -> GetJSON -> AsFloat (an exception on the way counts as changed; '-' when the input raised).

  Compared in every case: the 'input' line, and the 'type' line (or the exception) except for the
  out-of-range literals. Informational in every case: 'asjson', 'asstring' and 'roundtrip' (float text,
  which the numeric plan will settle; scripts/delphi-probe.py pins what each Delphi compiler prints
  there, expected/fcl.dcc32.txt and fcl.dcc64.txt).
  - 1-9: the bits are compared too.
  - 10-24: the bits are informational (out of range, the smallest subnormal, the largest Double, 18
    digits, 2^53 + 1, the halfway and the hard cases of rounding). 10 and 11 (1e999, -1e999) are
    out-of-range literals: their 'type' line, or the exception, is informational too (dcc raises
    where FPC reads +-Inf).
  - 25-27: TJSONFloatNumber.Create(1/3), Create(NaN), Create(Infinity); the bits are informational.
  - 28-67: 40 number literals of the gallery's option texts (examples/advchart/gallery/*.json in
    file-name order, from each file the first literal with a '.' not taken before); the bits are
    informational.
  - 68-73: more out-of-range literals (1e309, 2e308, 1e400, -1e400, 1.8e308, 1e4000): 'type' or the
    exception, and the bits, informational. *)

const
  cJsonNumRequired: array[0..8] of string = (
    '0.5', '1.5', '-2.25', '1e3', '1E+2', '0.1', '3.14', '-0.0', '1e0');
  { the first two are out of range }
  cJsonNumInfo: array[0..14] of string = (
    '1e999', '-1e999', '1e-999', '5e-324', '1.7976931348623157e308', '0.1e-5', '123456789012345678',
    '0.30000000000000004', '9007199254740993', '1.0000000000000002', '2.2250738585072014e-308', '4.35',
    '1e21', '1e22', '1e23');
  cJsonNumGallery: array[0..39] of string = (
    '0.6', '0.3', '144.79460245155357', '0.8', '7.557373003909573', '-8.901463875624668', '1.13', '0.5', '8.3',
    '-0.07', '1.2', '2.4', '917.54', '44.63431373', '45.12972', '39.54', '44.61', '43.36', '40.91', '36.58',
    '24.384', '37.67568', '25.8', '42.97564103', '48.6', '37.41086957', '29.93047652', '44.75', '45.21',
    '70.9124', '71.3262', '72.6', '71.3', '71.7', '55.21862745', '73.1', '60.51078431', '64.998', '66.336',
    '69.134');
  cJsonNumOutOfRange: array[0..5] of string = (
    '1e309', '2e308', '1e400', '-1e400', '1.8e308', '1e4000');

function JsonNumBits(AValue: Double): string;
var
  i: Int64;
begin
  Move(AValue, i, SizeOf(i));
  Result := IntToHex(i, 16);
end;

function JsonNumTypeName(D: TJSONData): string;
begin
  if D.JSONType <> jtNumber then
    Result := 'not a number'
  else
    case TJSONNumber(D).NumberType of
      ntFloat: Result := 'float';
      ntInteger: Result := 'int';
      ntInt64: Result := 'int64';
      ntQWord: Result := 'qword';
    else
      Result := 'unknown';
    end;
end;

{ Whether the 64 bits of D.AsFloat survive AsJSON -> GetJSON -> AsFloat; an exception counts as not. }
function JsonNumRoundTrip(D: TJSONData): Boolean;
var
  e: TJSONData;
begin
  try
    e := GetJSON(Trim(D.AsJSON));
    try
      Result := JsonNumBits(e.AsFloat) = JsonNumBits(D.AsFloat);
    finally
      e.Free;
    end;
  except
    Result := False;
  end;
end;

{ bits, asjson, asstring and roundtrip of D; all but bits are informational, bits when ABitsInfo is
  set. }
procedure JsonNumLines(D: TJSONData; ABitsInfo: Boolean);
begin
  GInfo := ABitsInfo;
  try
    Line('bits ' + JsonNumBits(D.AsFloat));
  except
    on E: Exception do Raised(E);
  end;
  GInfo := True;
  try
    Line('asjson ' + Esc(D.AsJSON));
  except
    on E: Exception do Raised(E);
  end;
  try
    Line('asstring ' + Esc(D.AsString));
  except
    on E: Exception do Raised(E);
  end;
  if JsonNumRoundTrip(D) then
    Line('roundtrip same')
  else
    Line('roundtrip changed');
end;

{ One literal: the bits are informational when AInfo is set; the type, or the exception, when
  AOutOfRange is set. }
procedure JsonNumCase(const AText: string; AInfo, AOutOfRange: Boolean);
var
  d: TJSONData;
begin
  NextCase;
  Line('input ' + Esc(AText));
  GInfo := AOutOfRange;
  try
    d := GetJSON(AText);
  except
    on E: Exception do
    begin
      Raised(E);
      GInfo := AInfo;
      Line('bits -');
      GInfo := True;
      Line('asjson -');
      Line('asstring -');
      Line('roundtrip -');
      Exit;
    end;
  end;
  try
    Line('type ' + JsonNumTypeName(d));
    JsonNumLines(d, AInfo);
  finally
    d.Free;
  end;
end;

procedure JsonNumObjectCase(const AWhat: string; D: TJSONData);
begin
  NextCase;
  try
    Line('input ' + AWhat);
    Line('type ' + JsonNumTypeName(D));
    JsonNumLines(D, True);
  finally
    D.Free;
  end;
end;

procedure SectionJsonNum;
var
  i: Integer;
begin
  BeginSection('jsonnum');
  for i := Low(cJsonNumRequired) to High(cJsonNumRequired) do
    JsonNumCase(cJsonNumRequired[i], False, False);
  for i := Low(cJsonNumInfo) to High(cJsonNumInfo) do
    JsonNumCase(cJsonNumInfo[i], True, i <= 1);
  JsonNumObjectCase('TJSONFloatNumber.Create(1/3)', TJSONFloatNumber.Create(1 / 3));
  JsonNumObjectCase('TJSONFloatNumber.Create(NaN)', TJSONFloatNumber.Create(NaN));
  JsonNumObjectCase('TJSONFloatNumber.Create(Infinity)', TJSONFloatNumber.Create(Infinity));
  for i := Low(cJsonNumGallery) to High(cJsonNumGallery) do
    JsonNumCase(cJsonNumGallery[i], True, False);
  for i := Low(cJsonNumOutOfRange) to High(cJsonNumOutOfRange) do
    JsonNumCase(cJsonNumOutOfRange[i], True, True);
end;
