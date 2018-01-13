//########################################################################//
//                                                                        //
//  檔案拖放訊息模組                                                      //
//                                                                        //
//########################################################################//
// 類型：Windows 訊息處理                                                 //
// 編寫：Wei-Lun Huang                                                    //
// 版權：Copyright (c) 2018 Wei-Lun Huang                                 //
// 說明：取得拖放的檔案列表。                                             //
//                                                                        //
// 作用：                                                                 //
//   1. GetDropFile                                                       //
//      取得拖放的檔案，同時拖放多個檔案時只會取第一項。                  //
//      需要傳入一個有效的 TStrings (例：TStringList)                     //
//   2. GetDropFiles                                                      //
//      取得多個拖放的檔案。                                              //
//      * GetDropFiles(Msg, Strings, Limit): Integer;                     //
//        取得的檔案路徑會加入到 Strings 尾端，並回傳取得的數量。         //
//      * GetDropFiles(Msg, Limit): TStringList;                          //
//        若回傳值不為 nil，則需要在使用完畢後手動釋放。                  //
//   3. TDropFiles                                                        //
//      取得拖放檔案列表的元件。                                          //
//                                                                        //
// 歷程：                                                                 //
//   2018年01月12日 GetDropFile、GetDropFiles、TDropFiles 功能            //
//                                                                        //
// 其他：                                                                 //
//                                                                        //
// 最後變更日期：2018年01月12日                                           //
//                                                                        //
//########################################################################//

//
//  File Drag&Drop message module.
//
// Type: Windows message process.
// Author: 2018 Wei-Lun Huang
// Description: Get a list of files dropped.
//
// Features:
//   1. GetDropFile
//      Get a dropped file. if drop multiple files, take only the first.
//      Need to provide a implemented TStrings. (Example: TStringList)
//   2. GetDropFiles
//      Get multiple dropped files to TStrings.
//      * GetDropFiles(Msg, Strings, Limit): Integer;
//        Add dropped files to Strings, and return count of files.
//      * GetDropFiles(Msg, Limit): TStringList;
//        If the return value is not nil, the return object need to manually release after use.
//   3. TDropFiles
//      Auto process of file drag-drop and use the OnDrop event property response.
//
// History:
//   Jan 12, 2018 GetDropFile, GetDropFiles and TDropFiles feature.
//
// Tested in Delphi 10 Seattle.
//
// Last modified date: Jan 12, 2018.

unit Vcl.DragFiles;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Classes,
  Vcl.Controls;

type
  TDropEvent = procedure(Sender: TObject; WinControl: TWinControl) of object;

  TDropFiles = class(TComponent)
  private
    FOwner: TComponent;
    FWindowProc: TWndMethod;
    FWinControl: TWinControl;
    FOnDrop: TDropEvent;
    FEnabled: Boolean;
    FPaths: TStringList;
    FLimit: Integer;
    procedure WindowProc(var Message: TMessage);
    procedure Hook(Value: TWinControl); inline;
    procedure Unhook; inline;
    procedure SetWinControl(Value: TWinControl);
    procedure SetEnabled(Value: Boolean);
    function GetPath(Index: Integer): string; inline;
    function GetFirst: string; inline;
    function GetCount: Integer; inline;
    function GetStrings: TStrings; inline;
  public
    constructor Create(AOwner: TComponent; DropEvent: TDropEvent = nil); reintroduce;
    destructor Destroy; override;
    procedure Clear;            // Clear paths list.
    procedure Accept; inline;   // Accept drag files.
    procedure Disallow; inline; // Disallow drag files.
    property WinControl: TWinControl read FWinControl write SetWinControl; // Target window control.
    property OnDrop: TDropEvent read FOnDrop write FOnDrop; // Files drop event.
    property Enabled: Boolean read FEnabled write SetEnabled; // Drag accept.
    property Paths[Index: Integer]: string read GetPath; // File path string.
    property First: string read GetFirst;                // First file path.
    property Count: Integer read GetCount;               // Count of list item.
    property Limit: Integer read FLimit write FLimit; // Limit count of files in one drop event.
    property Strings: TStrings read GetStrings;          // Get strings.
  end;

