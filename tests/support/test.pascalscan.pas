unit test.pascalscan;
{ A scanner that splits Pascal source into code, strings, comments and directives, for tests
  that count constructs in source text. It knows the lexical rules only, nothing of any
  project. Brace comments nest (as FPC does in objfpc mode); a '{$' at depth 0 starts a
  directive that ends at the first '}'; '(* *)' does not nest; '//' runs to the end of the
  line; in a string '' is an escaped quote, and an unclosed string ends with its line. }
{$mode objfpc}{$H+}
interface

type
  TTyPasSegKind = (pskCode, pskString, pskLineComment, pskBraceComment, pskParenComment, pskDirective);
  TTyPasSeg = record
    Kind: TTyPasSegKind;
    Start, Len: Integer;   // Start counts from 1, in bytes
    Line: Integer;         // the line Start is on, from 1
    Nested: Boolean;       // a brace comment with a '{' in it
  end;
  TTyPasSegs = array of TTyPasSeg;

function TyPasScan(const AText: string): TTyPasSegs;
{ The text at the same length: every character of a comment or directive becomes a space (line
  ends stay), every character between the outer quotes of a string becomes 'S'. }
function TyPasCodeOnly(const AText: string): string;

implementation

function TyPasScan(const AText: string): TTyPasSegs;
var
  n, i, j, depth, cnt, codeStart, linePos, line: Integer;
  nested: Boolean;
  kind: TTyPasSegKind;

  function LineAt(APos: Integer): Integer;
  begin
    while linePos < APos do
    begin
      if AText[linePos] = #10 then
        Inc(line);
      Inc(linePos);
    end;
    Result := line;
  end;

  procedure Add(AKind: TTyPasSegKind; AStart, AEnd: Integer; ANested: Boolean);
  begin
    if cnt = Length(Result) then
      SetLength(Result, cnt * 2 + 64);
    with Result[cnt] do
    begin
      Kind := AKind;
      Start := AStart;
      Len := AEnd - AStart;
      Line := LineAt(AStart);
      Nested := ANested;
    end;
    Inc(cnt);
  end;

  procedure FlushCode(AUpTo: Integer);
  begin
    if codeStart < AUpTo then
      Add(pskCode, codeStart, AUpTo, False);
  end;

begin
  Result := nil;
  n := Length(AText);
  cnt := 0;
  linePos := 1;
  line := 1;
  codeStart := 1;
  i := 1;
  while i <= n do
  begin
    case AText[i] of
      '''':
        begin
          FlushCode(i);
          j := i + 1;
          while j <= n do
          begin
            if AText[j] = '''' then
            begin
              if (j < n) and (AText[j + 1] = '''') then
              begin
                Inc(j, 2);
                Continue;
              end;
              Break;
            end;
            if (AText[j] = #10) or (AText[j] = #13) then
              Break;
            Inc(j);
          end;
          if j <= n then
            if AText[j] = '''' then
              Inc(j);
          Add(pskString, i, j, False);
          i := j;
          codeStart := i;
        end;
      '/':
        if (i < n) and (AText[i + 1] = '/') then
        begin
          FlushCode(i);
          j := i;
          while (j <= n) and (AText[j] <> #10) and (AText[j] <> #13) do
            Inc(j);
          Add(pskLineComment, i, j, False);
          i := j;
          codeStart := i;
        end
        else
          Inc(i);
      '{':
        begin
          FlushCode(i);
          nested := False;
          if (i < n) and (AText[i + 1] = '$') then
          begin
            kind := pskDirective;
            j := i + 1;
            while (j <= n) and (AText[j] <> '}') do
              Inc(j);
            if j <= n then
              Inc(j);
          end
          else
          begin
            kind := pskBraceComment;
            depth := 1;
            j := i + 1;
            while (j <= n) and (depth > 0) do
            begin
              if AText[j] = '{' then
              begin
                Inc(depth);
                nested := True;
              end
              else if AText[j] = '}' then
                Dec(depth);
              Inc(j);
            end;
          end;
          Add(kind, i, j, nested);
          i := j;
          codeStart := i;
        end;
      '(':
        if (i < n) and (AText[i + 1] = '*') then
        begin
          FlushCode(i);
          j := i + 2;
          while (j < n) and not ((AText[j] = '*') and (AText[j + 1] = ')')) do
            Inc(j);
          if j < n then
            Inc(j, 2)
          else
            j := n + 1;
          Add(pskParenComment, i, j, False);
          i := j;
          codeStart := i;
        end
        else
          Inc(i);
    else
      Inc(i);
    end;
  end;
  FlushCode(n + 1);
  SetLength(Result, cnt);
end;

function TyPasCodeOnly(const AText: string): string;
var
  segs: TTyPasSegs;
  k, p, last: Integer;
begin
  Result := AText;
  segs := TyPasScan(AText);
  for k := 0 to High(segs) do
    case segs[k].Kind of
      pskCode: ;
      pskString:
        begin
          // between the outer quotes; an unclosed string has no closing one
          last := segs[k].Start + segs[k].Len - 1;
          if (segs[k].Len < 2) or (AText[last] <> '''') then
            last := last + 1;
          for p := segs[k].Start + 1 to last - 1 do
            Result[p] := 'S';
        end;
    else
      for p := segs[k].Start to segs[k].Start + segs[k].Len - 1 do
        if (Result[p] <> #10) and (Result[p] <> #13) then
          Result[p] := ' ';
    end;
end;

end.
