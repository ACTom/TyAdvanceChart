unit test.advchart.canvasblend;

{ HALF-CLEAR INK IS THE CANVAS', ON EVERY LAYER.

  A browser canvas composites source-over on the sRGB values as they are:
  a green of opacity 0.5 on white is (127.5, 255, 127.5). BGRABitmap's
  default draw mode expands both colours by its gamma first, and the same
  rect comes out (169, 255, 169) -- every translucent fill and every
  antialiased edge lighter than upstream's.

  It also made one mark two colours. The layer at rest is painted on an
  opaque ground by the painter (the gamma blend); what moves is painted on
  a clear bitmap that the window's canvas composites (source-over as the
  browser's). So a translucent bar was one colour while its enter
  animation ran and another the frame it ended. }

{$mode objfpc}{$H+}

interface
uses Classes, SysUtils, Math, fpcunit, testregistry,
     Controls, Graphics, Forms, BGRABitmap, BGRABitmapTypes,
     tyControls.Controller, tyControls.AdvanceChart;
type
  TCbProbe = class(TTyAdvanceChart)
  public
    procedure Layered(ACanvas: TCanvas; const ARect: TRect; APPI: Integer);
  end;

  TAdvChartCanvasBlendTest = class(TTestCase)
  private
    FForm: TForm;
    FCtl: TTyStyleController;
    FChart: TCbProbe;
    { an opaque 24-bit canvas, as a window's }
    FBmp: TBitmap;
    FAt: Integer;
    function Pix(AX, AY: Integer): TBGRAPixel;
    procedure Start(const AOption: string);
    procedure Frames(ACount: Integer);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAHalfClearFillAtRestIsTheCanvas;
    procedure TestAHalfClearStrokeAtRestIsTheCanvas;
    procedure TestTwoHalfClearFillsAtRestAreTheCanvas;
    procedure TestAnAntialiasedEdgeIsTheCanvas;
    procedure TestASplitAreaIsTheCanvas;
    procedure TestABarIsOneInkInMotionAndAtRest;
    procedure TestAProgressiveRunsLayerIsTheCanvas;
    procedure TestALargeBatchIsTheCanvas;
    procedure TestAnExportIsTheCanvasToo;
  end;

implementation

const
  cT0 = 1700000000000;

procedure PinClocks(AChart: TTyCustomAdvanceChart; AAt: Double);
begin
  AChart.AnimNow := AAt;
  AChart.TooltipNow := AAt;
  AChart.DataZoomNow := AAt;
  AChart.BrushNow := AAt;
  AChart.ParallelExpandNow := AAt;
  AChart.TimelineNow := AAt;
end;

procedure TCbProbe.Layered(ACanvas: TCanvas; const ARect: TRect; APPI: Integer);
begin
  RenderCached(ACanvas, ARect, APPI);
end;

procedure TAdvChartCanvasBlendTest.SetUp;
begin
  inherited SetUp;
  FForm := TForm.CreateNew(nil);
  FCtl := TTyStyleController.Create(nil);
  FCtl.Mode := 'light';
  FCtl.ThemeName := 'default';
end;

procedure TAdvChartCanvasBlendTest.TearDown;
begin
  FreeAndNil(FChart);
  FreeAndNil(FForm);
  FreeAndNil(FCtl);
  FreeAndNil(FBmp);
  inherited TearDown;
end;

procedure TAdvChartCanvasBlendTest.Start(const AOption: string);
begin
  FreeAndNil(FChart);
  FreeAndNil(FBmp);
  FChart := TCbProbe.Create(FForm);
  FChart.Parent := FForm;
  FChart.Controller := FCtl;
  FChart.SetBounds(0, 0, 400, 300);
  FAt := 0;
  PinClocks(FChart, cT0);
  FBmp := TBitmap.Create;
  FBmp.PixelFormat := pf24bit;
  FBmp.SetSize(400, 300);
  FBmp.Canvas.Brush.Color := clWhite;
  FBmp.Canvas.FillRect(Rect(0, 0, 400, 300));
  FChart.AnimationMode := camAlways;
  FChart.SetOption(AOption, True);
  AssertEquals('parses', '', FChart.OptionError);
  FChart.Layered(FBmp.Canvas, Rect(0, 0, 400, 300), 96);
end;

procedure TAdvChartCanvasBlendTest.Frames(ACount: Integer);
var t: Integer;
begin
  for t := 1 to ACount do
  begin
    Inc(FAt, 16);
    PinClocks(FChart, cT0 + FAt);
    FChart.AnimTick(cT0 + FAt);
    FChart.Layered(FBmp.Canvas, Rect(0, 0, 400, 300), 96);
  end;
end;

function TAdvChartCanvasBlendTest.Pix(AX, AY: Integer): TBGRAPixel;
var c: TColor;
begin
  c := ColorToRGB(FBmp.Canvas.Pixels[AX, AY]);
  Result := BGRA(Red(c), Green(c), Blue(c), 255);
end;

function Px(const P: TBGRAPixel): string;
begin
  Result := Format('(%d,%d,%d)', [P.red, P.green, P.blue]);
end;

const
  cRest = '{"animation":false,"backgroundColor":"#ffffff","graphic":[%s],'
    + '"series":[]}';

{ a rect of #00ff00 at opacity 0.5 on white: 255 - 255 * 0.5 [was: 169] }
procedure TAdvChartCanvasBlendTest.TestAHalfClearFillAtRestIsTheCanvas;
var p: TBGRAPixel;
begin
  Start(Format(cRest, ['{"type":"rect","shape":{"x":100,"y":100,"width":60,"height":60},'
    + '"style":{"fill":"#00ff00","opacity":0.5}}']));
  p := Pix(130, 130);
  AssertTrue('the half-clear rect on white: ' + Px(p),
    (p.red >= 126) and (p.red <= 129) and (p.green = 255) and (p.blue = p.red));
  { and a colour that carries its own alpha }
  Start(Format(cRest, ['{"type":"rect","shape":{"x":100,"y":100,"width":60,"height":60},'
    + '"style":{"fill":"rgba(0,0,0,0.25)"}}']));
  p := Pix(130, 130);
  AssertTrue('a quarter of black on white: ' + Px(p),
    (p.red >= 190) and (p.red <= 192) and (p.green = p.red) and (p.blue = p.red));
end;

{ a line 20 px wide of #000000 at opacity 0.5: its middle is 127.5 }
procedure TAdvChartCanvasBlendTest.TestAHalfClearStrokeAtRestIsTheCanvas;
var p: TBGRAPixel;
begin
  Start(Format(cRest, ['{"type":"line","shape":{"x1":60,"y1":150,"x2":340,"y2":150},'
    + '"style":{"stroke":"#000000","lineWidth":20,"opacity":0.5}}']));
  p := Pix(200, 150);
  AssertTrue('the half-clear line on white: ' + Px(p),
    (p.red >= 126) and (p.red <= 129) and (p.green = p.red) and (p.blue = p.red));
end;

{ two rects of #ff0000 at 0.5, one over the other: the canvas' second
  source-over is 255 - (255 - 127.5) * 0.5 on green and blue, about 64 }
procedure TAdvChartCanvasBlendTest.TestTwoHalfClearFillsAtRestAreTheCanvas;
var p: TBGRAPixel;
begin
  Start(Format(cRest, ['{"type":"rect","shape":{"x":100,"y":100,"width":60,"height":60},'
    + '"style":{"fill":"#ff0000","opacity":0.5}},'
    + '{"type":"rect","shape":{"x":130,"y":100,"width":60,"height":60},'
    + '"style":{"fill":"#ff0000","opacity":0.5}}']));
  p := Pix(115, 130);
  AssertTrue('one of them: ' + Px(p), (p.red = 255) and (p.green >= 126) and (p.green <= 129));
  p := Pix(145, 130);
  AssertTrue('both: ' + Px(p), (p.red = 255) and (p.green >= 62) and (p.green <= 66)
    and (p.blue = p.green));
end;

{ AN OPAQUE BLACK RECT FROM x 100.5: the column it half covers is half
  its ink, 127.5 [was: 170 -- every antialiased edge a quarter lighter than
  upstream's, a hairline with it] }
procedure TAdvChartCanvasBlendTest.TestAnAntialiasedEdgeIsTheCanvas;
var p: TBGRAPixel;
begin
  Start(Format(cRest, ['{"type":"rect","shape":{"x":100.5,"y":100,"width":60,"height":60},'
    + '"style":{"fill":"#000000"}}']));
  p := Pix(130, 130);
  AssertTrue('inside: ' + Px(p), p.red = 0);
  p := Pix(100, 130);
  AssertTrue('the half-covered column at its left: ' + Px(p),
    (p.red >= 126) and (p.red <= 129) and (p.green = p.red) and (p.blue = p.red));
  p := Pix(160, 130);
  AssertTrue('and at its right: ' + Px(p),
    (p.red >= 126) and (p.red <= 129) and (p.green = p.red) and (p.blue = p.red));
end;

{ a grid's split areas of rgba(0,0,0,0.2) on white: 255 * 0.8 [was: 224,
  filled past the canvas state, as a control's background is] }
procedure TAdvChartCanvasBlendTest.TestASplitAreaIsTheCanvas;
const
  cOpt = '{"animation":false,"backgroundColor":"#ffffff","grid":{"left":40,"right":40,"top":40,"bottom":40},'
    + '"xAxis":{"type":"category","data":["a","b"],"axisLine":{"show":false},"axisTick":{"show":false},'
    + '"axisLabel":{"show":false},"splitLine":{"show":false},'
    + '"splitArea":{"show":true,"areaStyle":{"color":["rgba(0,0,0,0.2)","rgba(0,0,0,0.2)"]}}},'
    + '"yAxis":{"type":"value","show":false},"series":[]}';
var p: TBGRAPixel;
begin
  Start(cOpt);
  p := Pix(120, 150);
  AssertTrue('a fifth of black on white: ' + Px(p),
    (p.red >= 203) and (p.red <= 205) and (p.green = p.red) and (p.blue = p.red));
end;

{ A BAR OF OPACITY 0.5 through its enter animation and after it: the ink
  of its foot is the same while it grows (the layer in motion) and when it
  stands (the layer at rest) [was: darker while it grew, lighter the frame
  the animation ended] }
procedure TAdvChartCanvasBlendTest.TestABarIsOneInkInMotionAndAtRest;
const
  cBar = '{"animation":true,"animationDuration":1000,"animationEasing":"linear","backgroundColor":"#ffffff",'
    + '"grid":{"left":40,"right":40,"top":40,"bottom":40},'
    + '"xAxis":{"type":"category","data":["a"],"show":false},'
    + '"yAxis":{"type":"value","min":0,"max":10,"show":false},'
    + '"series":[{"type":"bar","barWidth":100,"itemStyle":{"color":"#00ff00","opacity":0.5},"data":[10]}]}';
var moving, rest: TBGRAPixel;
begin
  Start(cBar);
  { 480 ms of 1000: the bar is about half its height, its foot is inked }
  Frames(30);
  AssertTrue('the animation runs', FChart.AnimLive);
  moving := Pix(200, 250);
  AssertTrue('the foot of the growing bar is inked: ' + Px(moving), moving.red < 250);
  AssertTrue('the top of the plot is not yet: ' + Px(Pix(200, 50)), Pix(200, 50).red = 255);
  Frames(60);
  AssertFalse('the animation ended', FChart.AnimLive);
  rest := Pix(200, 250);
  AssertTrue('the bar in motion ' + Px(moving) + ' is the bar at rest ' + Px(rest),
    (Abs(moving.red - rest.red) <= 1) and (Abs(moving.green - rest.green) <= 1)
    and (Abs(moving.blue - rest.blue) <= 1));
  AssertTrue('and both the canvas'': ' + Px(rest), (rest.red >= 126) and (rest.red <= 129));
end;

{ A SCATTER DRAWN IN CHUNKS ON A LAYER OF ITS OWN (more rows than its
  progressiveThreshold; of z -1, so on the ground's zlevel and laid on the
  ground in the layer at rest): the layer is laid on the picture as the browser
  lays a canvas on another -- a symbol of opacity 0.5 is 127.5 there too
  [was: 169, the layer put through the gamma blend] }
procedure TAdvChartCanvasBlendTest.TestAProgressiveRunsLayerIsTheCanvas;
const
  cOpt = '{"animation":false,"backgroundColor":"#ffffff","grid":{"left":40,"right":40,"top":40,"bottom":40},'
    + '"xAxis":{"type":"value","min":0,"max":10,"show":false},'
    + '"yAxis":{"type":"value","min":0,"max":10,"show":false},'
    + '"series":[{"type":"scatter","z":-1,"symbolSize":24,"progressive":4,"progressiveThreshold":10,'
    + '"itemStyle":{"color":"#00ff00","opacity":0.5},'
    + '"data":[[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[8,5],[9,5],[1.5,8],[2.5,8],[3.5,8]]}]}';
var p: TBGRAPixel; n: Integer; fast: Boolean;
begin
  { the frames that blit a kept picture and draw the chunk on it, and the
    full paints that lay the run's layer }
  try
    for fast := False to True do
    begin
      TyAdvChartProgFastForTest(fast);
      Start(cOpt);
      n := 0;
      while FChart.ProgressiveUnfinished and (n < 20) do
      begin
        FChart.ProgressTick;
        FChart.Layered(FBmp.Canvas, Rect(0, 0, 400, 300), 96);
        Inc(n);
      end;
      AssertFalse('drawn to the end', FChart.ProgressiveUnfinished);
      AssertTrue('a progressive run', n > 0);
      { the symbol at x 5 (200 px), y 5 (150 px) }
      p := Pix(200, 150);
      AssertTrue(Format('fast %s: the half-clear symbol of the run: %s', [BoolToStr(fast, True), Px(p)]),
        (p.red >= 126) and (p.red <= 129) and (p.green = 255) and (p.blue = p.red));
    end;
  finally
    TyAdvChartProgFastForTest(True);
  end;
end;

{ A LARGE BATCH is drawn opaque on a tile and the tile laid at the
  series' opacity: 127.5 as well [was: 169] }
procedure TAdvChartCanvasBlendTest.TestALargeBatchIsTheCanvas;
const
  cOpt = '{"animation":false,"backgroundColor":"#ffffff","grid":{"left":40,"right":40,"top":40,"bottom":40},'
    + '"xAxis":{"type":"value","min":0,"max":10,"show":false},'
    + '"yAxis":{"type":"value","min":0,"max":10,"show":false},'
    + '"series":[{"type":"scatter","large":true,"largeThreshold":1,"symbolSize":24,'
    + '"itemStyle":{"color":"#00ff00","opacity":0.5},"data":[[5,5],[1,1],[9,9]]}]}';
var p: TBGRAPixel;
begin
  Start(cOpt);
  p := Pix(200, 150);
  AssertTrue('the half-clear symbol of the batch: ' + Px(p),
    (p.red >= 126) and (p.red <= 129) and (p.green = 255) and (p.blue = p.red));
end;

{ the picture an export draws, on its own opaque ground }
procedure TAdvChartCanvasBlendTest.TestAnExportIsTheCanvasToo;
var bmp: TBGRABitmap; p: TBGRAPixel;
begin
  Start(Format(cRest, ['{"type":"rect","shape":{"x":100,"y":100,"width":60,"height":60},'
    + '"style":{"fill":"#00ff00","opacity":0.5}}']));
  bmp := FChart.RenderToBitmap('');
  try
    p := bmp.GetPixel(130, 130);
    AssertTrue('the half-clear rect in the export: ' + Px(p),
      (p.red >= 126) and (p.red <= 129) and (p.green = 255) and (p.blue = p.red));
  finally
    bmp.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartCanvasBlendTest);
end.