// Get a dropped file.
function GetDropFile(const Msg: TMessage): string;

// Get multiple dropped files to Strings.
// Only result number of drop files and no add to Strings with Limit is zero.
// If Limit is less than zero, no limit the files count for add to Strings.
function GetDropFiles(const Msg: TMessage; Strings: TStrings; Limit: Integer = -1): Integer; overload;

// Get multiple dropped files, result string list.
// No limit the files count for add to Strings, if Limit is less than or equal to zero.
function GetDropFiles(const Msg: TMessage; Limit: Integer = -1): TStringList; overload;

resourcestring
  _NotWinControl = 'No support to create from the not is TWinControl class.';
  _CannotChangeControl = 'Cannot change WinControl because the Owner was specified at create.';

implementation

//
// Currently put aside, the future may have functionality will need to use.
//

// Remove double quotes form the begin and end of string.
procedure RemoveDoubleQuotes(var Str: string);
var
  Len: Integer;
begin
  Len := Length(Str);
  if Len > 1 then
  begin
    if (Str[1] = '"') and (Str[Len] = '"') then
      if Len = 2 then
        Str := ''
      else
        Str := Copy(Str, 2, Len - 2);
  end;
end;

//
// Implementation.
//

function GetDropFile(const Msg: TMessage): string;
var
  FileMsg: TWMDropFiles absolute Msg;
  I: Integer;
begin
  try
    I := DragQueryFile(FileMsg.Drop, $FFFFFFFF, nil, 0); // Get files Number.
    if I <> 1 then
      Exit;
    I := DragQueryFile(FileMsg.Drop, 0, nil, 0); // Length of file name.
    if I <= 0 then
      Exit;
    SetLength(Result, I); // Set capacity of string memory.
    DragQueryFile(FileMsg.Drop, 0, PChar(Result), I + 1); // Copy file name.
  finally
    DragFinish(FileMsg.Drop); // Releases memory that the system allocated.
  end;
end;

function GetDropFiles(const Msg: TMessage; Strings: TStrings; Limit: Integer): Integer;
var
  FileMsg: TWMDropFiles absolute Msg;
  I, J: Integer;
  Len: Integer;
  FileName: string;
begin
  if not Assigned(Strings) then
    Exit(-1);
  Result := 0;
  Strings.BeginUpdate;
  try
    J := DragQueryFile(FileMsg.Drop, $FFFFFFFF, nil, 0); // Get files Number.
    if (J > 0) and (Limit <> 0) then
    begin
      I := 0;
      repeat
        Len := DragQueryFile(FileMsg.Drop, I, nil, 0); // Length of file name.
        if Len > 0 then // Ignore empty string.
        begin
          WideCharLenToStrVar(nil, Len, FileName); // Set capacity of string buffer.
          DragQueryFile(FileMsg.Drop, I, PChar(FileName), Len + 1); // Copy file name.
          if FileName[1] <> #0 then
          begin
            Strings.Add(FileName); // Add to the list of Strings.
            Inc(Result);
            if Limit > 0 then // The limit of negative doesn't limit the number of outputs.
              if Strings.Count = Limit then // Exit when count reach to limit.
                Exit;
          end;
        end;
        Inc(I);
      until (I = J);
    end;
  finally
    DragFinish(FileMsg.Drop); // Releases memory that the system allocated.
    Strings.EndUpdate;
  end;
end;

function GetDropFiles(const Msg: TMessage; Limit: Integer): TStringList;
var
  FileMsg: TWMDropFiles absolute Msg;
  Count, I: Integer;
  Len: Integer;
  FileName: string;
