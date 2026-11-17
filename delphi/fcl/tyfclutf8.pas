{ The one place where the FCL ports in delphi/fcl turn bytes read from a stream into a string. Delphi only
  (Lazarus builds with FPC's own units, which keep the bytes in a byte string as they are).

  FPC's units never decode: a stream's bytes become the bytes of the string, and an invalid UTF-8 sequence
  simply stays in it. The ports have UTF-16 strings, so they must decode, and they must not raise where
  FPC parses (Delphi's TEncoding.UTF8 raises EEncodingError on an invalid sequence). This decoder replaces
  every invalid sequence by U+FFFD and goes on, as the Unicode Standard recommends (chapter 3, "U+FFFD
  Substitution of Maximal Subparts"): a byte that cannot start a sequence is one U+FFFD; a sequence cut
  short (by the end of the bytes or by a byte that cannot continue it) is one U+FFFD for the bytes read so
  far, and the byte that broke it is read again as the start of the next one. }
unit tyfclutf8;

interface

uses
  SysUtils;

{ ABytes as UTF-8, an invalid sequence as U+FFFD; never raises. }
function TyFclUtf8Decode(const ABytes: TBytes): string;

implementation

function TyFclUtf8Decode(const ABytes: TBytes): string;
var
  i, n, k, need, len: Integer;
  b: Byte;
  lo, hi: Byte;
  cp: Cardinal;
  ok: Boolean;
begin
  n := Length(ABytes);
  SetLength(Result, n); // at most one unit per byte
  len := 0;
  i := 0;
  while i < n do
  begin
    b := ABytes[i];
    lo := $80;
    hi := $BF;
    case b of
      $00..$7F:
        begin
          Inc(len);
          Result[len] := Char(b);
          Inc(i);
          Continue;
        end;
      $C2..$DF: need := 1;
      $E0: begin need := 2; lo := $A0; end;
      $E1..$EC, $EE..$EF: need := 2;
      $ED: begin need := 2; hi := $9F; end;
      $F0: begin need := 3; lo := $90; end;
      $F1..$F3: need := 3;
      $F4: begin need := 3; hi := $8F; end;
    else
      need := 0; // $80..$C1, $F5..$FF: cannot start a sequence
    end;
    if need = 0 then
    begin
      Inc(len);
      Result[len] := #$FFFD;
      Inc(i);
      Continue;
    end;
    case need of
      1: cp := b and $1F;
      2: cp := b and $0F;
    else
      cp := b and $07;
    end;
    ok := True;
    k := 1;
    while k <= need do
    begin
      if (i + k >= n) or (ABytes[i + k] < lo) or (ABytes[i + k] > hi) then
      begin
        ok := False;
        Break;
      end;
      cp := (cp shl 6) or (ABytes[i + k] and $3F);
      lo := $80;
      hi := $BF;
      Inc(k);
    end;
    if not ok then
    begin
      Inc(len);
      Result[len] := #$FFFD;
      Inc(i, k); // the lead byte and the continuation bytes read so far
      Continue;
    end;
    if cp < $10000 then
    begin
      Inc(len);
      Result[len] := Char(cp);
    end
    else
    begin
      Inc(len);
      Result[len] := Char($D800 + ((cp - $10000) shr 10));
      Inc(len);
      Result[len] := Char($DC00 + ((cp - $10000) and $3FF));
    end;
    Inc(i, need + 1);
  end;
  SetLength(Result, len);
end;

end.
