unit test.advchart.tabstop;
{$mode objfpc}{$H+}

{ The chart's side of TyControls' focus decision (test.focus.tabstop).

  TTyCustomControl.MouseDown is the only thing that focuses a custom-drawn control on click, and
  it gates that on TabStop; so whether a windowed control is a tab stop is a decision, written
  down in two tables, and every windowed class the designtime/ registers must be on one of them.
  TTyAdvanceChart was on the non-focusable table: it is a chart, it reads an option tree and draws
  it. Charts are pointed at, not typed into -- ECharts' own keyboard story is a screen-reader
  description, not a caret -- so it stays out of the tab order like every other display surface.

  The same three checks run here over this repository's registrations: the table entries are
  what they say, every registered windowed class is on a table (the population parsed out of
  designtime/ by test.designregistry, so a new control fails until somebody decides), and the
  published TabStop default is the constructed value, so a .lfm can override it. }

interface

uses
  Classes, SysUtils, TypInfo, Controls, Forms, fpcunit, testregistry,
  test.designregistry, test.advchart.version,
  tyControls.Base, tyControls.AdvanceChart;

type
  TTyCtlClass = class of TTyCustomControl;
  TTyCtlClassArray = array of TTyCtlClass;

  TAdvChartFocusTabStopTest = class(TTestCase)
  private
    FForm: TForm;
    function Build(AClass: TTyCtlClass): TTyCustomControl;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestContainersAndChromeStayOutOfTheFocusOrder;
    procedure TestEveryRegisteredWindowedControlIsOnATable;
    procedure TestPublishedDefaultAgreesWithTheConstructedValue;
  end;

implementation

{ The focusable table: windowed controls the user acts on once they hold focus. None here. }
function FocusableControls: TTyCtlClassArray;
begin
  Result := nil;
end;

{ The non-focusable table. }
function ContainerAndChromeControls: TTyCtlClassArray;
begin
  Result := TTyCtlClassArray.Create(
    { TTyAdvanceChart is a chart: it reads an option tree and draws it (see the unit doc). }
    TTyAdvanceChart);
end;

procedure TAdvChartFocusTabStopTest.SetUp;
begin
  FForm := TForm.CreateNew(nil);
end;

procedure TAdvChartFocusTabStopTest.TearDown;
begin
  FForm.Free;   // owns every control the test built
  FForm := nil;
end;

function TAdvChartFocusTabStopTest.Build(AClass: TTyCtlClass): TTyCustomControl;
begin
  Result := AClass.Create(FForm);
end;

procedure TAdvChartFocusTabStopTest.TestContainersAndChromeStayOutOfTheFocusOrder;
var
  list: TTyCtlClassArray;
  i: Integer;
  c: TTyCustomControl;
begin
  list := ContainerAndChromeControls;
  AssertTrue('the table is not empty', Length(list) > 0);
  for i := 0 to High(list) do
  begin
    c := Build(list[i]);
    AssertFalse(c.ClassName + ' must NOT be a tab stop: a click on its background would '
      + 'pull focus off the child that had it',
      c.TabStop);
  end;
end;

{ The tables are a decision, so they are written by hand; the POPULATION they decide about is
  not: it is every name in a RegisterComponents / RegisterNoIcon / RegisterDesignerBaseClass
  call of designtime/, filtered to the windowed base, TTyCustomControl. }
procedure TAdvChartFocusTabStopTest.TestEveryRegisteredWindowedControlIsOnATable;
var
  names, listed, missing: TStringList;
  arr: TTyCtlClassArray;
  cls: TPersistentClass;
  i, windowed: Integer;
begin
  names := TStringList.Create;
  listed := TStringList.Create;
  missing := TStringList.Create;
  try
    arr := FocusableControls;
    for i := 0 to High(arr) do listed.Add(arr[i].ClassName);
    arr := ContainerAndChromeControls;
    for i := 0 to High(arr) do listed.Add(arr[i].ClassName);
    listed.Sorted := True;

    CollectRegisteredClassNames(names);
    AssertTrue('the design-registry parser found the palette entry',
      names.IndexOf('TTyAdvanceChart') >= 0);

    windowed := 0;
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      { An unresolvable name is test.advchart.version's TestEveryRegisteredNameResolves to report. }
      if cls = nil then Continue;
      if not cls.InheritsFrom(TTyCustomControl) then Continue;
      Inc(windowed);
      if listed.IndexOf(names[i]) < 0 then missing.Add(names[i]);
    end;
    AssertTrue('the TTyCustomControl filter kept the chart', windowed >= 1);
    AssertEquals('registered windowed control(s) with no declared focus default. Every'
      + ' windowed TTy class a .lfm can name must appear in FocusableControls or in'
      + ' ContainerAndChromeControls, so that its TabStop default is a decision somebody'
      + ' wrote down:' + LineEnding + missing.Text, 0, missing.Count);
  finally
    missing.Free;
    listed.Free;
    names.Free;
  end;
end;

{ FPC streams a published property only when its value differs from the DECLARED default, so a
  constructor and a declaration that disagree make the .lfm unable to override TabStop. }
procedure TAdvChartFocusTabStopTest.TestPublishedDefaultAgreesWithTheConstructedValue;

  procedure CheckOne(AClass: TTyCtlClass);
  var
    c: TTyCustomControl;
    pi: PPropInfo;
  begin
    c := Build(AClass);
    pi := GetPropInfo(AClass, 'TabStop');
    AssertTrue(AClass.ClassName + ' must publish TabStop (a host has to be able to '
      + 'override it in the .lfm)', pi <> nil);
    AssertEquals(AClass.ClassName + ': the declared default must match what the '
      + 'constructor sets, or the .lfm cannot override it',
      GetOrdProp(c, pi), pi^.Default);
  end;

var
  list: TTyCtlClassArray;
  i: Integer;
begin
  list := FocusableControls;
  for i := 0 to High(list) do CheckOne(list[i]);
  list := ContainerAndChromeControls;
  for i := 0 to High(list) do CheckOne(list[i]);
end;

initialization
  RegisterTest(TAdvChartFocusTabStopTest);
end.