begin
  try
    Count := DragQueryFile(FileMsg.Drop, $FFFFFFFF, nil, 0); // Get files Number.
    if Count > 0 then
    begin
      Result := TStringList.Create;
      I := 0;
      repeat
        Len := DragQueryFile(FileMsg.Drop, I, nil, 0); // Length of file name.
        if Len > 0 then // Ignore empty string.
        begin
          WideCharLenToStrVar(nil, Len, FileName); // Set capacity of string buffer.
          DragQueryFile(FileMsg.Drop, I, PChar(FileName), Len + 1); // Copy file name.
          Result.Add(FileName); // Add to the list of result.
          if Limit > 0 then // The limit of negative or zero doesn't limit the number of outputs.
            if Result.Count = Limit then // Exit when count reach to limit.
              Exit;
        end;
        Inc(I);
      until (I = Count);
      Exit;
    end;
  finally
    DragFinish(FileMsg.Drop); // Releases memory that the system allocated.
  end;
  Result := nil;
end;

{ TDropFiles }

constructor TDropFiles.Create(AOwner: TComponent; DropEvent: TDropEvent);
begin
  inherited Create(AOwner);
  FOwner := AOwner;
  FOnDrop := DropEvent;
  FEnabled := Assigned(DropEvent);
  FPaths := TStringList.Create;
  FLimit := -1;

  if Assigned(AOwner) then
  begin
    if AOwner is TWinControl then
      Hook(TWinControl(AOwner))
    else
      raise Exception.Create(_NotWinControl);
  end
  else
  begin
    FWindowProc := nil;
    FWinControl := nil;
  end;
end;

destructor TDropFiles.Destroy;
begin
  Unhook;
  FPaths.Free;
  inherited;
end;

procedure TDropFiles.WindowProc(var Message: TMessage);
begin
  try
    case Message.Msg of
      WM_CREATE:
        if FEnabled then
          DragAcceptFiles(FWinControl.Handle, True);
      WM_DESTROY:
        if not FEnabled and FWinControl.HandleAllocated then
          DragAcceptFiles(FWinControl.Handle, False);
      WM_DROPFILES:
      begin
        FPaths.Clear;
        if GetDropFiles(Message, FPaths, FLimit) > 0 then
          if Assigned(FOnDrop) then
            FOnDrop(Self, FWinControl);
      end;
    end;
  finally
    FWindowProc(Message); // Call backup of WindowProc.
  end;
end;

procedure TDropFiles.Hook(Value: TWinControl);
var
  Wnd: HWND;
begin
  if Assigned(Value) then
  begin
    FWinControl := Value;
    FWindowProc := Value.WindowProc;
    Value.WindowProc := WindowProc;
    Wnd := FWinControl.Handle;
    if FEnabled and (Wnd <> 0) then
      DragAcceptFiles(Wnd, True);
  end;
end;

procedure TDropFiles.Unhook;
begin
  if Assigned(FWinControl) then
  begin
    if FEnabled and FWinControl.HandleAllocated then
      DragAcceptFiles(FWinControl.Handle, False);
    FWinControl.WindowProc := FWindowProc;
    FWindowProc := nil;
  end;
end;

procedure TDropFiles.SetWinControl(Value: TWinControl);
begin
  if Assigned(FOwner) then
    raise Exception.Create(_CannotChangeControl)
  else if Value <> FWinControl then
  begin
    Unhook;
    FEnabled := False;
    Hook(Value);
  end;
end;

procedure TDropFiles.SetEnabled(Value: Boolean);
begin
  if Assigned(FWinControl) then
  begin
    if Value or FWinControl.HandleAllocated then
    begin
      FEnabled := Value;
      DragAcceptFiles(FWinControl.Handle, Value);
      Exit;
    end;
  end;
  FEnabled := False;
end;

procedure TDropFiles.Clear;
begin
  FPaths.Clear;
end;

procedure TDropFiles.Accept;
begin
  SetEnabled(True);
end;

procedure TDropFiles.Disallow;
begin
  SetEnabled(False);
end;

function TDropFiles.GetPath(Index: Integer): string;
begin
  Result := FPaths.Strings[Index];
end;

function TDropFiles.GetFirst: string;
begin
  if FPaths.Count <> 0 then
    Result := FPaths.Strings[0];
end;

function TDropFiles.GetCount: Integer;
begin
  Result := FPaths.Count;
end;

function TDropFiles.GetStrings: TStrings;
begin
  Result := FPaths;
end;

end.
