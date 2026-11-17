(* Section jsonnum: JSON numbers. Every input is read with GetJSON and prints the same five lines: 'input',
  'type' (the NumberType, or the exception), 'bits' (the 64 bits of AsFloat in hexadecimal), 'asjson',
  'asstring'.

  - 1-9: required to be equal: the type and the bits; their asjson and asstring are informational.
  - 10-24: informational (out of range, the smallest subnormal, the largest Double, 18 digits, 2^53 + 1,
    the halfway and the hard cases of rounding).
  - 25-27: TJSONFloatNumber.Create(1/3), Create(NaN), Create(Infinity); informational.
  - 28-67: informational: 40 number literals of the gallery's option texts (examples/advchart/gallery/
    *.json in file-name order, from each file the first literal with a '.' not taken before). *)

const
  cJsonNumRequired: array[0..8] of string = (
    '0.5', '1.5', '-2.25', '1e3', '1E+2', '0.1', '3.14', '-0.0', '1e0');
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

{ bits, asjson and asstring of D; asjson and asstring are informational, bits when ABitsInfo is set. }
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
end;

procedure JsonNumCase(const AText: string; AInfo: Boolean);
var
  d: TJSONData;
begin
  NextCase;
  GInfo := AInfo;
  Line('input ' + Esc(AText));
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
  GInfo := True;
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
    JsonNumCase(cJsonNumRequired[i], False);
  for i := Low(cJsonNumInfo) to High(cJsonNumInfo) do
    JsonNumCase(cJsonNumInfo[i], True);
  JsonNumObjectCase('TJSONFloatNumber.Create(1/3)', TJSONFloatNumber.Create(1 / 3));
  JsonNumObjectCase('TJSONFloatNumber.Create(NaN)', TJSONFloatNumber.Create(NaN));
  JsonNumObjectCase('TJSONFloatNumber.Create(Infinity)', TJSONFloatNumber.Create(Infinity));
  for i := Low(cJsonNumGallery) to High(cJsonNumGallery) do
    JsonNumCase(cJsonNumGallery[i], True);
end;
