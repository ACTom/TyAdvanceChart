unit test.advchart.coredir;
{$mode objfpc}{$H+}

{ TY_CORE_DIR: the TyControls checkout a few checks compare the chart with.

  The chart builds against TyControls' packages, not against a TyControls tree, so its tests
  read nothing of the core by path -- except the checks whose whole point is the boundary
  between the two: none of the chart's strings is left in the core's catalogues, and the
  core's Version editor reaches the chart's component. Those read the checkout this variable
  names. Unset, they call Ignore with a message that says so; set to a directory that is not a
  TyControls checkout, they fail.

  REGISTERS NO TESTS. }

interface

uses
  SysUtils, fpcunit;

const
  CTyCoreDirVar = 'TY_CORE_DIR';

{ The checkout TY_CORE_DIR names, with a trailing delimiter. Unset: ATest.Ignore, with AWhat
  saying what is not checked. Set to something that is not a TyControls checkout (no
  tycontrols.lpk at its root): a failure. }
function TyCoreDirFor(ATest: TTestCase; const AWhat: string): string;

implementation

function TyCoreDirFor(ATest: TTestCase; const AWhat: string): string;
begin
  Result := GetEnvironmentVariable(CTyCoreDirVar);
  if Result = '' then
    ATest.Ignore(CTyCoreDirVar + ' is not set, so ' + AWhat + ' is not checked: point it at a '
      + 'TyControls checkout to check it');
  Result := IncludeTrailingPathDelimiter(Result);
  TAssert.AssertTrue(CTyCoreDirVar + ' names a TyControls checkout (' + Result
    + 'tycontrols.lpk)', FileExists(Result + 'tycontrols.lpk'));
end;

end.
