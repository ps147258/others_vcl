//########################################################################//
//                                                                        //
//  文字編輯框行編號模組                                                  //
//                                                                        //
//########################################################################//
// 類型：VCL元件功能加強                                                  //
// 編寫：Wei-Lun Huang                                                    //
// 版權：Copyright (c) 2020 Wei-Lun Huang                                 //
// 說明：繪製字串行編號。                                                 //
//                                                                        //
// 作用：                                                                 //
//   1. TLineNumber                                                       //
//      在關聯的控制項中繪製字串的行編號                                  //
//      * 注意：釋放物件時需要注意程式流程，以先建立後釋放為原則。        //
//              請參閱 Bind 與 Unbind 功能，WindowProc 覆蓋。             //
//                                                                        //
// 其他：                                                                 //
//                                                                        //
// 最後變更日期：2020年12月12日                                           //
//                                                                        //
//########################################################################//

//
//  Memo box line number module.
//
// Type: VCL Component Enhancements.
// Author: 2020 Wei-Lun Huang
// Description: Draw the line numbers of the text.
//
// Features:
//   1. TLineNumber
//      Draw the line numbers of the string in the associated control.
//      * Note: Need check program flow when releasing objects.
//              principle is first in and last out for objects, 
//              like order of the stack, please.
//              See the Bind and Unbind function, about WindowProc override.
//
//
// Last modified date: Dec 12, 2020.

unit Vcl.Memo.LineNumbers;

{$OPTIMIZATION ON}

interface

uses
  System.SysUtils, System.Types, System.Classes, Winapi.Messages, System.Math,
  Vcl.Graphics, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TLineNumberStyle = set of (_LNS_FontColor, _LNS_BackgroundColor);

  TLineNumbers = class(TComponent)
  private const
    DefaultFontColor = clBtnShadow;
  private
    FMemo: TCustomMemo;
    FControl: TControl;
    FPicture: TPicture;
    FGraphic: TGraphic;
    FCanvas: TCanvas;
    FCtlCanvas: TCanvas;
    FMemoProc: TWndMethod;
    FControlProc: TWndMethod;
    FFontColor: TColor;
    FBackgroundColor: TColor;
    FDistance: Integer;
    FLastFirst: Integer;
    FLastCount: Integer;
    FTopSide: Integer;
    FGap: TPoint;
    FMemoHeight: Integer;
    FMemoRect: TRect;
    FCanvasSize: TSize;
    FImmediate: Boolean;
    FStyle: TLineNumberStyle;
    procedure Associate(AMemo: TCustomMemo; AControl: TControl);
    procedure Unassociate;
    procedure SetFontColor(Color: TColor);
    procedure SetBackgroundColor(Color: TColor);
  protected
    //
    // 當 Memo 或 繪製目標控制項 的位置或大小發生變化時應呼叫。
    // When Memo or target drawing control item size changes, call this.
    procedure SyncCanvas;

    // 當 Memo 字體變更後時應呼叫，以保持繪製文字時的大小位置。
    // When the Memo font is changed to keep the size and position when drawing text.
    procedure SyncFont; overload;
    procedure SyncFont(Color: TColor); overload;
    procedure SyncFont(Default: Boolean); overload;

    procedure Paint;

    procedure MemoProc(var Message: TMessage);
    procedure ControlProc(var Message: TMessage);

  public
    // 當有覆蓋 Memo 與 繪製目標控制項 的 WindowProc 時不建議設定主體元件 AOwner。
    // 因為需要掌控還原時的函數執行位址，順序錯誤將導致執行出現嚴重錯誤。
    // It is not recommended to set the belonging component AOwner when WindowProc
    // overrides of Memo or draw target control.
    // Because need to handle the execution address of the function when restoring,
    // a sequence mistake will make serious execution errors.
    constructor Create(AOwner: TComponent); overload; override;

    // 建立時設定來源 Memo 與 目標控制項。
    // Set the source Memo and target controls when creating.
    constructor Create(AOwner: TComponent; AMemo: TCustomMemo; AControl: TControl; Immediate: Boolean = False); reintroduce; overload;

    // 建立時設定來源 Memo 並將目標控制項指定為該 Memo 的父控制項。
    // Set the source Memo when creating and specify the target control as the parent control of the Memo.
    constructor Create(AOwner: TComponent; AMemo: TCustomMemo; Immediate: Boolean = False); reintroduce; overload;

    destructor Destroy; override;

    // 建立連動 與 解除連動
    // 注意執行順序，當有覆蓋 Memo 與 繪製目標控制項 的 WindowProc 時，這個順序很重要。
    // About Bind and Unbind.
    // Attention, the order of execution. If the WindowProc of Memo or draw target control items be covers, the order is very important.

    // 建立連動
    // Manually bind linkage components.
    procedure Bind(AMemo: TCustomMemo; AControl: TControl);

    // 解除連動
    // Manually unbind.
    procedure Unbind;

    // 區域失效，使控制項收到繪製要求後能重新繪製
    procedure Invalidate;
    function Update: Boolean;

    property Memo: TCustomMemo read FMemo;
    property Control: TControl read FControl;

    property FontColor: TColor read FFontColor write SetFontColor;
    property BackgroundColor: TColor read FBackgroundColor write SetBackgroundColor;

    // 當指定繪製目的為 Memo 的父控制項時的繪製間格。
    // The left distance when drawing on the parent control of TMemo.
    property Distance: Integer read FDistance write FDistance;

    // 是否立即更新繪製
    // Update drawing immediately when Memo changed.
    property Immediate: Boolean read FImmediate write FImmediate;
  end;

