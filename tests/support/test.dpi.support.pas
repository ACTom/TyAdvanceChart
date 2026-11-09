{ Copied from TyControls tests/test.dpi.support.pas at 77860b40. }
unit test.dpi.support;
{ Only TyTestCodeOnly and TyTestRepoRoot came over: the AdvChart guards that read the
  library's own source use them. The layout and painting helpers stay in TyControls. }
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils;

{ Pascal source with comments and string literals blanked out, so that prose ABOUT a
  construct cannot be taken for the construct. Brace comments NEST in this dialect, and the
  units under scan do use that. For the guards that read the library's own source. }
function TyTestCodeOnly(const S: string): string;
{ The repository root, with a trailing delimiter: the runner lives in tests/. }
function TyTestRepoRoot: string;

implementation

function TyTestRepoRoot: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim;
end;

function TyTestCodeOnly(const S: string): string;
var
  i, n, depth: Integer;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    i := 1;
    n := Length(S);
    while i <= n do
    begin
      if S[i] = '{' then
      begin
        depth := 1;
        Inc(i);
        while (i <= n) and (depth > 0) do
        begin
          if S[i] = '{' then Inc(depth)
          else if S[i] = '}' then Dec(depth);
          Inc(i);
        end;
        sb.Append(' ');
      end
      else if (S[i] = '(') and (i < n) and (S[i + 1] = '*') then
      begin
        Inc(i, 2);
        while (i < n) and not ((S[i] = '*') and (S[i + 1] = ')')) do Inc(i);
        Inc(i, 2);
        sb.Append(' ');
      end
      else if (S[i] = '/') and (i < n) and (S[i + 1] = '/') then
      begin
        while (i <= n) and (S[i] <> #10) do Inc(i);
        sb.Append(' ');
      end
      else if S[i] = '''' then
      begin
        Inc(i);
        while (i <= n) and (S[i] <> '''') do Inc(i);
        Inc(i);
        sb.Append(' ');
      end
      else
      begin
        sb.Append(S[i]);
        Inc(i);
      end;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.
