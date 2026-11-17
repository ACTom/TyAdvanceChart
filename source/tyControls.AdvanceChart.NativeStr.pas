unit tyControls.AdvanceChart.NativeStr;
{$I tyControls.AdvanceChart.Compiler.inc}
{ The string operations whose implementation depends on the encoding of the
  native string: UTF-8 bytes under FPC, UTF-16 code units under Delphi.

  ONE ROUTINE, TWO BODIES. Each routine holds both implementations, one per
  compiler. Callers do not need to know which encoding the native string
  has: they ask for "the string as JavaScript sees it", "the string of one
  code point", "how long is the first character", and get the answer in
  the native units of the compiler they were built with.

  THE FPC BRANCHES ARE THE OLD CODE. Each one gives exactly what the code
  it replaces gave: UTF8Decode / UTF8Encode, TextPatch's AddCode (one to
  four bytes, no validation), Calendar's steps over 10xxxxxx bytes, and
  Data's code point reader for trimming JavaScript's white space.

  PURE: SysUtils. }
interface
uses SysUtils;

{ S as JavaScript sees it: a string of UTF-16 code units. Upstream counts
  its length and indexes it in these units. }
function TyJsUnits(const S: string): UnicodeString;
{ The reverse of TyJsUnits, except for an unpaired surrogate: under FPC it is
  dropped (UTF8Encode's behaviour), under Delphi it is kept. }
function TyFromJsUnits(const U: UnicodeString): string;
{ The string of one code point. ACode is not checked: a caller that may
  hold an invalid code point deals with it first. }
function TyCodePointStr(ACode: Cardinal): string;
{ How many native units the first character of S takes; 0 for ''. }
function TyFirstCharLen(const S: string): Integer;
{ The native unit (counted from 1) where the last character of S starts;
  0 for ''. }
function TyLastCharStart(const S: string): Integer;
{ The code point that starts at S[AAt], and how many native units it takes. AAt must be within the string.
  A sequence that is cut short or malformed is read the way the routine's FPC branch always has: see the tests. }
function TyCodePointAt(const S: string; AAt: Integer; out ALen: Integer): Cardinal;
{ The index at which the character containing S[AAt] starts, never going below AFloor.
  AAt must be within the string. }
function TyCharStartAt(const S: string; AAt, AFloor: Integer): Integer;

implementation

function TyJsUnits(const S: string): UnicodeString;
begin
  {$IFDEF FPC}Result := UTF8Decode(S);{$ELSE}Result := S;{$ENDIF}
end;

function TyFromJsUnits(const U: UnicodeString): string;
begin
  {$IFDEF FPC}Result := UTF8Encode(U);{$ELSE}Result := U;{$ENDIF}
end;

function TyCodePointStr(ACode: Cardinal): string;
begin
{$IFDEF FPC}
  { One to four bytes, as TextPatch's AddCode writes them. }
  if ACode < $80 then Result := Chr(ACode)
  else if ACode < $800 then
    Result := Chr($C0 or (ACode shr 6)) + Chr($80 or (ACode and $3F))
  else if ACode < $10000 then
    Result := Chr($E0 or (ACode shr 12))
      + Chr($80 or ((ACode shr 6) and $3F)) + Chr($80 or (ACode and $3F))
  else
    Result := Chr($F0 or (ACode shr 18))
      + Chr($80 or ((ACode shr 12) and $3F))
      + Chr($80 or ((ACode shr 6) and $3F)) + Chr($80 or (ACode and $3F));
{$ELSE}
  { One code unit, or a surrogate pair above the BMP. }
  if ACode < $10000 then Result := Char(ACode)
  else
    Result := Char($D800 + ((ACode - $10000) shr 10))
      + Char($DC00 + ((ACode - $10000) and $3FF));
{$ENDIF}
end;

function TyFirstCharLen(const S: string): Integer;
begin
  if S = '' then Exit(0);
{$IFDEF FPC}
  { A lead byte of $C0 or more, and the 10xxxxxx bytes after it. }
  Result := 1;
  if Ord(S[1]) >= $C0 then
    while (Result < Length(S)) and ((Ord(S[Result + 1]) and $C0) = $80) do Inc(Result);
{$ELSE}
  { A high surrogate followed by a low one is one character. }
  if (Length(S) >= 2) and (Ord(S[1]) >= $D800) and (Ord(S[1]) <= $DBFF)
    and (Ord(S[2]) >= $DC00) and (Ord(S[2]) <= $DFFF) then
    Result := 2
  else
    Result := 1;
{$ENDIF}
end;

function TyLastCharStart(const S: string): Integer;
begin
  if S = '' then Exit(0);
{$IFDEF FPC}
  { Back over the 10xxxxxx bytes, never past the first byte. }
  Result := Length(S);
  while (Result > 1) and ((Ord(S[Result]) and $C0) = $80) do Dec(Result);
{$ELSE}
  { A low surrogate preceded by a high one is one character. }
  Result := Length(S);
  if (Result >= 2) and (Ord(S[Result]) >= $DC00) and (Ord(S[Result]) <= $DFFF)
    and (Ord(S[Result - 1]) >= $D800) and (Ord(S[Result - 1]) <= $DBFF) then
    Dec(Result);
{$ENDIF}
end;

function TyCodePointAt(const S: string; AAt: Integer; out ALen: Integer): Cardinal;
var
{$IFDEF FPC}
  b: Byte;
{$ELSE}
  hi, lo: Cardinal;
{$ENDIF}
begin
{$IFDEF FPC}
  { One to four bytes; a sequence cut short by the end of S, or with a lead
    byte that starts none, is that one byte. }
  b := Ord(S[AAt]);
  ALen := 1;
  Result := b;
  if b < $80 then Exit;
  if (b and $E0 = $C0) and (AAt + 1 <= Length(S)) then
  begin
    ALen := 2;
    Result := ((b and $1F) shl 6) or (Ord(S[AAt + 1]) and $3F);
  end
  else if (b and $F0 = $E0) and (AAt + 2 <= Length(S)) then
  begin
    ALen := 3;
    Result := ((b and $0F) shl 12) or ((Ord(S[AAt + 1]) and $3F) shl 6)
      or (Ord(S[AAt + 2]) and $3F);
  end
  else if (b and $F8 = $F0) and (AAt + 3 <= Length(S)) then
  begin
    ALen := 4;
    Result := ((b and $07) shl 18) or ((Ord(S[AAt + 1]) and $3F) shl 12)
      or ((Ord(S[AAt + 2]) and $3F) shl 6) or (Ord(S[AAt + 3]) and $3F);
  end;
{$ELSE}
  { A high surrogate followed by a low one is one code point; any other
    unit, a lone surrogate included, is itself. }
  hi := Ord(S[AAt]);
  ALen := 1;
  Result := hi;
  if (hi >= $D800) and (hi <= $DBFF) and (AAt < Length(S)) then
  begin
    lo := Ord(S[AAt + 1]);
    if (lo >= $DC00) and (lo <= $DFFF) then
    begin
      ALen := 2;
      Result := $10000 + ((hi - $D800) shl 10) + (lo - $DC00);
    end;
  end;
{$ENDIF}
end;

function TyCharStartAt(const S: string; AAt, AFloor: Integer): Integer;
begin
  Result := AAt;
{$IFDEF FPC}
  { Back over the 10xxxxxx bytes, never below AFloor. }
  while (Result > AFloor) and ((Ord(S[Result]) and $C0) = $80) do Dec(Result);
{$ELSE}
  { A low surrogate preceded by a high one, above the floor, starts one
    unit earlier. }
  if (AAt > AFloor) and (AAt >= 2) and (Ord(S[AAt]) >= $DC00) and (Ord(S[AAt]) <= $DFFF)
    and (Ord(S[AAt - 1]) >= $D800) and (Ord(S[AAt - 1]) <= $DBFF) then
    Result := AAt - 1;
{$ENDIF}
end;

end.