implementation

//uses
//  Debug;

resourcestring
  rcErrBind      = 'Already bound.';
  rcErrUnbind    = 'Can''t manually unbind the owner.';
  rcErrControl   = 'No target Memo control.';
  rcErrSeated    = 'Target control is seated.';
  rcErrParamEdit = 'The parameter Memo cannot be nil.';
  rcErrClass     = 'Class %s is Not supported.';

type
  TCustomControlEx = class(TCustomControl)
  published
    property Canvas;
  end;

  TControlEx = class(TControl)
  published
    property Color;
  end;

  TGraphicControlEx = class(TGraphicControl)
  published
    property Canvas;
  end;

  TCustomMemoEx = class(TCustomMemo)
  published
    property Color;
    property Font;
  end;

procedure RectSetSize(out Rect: TRect; Width, Height: Integer); inline;
begin
  Rect.Left   := 0;
  Rect.Top    := 0;
  Rect.Right  := Width;
  Rect.Bottom := Height;
end;

procedure RectOffsetY(out Rect: TRect; Y: Integer); inline;
begin
  Inc(Rect.Top, Y);
  Inc(Rect.Bottom, Y);
end;

procedure UpdateMax(var Changed: Boolean; var OutValue: Integer; InValue: Integer); overload; inline;
begin
  if InValue > OutValue then
  begin
    OutValue := InValue;
    Changed := True;
  end;
end;

procedure UpdateMax(var Changed: Boolean; var OutValue: TSize; InValue: TSize); overload; inline;
begin
  UpdateMax(Changed, OutValue.cx, InValue.cx);
  UpdateMax(Changed, OutValue.cy, InValue.cy);
end;

{ TLineNumber }

constructor TLineNumbers.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

constructor TLineNumbers.Create(AOwner: TComponent; AMemo: TCustomMemo; AControl: TControl; Immediate: Boolean);
begin
  Self.Immediate := Immediate;
  Associate(AMemo, AControl);
  inherited Create(AOwner);
end;

constructor TLineNumbers.Create(AOwner: TComponent; AMemo: TCustomMemo; Immediate: Boolean);
begin
  Create(AOwner, AMemo, nil, Immediate);
end;

destructor TLineNumbers.Destroy;
begin
  Unassociate;
  inherited;
end;

procedure TLineNumbers.SyncCanvas;
var
  Bitmap: TBitmap;
  P: TPoint;
