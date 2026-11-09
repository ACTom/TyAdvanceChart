{ Copied from TyControls tests/test.wheelevents.pas at 77860b40. }
unit test.advchart.wheelevents;
{$mode objfpc}{$H+}

{ TyControls #62. OnMouseWheel, OnMouseWheelUp and OnMouseWheelDown are fired by
  TControl.DoMouseWheel, so a control that overrides DoMouseWheel and never calls inherited never
  fires them -- and the chart overrides it, for its roams and data zooms.

  The contract, as LCL's TControl.DoMouseWheel has it: OnMouseWheel first; if it does not set
  Handled, OnMouseWheelUp or OnMouseWheelDown; each fires once a notch, and a handler that sets
  Handled has the last word -- nothing after it in that chain fires.

  TyControls' TWheelEventTest.TestEveryControlFiresTheWheelEventsOncePerNotch asks every control
  on its palette the event half of that, and TTyAdvanceChart was on it until it moved here. The
  same sweep runs over this repository's registrations. The suite's other tests are the grid's,
  the image view's and the cascader's, and stay there. }

interface

uses
  Classes, SysUtils, Types, Forms, Controls, fpcunit, testregistry,
  test.designregistry, test.advchart.version;

type
  TAdvChartWheelEventTest = class(TTestCase)
  private
    FForm: TForm;
    FWheel, FUp, FDown: Integer;
    FHandleIn: Integer;   // 0 = nobody sets Handled, 1 = OnMouseWheel does, 2 = OnMouseWheelUp/Down do
    procedure Wheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure WheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint;
      var Handled: Boolean);
    procedure WheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint;
      var Handled: Boolean);
    { One notch on AControl with its three wheel events hooked; AHandleIn as FHandleIn. Returns
      what DoMouseWheel answered. }
    function Notch(AControl: TControl; ADelta, AHandleIn: Integer): Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestEveryControlFiresTheWheelEventsOncePerNotch;
  end;

implementation

type
  { DoMouseWheel and the three wheel events are protected in TControl. The call is virtual, so it
    runs the concrete control's override. }
  TWheelAccess = class(TControl);

procedure TAdvChartWheelEventTest.SetUp;
begin
  FForm := TForm.CreateNew(nil);
  FForm.SetBounds(0, 0, 640, 480);
end;

procedure TAdvChartWheelEventTest.TearDown;
begin
  FreeAndNil(FForm);
end;

procedure TAdvChartWheelEventTest.Wheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint; var Handled: Boolean);
begin
  Inc(FWheel);
  if FHandleIn = 1 then Handled := True;
end;

procedure TAdvChartWheelEventTest.WheelUp(Sender: TObject; Shift: TShiftState; MousePos: TPoint;
  var Handled: Boolean);
begin
  Inc(FUp);
  if FHandleIn = 2 then Handled := True;
end;

procedure TAdvChartWheelEventTest.WheelDown(Sender: TObject; Shift: TShiftState; MousePos: TPoint;
  var Handled: Boolean);
begin
  Inc(FDown);
  if FHandleIn = 2 then Handled := True;
end;

function TAdvChartWheelEventTest.Notch(AControl: TControl; ADelta, AHandleIn: Integer): Boolean;
begin
  TWheelAccess(AControl).OnMouseWheel := @Wheel;
  TWheelAccess(AControl).OnMouseWheelUp := @WheelUp;
  TWheelAccess(AControl).OnMouseWheelDown := @WheelDown;
  FWheel := 0;
  FUp := 0;
  FDown := 0;
  FHandleIn := AHandleIn;
  { MousePos is in client coordinates (LCL's TMouseWheelEvent). }
  Result := TWheelAccess(AControl).DoMouseWheel([], ADelta, Point(20, 20));
end;

procedure TAdvChartWheelEventTest.TestEveryControlFiresTheWheelEventsOncePerNotch;
var
  names, bad: TStringList;
  i, swept: Integer;
  cls: TPersistentClass;
  c: TControl;
  handled: Boolean;

  procedure Check(const AWhat: string; AWant, AWantUp, AWantDown: Integer);
  begin
    if (FWheel <> AWant) or (FUp <> AWantUp) or (FDown <> AWantDown) or not handled then
      bad.Add(Format('%s, %s: OnMouseWheel %d, Up %d, Down %d, answered %s'
        + ' (want %d, %d, %d, True)', [names[i], AWhat, FWheel, FUp, FDown,
        BoolToStr(handled, True), AWant, AWantUp, AWantDown]));
  end;

begin
  names := TStringList.Create;
  bad := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    AssertTrue('the design-registry parser found the palette entry',
      names.IndexOf('TTyAdvanceChart') >= 0);
    swept := 0;
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      if (cls = nil) or not cls.InheritsFrom(TControl) then Continue;
      if cls.InheritsFrom(TCustomForm) then Continue;
      c := TControlClass(cls).Create(FForm);
      try
        try
          c.Parent := FForm;
          c.SetBounds(0, 0, 300, 200);
          { OnMouseWheel takes the notch: nothing after it fires. }
          handled := Notch(c, -120, 1);
          Check('OnMouseWheel handles a notch down', 1, 0, 0);
          { OnMouseWheel passes; the direction event fires once and takes it. }
          handled := Notch(c, -120, 2);
          Check('OnMouseWheelDown handles a notch down', 1, 0, 1);
          handled := Notch(c, 120, 2);
          Check('OnMouseWheelUp handles a notch up', 1, 1, 0);
          Inc(swept);
        except
          on E: Exception do
            bad.Add(names[i] + ': ' + E.ClassName + ': ' + E.Message);
        end;
      finally
        c.Free;
      end;
    end;
    AssertTrue(Format('the sweep must cover the registrations, and it covered %d controls',
      [swept]), swept >= 1);
    AssertEquals('controls whose wheel events do not fire once a notch, or do not stop at'
      + ' Handled:' + LineEnding + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    names.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartWheelEventTest);
end.