begin
  FMemoHeight := FMemo.Height;
  P := FMemo.ClientOrigin;
  FGap := FControl.ScreenToClient(P);
  if FMemo.Parent = FControl then
  begin
    FTopSide := FGap.Y - FMemo.Top;
    Dec(FGap.X, FDistance);
    Dec(FGap.Y, FTopSide);
  end
  else
  begin
    FTopSide := 0;
    FGap.X := 0;
  end;
  FMemoRect := FMemo.ClientRect;

  FCanvasSize := TSize.Create(0, 0);

  Invalidate;

  if FControl is TImage then
    Exit;

  if not Assigned(FPicture) then
    FPicture := TPicture.Create;

  if Assigned(FPicture.Graphic) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.Width := FCanvasSize.Width;
    Bitmap.Height := FCanvasSize.Height;
    FPicture.Graphic := Bitmap;
    FGraphic := FPicture.Graphic;
  finally
    Bitmap.Free;
  end;

  FCanvas := TBitmap(FPicture.Graphic).Canvas;
  FCanvas.Brush.Assign(FCtlCanvas.Brush);
  FCanvas.Pen.Assign(FCtlCanvas.Pen);
  if FMemo.Parent <> FControl then
    FCanvas.Brush.Color := TControlEx(FControl).Color;
end;

procedure TLineNumbers.SyncFont;
begin
  FCanvas.Font.Assign(TCustomMemoEx(FMemo).Font);
  if _LNS_FontColor in FStyle then
    FCanvas.Font.Color := FFontColor
  else
    FCanvas.Font.Color := DefaultFontColor;
end;

procedure TLineNumbers.SyncFont(Color: TColor);
begin
  FCanvas.Font.Assign(TCustomMemoEx(FMemo).Font);
  FCanvas.Font.Color := Color;
  FFontColor := Color;
  Include(FStyle, _LNS_FontColor);
end;

procedure TLineNumbers.SyncFont(Default: Boolean);
begin
  FCanvas.Font.Assign(TCustomMemoEx(FMemo).Font);
  if Default then
  begin
    Exclude(FStyle, _LNS_FontColor);
    FCanvas.Font.Color := DefaultFontColor;
  end
  else
  begin
    FCanvas.Font.Color := FFontColor;
  end;
end;

procedure TLineNumbers.Invalidate;
begin
  FLastFirst := -1;
  FLastCount := -1;
end;

procedure TLineNumbers.Associate(AMemo: TCustomMemo; AControl: TControl);
begin
  if Assigned(FMemoProc) then
    raise Exception.Create(rcErrSeated);

  if not Assigned(AMemo) then
    raise Exception.Create(rcErrParamEdit);

  if not Assigned(AControl) then
    AControl := AMemo.Parent;

  FMemo := AMemo;
  FControl := AControl;
  FDistance := 5;

  if AControl is TImage then
  begin
    FCanvas := TImage(AControl).Canvas;
    FGraphic := TImage(AControl).Picture.Graphic;
    FCanvasSize.Width := FGraphic.Width;
    FCanvasSize.Height := FGraphic.Height;
//    FCanvasSize := TImage(AControl).ClientRect.Size;
  end
  else
  begin
    if AControl is TCustomControl then
      FCtlCanvas := TCustomControlEx(AControl).Canvas
    else if AControl is TCustomForm then
      FCtlCanvas := TCustomForm(AControl).Canvas
    else
      raise Exception.CreateFmt(rcErrClass, [AControl.ClassName]);
  end;

  FStyle := [];
  SyncCanvas;
  SyncFont(clBtnShadow);

  if Assigned(FPicture) then
  begin
    FControlProc := AControl.WindowProc;
    AControl.WindowProc := ControlProc;
  end;

  FMemoProc := AMemo.WindowProc;
  AMemo.WindowProc := MemoProc;
end;

procedure TLineNumbers.Unassociate;
begin
  FMemo.WindowProc := FMemoProc;

  if Assigned(FPicture) then
  begin
    FControl.WindowProc := FControlProc;
    FControlProc := nil;
    FreeAndNil(FPicture);
  end;

  FMemoProc := nil;
  FCanvas := nil;
end;

procedure TLineNumbers.SetFontColor(Color: TColor);
begin
  SyncFont(Color);
end;

procedure TLineNumbers.SetBackgroundColor(Color: TColor);
begin
  FCanvas.Brush.Color := Color;
  FBackgroundColor := Color;
  Include(FStyle, _LNS_BackgroundColor);
end;

procedure TLineNumbers.Paint;
var
  N, C, H: Integer;
  R: TRect;
  Size: TSize;
  Base: TSize;
  S: string;
  B: Boolean;
begin
  N := FLastFirst;
  C := FLastCount;

  FCanvas.Lock;
  try
    Size := FCanvas.TextExtent(C.ToString);

    if FMemo.Parent = FControl then
      Base := TSize.Create(Size.Width, FMemoHeight)
    else
      Base := TSize.Create(FControl.ClientWidth, FMemoHeight);

    B := False;
    UpdateMax(B, FCanvasSize, Base);

    RectSetSize(R, Base.Width, Base.Height);

    if Assigned(FPicture) then
    begin
      H := FMemoRect.Height;
    end
    else
    begin
      RectOffsetY(R, FGap.Y);
      H := FMemoRect.Height + FGap.y;
    end;

    if B then
      if FControl is TImage then
        FGraphic.SetSize(FCanvasSize.Width, FCanvasSize.Height + FGap.y)
      else
        FGraphic.SetSize(FCanvasSize.Width, FCanvasSize.Height);

    FCanvas.FillRect(R);

    R.Height := FTopSide + Size.Height;
    RectOffsetY(R, FTopSide);

    while (R.Top < H) and (N <= C) do
    begin
      S := N.ToString;
      FCanvas.TextRect(R, S, [tfRight]);
      RectOffsetY(R, Size.Height);
      Inc(N);
    end;
  finally
    FCanvas.Unlock;
  end;

  if FImmediate then
    FControl.Repaint
  else
    FControl.Invalidate;
end;

function TLineNumbers.Update: Boolean;
var
  N, C: Integer;
begin
  N := FMemo.Perform(EM_GETFIRSTVISIBLELINE, 0, 0) + 1;
  C := FMemo.Perform(EM_GETLINECOUNT, 0, 0);
  Result := (N <> FLastFirst) or (C <> FLastCount);
  if not Result then
    Exit;

  FLastFirst := N;
  FLastCount := C;

  Paint;
end;

procedure TLineNumbers.MemoProc(var Message: TMessage);
begin
  FMemoProc(Message);

  case Message.Msg of
    WM_MOVE:
      if FMemo.Parent = FControl then
      begin
        SyncCanvas;
        FControl.Invalidate;
      end;
    WM_SIZE:
      begin
        SyncCanvas;
        FControl.Invalidate;
      end;

    WM_FONTCHANGE:
      SyncFont;

    WM_PAINT, CM_CHANGED:
      Update;
//    WM_PRINTCLIENT:
//      FControl.Invalidate;
  end;
end;

procedure TLineNumbers.ControlProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_PAINT:
    begin
      FControlProc(Message);
      if FMemo.Parent = FControl then
        FCtlCanvas.Draw(FGap.X - FPicture.Width, FGap.Y, FPicture.Graphic)
      else
        FCtlCanvas.Draw(0, FGap.Y, FPicture.Graphic);
      Message.Result := 0;
    end;
    WM_ERASEBKGND:
    begin
      if FMemo.Parent <> FControl then
        Message.Result := -1;
      FControlProc(Message);
    end;
    else
      FControlProc(Message);
  end;
end;

procedure TLineNumbers.Bind(AMemo: TCustomMemo; AControl: TControl);
begin
  Associate(AMemo, AControl);
end;

procedure TLineNumbers.Unbind;
begin
  if Self.Owner = FMemo then
    raise Exception.Create(rcErrUnbind);
  Unassociate;
end;

end.
