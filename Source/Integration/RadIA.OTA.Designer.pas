unit RadIA.OTA.Designer;

interface

uses
  System.Classes,
  RadIA.Core.Designer,
  RadIA.Core.DesignerEvents;

type
  TRadIAOTAFormDesignerFacade = class(
    TInterfacedObject,
    IRadIAFormDesignerFacade,
    IRadIAFormDesignerMutationFacade,
    IRadIAFormDesignerComponentFacade,
    IRadIAFormDesignerEventFacade
  )
  private
    procedure RunOnMainThread(const AAction: TThreadProcedure);
  public
    function GetActiveForm: TRadIAFormSnapshot;
    function ListFormComponents(
      const AMaxCount: Integer
    ): TArray<TRadIAFormComponentSnapshot>;
    function GetComponentBounds(
      const AComponentName: string;
      out AFormFileName: string;
      out ABounds: TRadIAComponentBounds
    ): Boolean;
    function ApplyComponentBounds(
      const AFormFileName: string;
      const AComponentName: string;
      const AExpectedBounds: TRadIAComponentBounds;
      const ANewBounds: TRadIAComponentBounds;
      out AActualBounds: TRadIAComponentBounds
    ): Boolean;
    function GetComponentProperty(
      const AComponentName: string;
      const APropertyName: string;
      out AFormFileName: string;
      out AValue: TRadIAComponentPropertyValue
    ): Boolean;
    function ApplyComponentProperty(
      const AFormFileName: string;
      const AComponentName: string;
      const AExpectedValue: TRadIAComponentPropertyValue;
      const ANewValue: TRadIAComponentPropertyValue;
      out AActualValue: TRadIAComponentPropertyValue
    ): Boolean;
    function GetComponentSnapshot(
      const AComponentName: string;
      out AFormFileName: string;
      out ASnapshot: TRadIAFormComponentSnapshot
    ): Boolean;
    function CreateComponent(
      const AFormFileName: string;
      const AParentName: string;
      const AClassName: string;
      const AComponentName: string;
      const ABounds: TRadIAComponentBounds;
      out ACreated: TRadIAFormComponentSnapshot
    ): Boolean;
    function RemoveComponent(
      const AFormFileName: string;
      const AExpected: TRadIAFormComponentSnapshot;
      out AActual: TRadIAFormComponentSnapshot
    ): Boolean;
    function PrepareEvent(
      const AComponentName: string;
      const AEventName: string;
      const AHandlerName: string;
      out AState: TRadIAFormEventState
    ): Boolean;
    function ApplyEvent(
      const AExpected: TRadIAFormEventState;
      out AApplied: TRadIAFormEventState
    ): Boolean;
    function RevertEvent(
      const AExpected: TRadIAFormEventState
    ): Boolean;
  end;

implementation

uses
  DesignIntf,
  System.Math,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  ToolsAPI,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Winapi.Windows,
  RadIA.Core.Types,
  RadIA.OTA.TextReader;

const
  CDesignerUnavailable = 'The Form Designer is shutting down.';

function ResolveAllowedComponentClass(
  const AClassName: string
): TComponentClass;
begin
  Result := nil;
  if SameText(AClassName, 'TButton') then
    Exit(TButton);
  if SameText(AClassName, 'TCheckBox') then
    Exit(TCheckBox);
  if SameText(AClassName, 'TComboBox') then
    Exit(TComboBox);
  if SameText(AClassName, 'TEdit') then
    Exit(TEdit);
  if SameText(AClassName, 'TGroupBox') then
    Exit(TGroupBox);
  if SameText(AClassName, 'TLabel') then
    Exit(TLabel);
  if SameText(AClassName, 'TListBox') then
    Exit(TListBox);
  if SameText(AClassName, 'TMemo') then
    Exit(TMemo);
  if SameText(AClassName, 'TPanel') then
    Exit(TPanel);
  if SameText(AClassName, 'TRadioButton') then
    Result := TRadioButton;
end;

function IsSensitivePropertyName(
  const APropertyName: string
): Boolean;
var
  LName: string;
begin
  LName := LowerCase(APropertyName);
  Result := LName.Contains('password') or
    LName.Contains('secret') or
    LName.Contains('token') or
    LName.Contains('apikey') or
    LName.Contains('connectionstring');
end;

function IsSafeProperty(
  const APropertyName: string;
  const APropInfo: PPropInfo
): Boolean;
begin
  Result := Assigned(APropInfo) and
    Assigned(APropInfo.SetProc) and
    not SameText(APropertyName, 'Name') and
    not IsSensitivePropertyName(APropertyName) and
    (APropInfo.PropType^.Kind in [
      tkInteger,
      tkChar,
      tkEnumeration,
      tkFloat,
      tkString,
      tkSet,
      tkWChar,
      tkLString,
      tkWString,
      tkInt64,
      tkUString
    ]);
end;

function TryReadProperty(
  const AComponent: TComponent;
  const APropertyName: string;
  out AValue: TRadIAComponentPropertyValue
): Boolean;
var
  LPropInfo: PPropInfo;
begin
  AValue := Default(TRadIAComponentPropertyValue);
  if not Assigned(AComponent) then
    Exit(False);

  LPropInfo := GetPropInfo(AComponent.ClassInfo, APropertyName);
  if not IsSafeProperty(APropertyName, LPropInfo) then
    Exit(False);

  try
    AValue := TRadIAComponentPropertyValue.Create(
      string(LPropInfo.Name),
      string(LPropInfo.PropType^.Name),
      VarToStr(GetPropValue(AComponent, LPropInfo, True))
    );
    Result := True;
  except
    Result := False;
  end;
end;

function FindActiveFormEditor(
  out AModule: IOTAModule;
  out AFormEditor: IOTAFormEditor
): Boolean;
var
  LEditor: IOTAEditor;
  LIndex: Integer;
  LModuleServices: IOTAModuleServices;
begin
  AModule := nil;
  AFormEditor := nil;
  Result := False;
  if not Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    Exit;

  AModule := LModuleServices.CurrentModule;
  if not Assigned(AModule) then
    Exit;

  for LIndex := 0 to AModule.GetModuleFileCount - 1 do
  begin
    LEditor := AModule.GetModuleFileEditor(LIndex);
    if Supports(LEditor, IOTAFormEditor, AFormEditor) then
      Exit(True);
  end;
end;

function GetNativeComponent(
  const AComponent: IOTAComponent
): TComponent;
var
  LNative: INTAComponent;
begin
  Result := nil;
  if Supports(AComponent, INTAComponent, LNative) then
    Result := LNative.GetComponent;
end;

function FindSourceEditor(
  const AModule: IOTAModule;
  out ASourceEditor: IOTASourceEditor
): Boolean;
var
  LEditor: IOTAEditor;
  LIndex: Integer;
begin
  ASourceEditor := nil;
  Result := False;
  if not Assigned(AModule) then
    Exit;
  for LIndex := 0 to AModule.GetModuleFileCount - 1 do
  begin
    LEditor := AModule.GetModuleFileEditor(LIndex);
    if Supports(LEditor, IOTASourceEditor, ASourceEditor) then
      Exit(True);
  end;
end;

function GetEventHandlerName(
  const ADesigner: IDesigner;
  const AComponent: TComponent;
  const APropInfo: PPropInfo
): string;
var
  LMethod: TMethod;
begin
  Result := '';
  if not Assigned(ADesigner) or not Assigned(AComponent) or
    not Assigned(APropInfo) then
    Exit;
  LMethod := GetMethodProp(AComponent, APropInfo);
  if Assigned(LMethod.Code) then
    Result := ADesigner.GetMethodName(LMethod);
end;

procedure ClearEventHandler(
  const AComponent: TComponent;
  const APropInfo: PPropInfo
);
var
  LMethod: TMethod;
begin
  LMethod.Code := nil;
  LMethod.Data := nil;
  SetMethodProp(AComponent, APropInfo, LMethod);
end;

function IsWritableEvent(
  const AComponent: TComponent;
  const AEventName: string;
  out APropInfo: PPropInfo
): Boolean;
begin
  APropInfo := nil;
  if not Assigned(AComponent) then
    Exit(False);
  APropInfo := GetPropInfo(AComponent.ClassInfo, AEventName);
  Result := Assigned(APropInfo) and
    Assigned(APropInfo.SetProc) and
    (APropInfo.PropType^.Kind = tkMethod);
end;

function ReplaceSourceText(
  const ASourceEditor: IOTASourceEditor;
  const ACurrentSource: string;
  const ANewSource: string
): Boolean;
var
  LCurrentBytes: TBytes;
  LNewText: UTF8String;
  LWriter: IOTAEditWriter;
begin
  Result := False;
  if not Assigned(ASourceEditor) then
    Exit;
  LCurrentBytes := TEncoding.UTF8.GetBytes(ACurrentSource);
  LNewText := UTF8Encode(ANewSource);
  LWriter := ASourceEditor.CreateUndoableWriter;
  if not Assigned(LWriter) then
    Exit;
  LWriter.CopyTo(0);
  if Length(LCurrentBytes) > 0 then
    LWriter.DeleteTo(Length(LCurrentBytes));
  LWriter.Insert(PAnsiChar(LNewText));
  LWriter := nil;
  Result := ReadRadIAEditReaderText(
    ASourceEditor.CreateReader
  ) = ANewSource;
end;

function GetComponentName(
  const AComponent: IOTAComponent
): string;
var
  LComponent: TComponent;
begin
  Result := '';
  LComponent := GetNativeComponent(AComponent);
  if Assigned(LComponent) then
    Result := LComponent.Name;
end;

function FindNamedComponent(
  const AFormEditor: IOTAFormEditor;
  const AComponentName: string
): IOTAComponent;
var
  LRoot: IOTAComponent;
begin
  Result := nil;
  if not Assigned(AFormEditor) then
    Exit;
  LRoot := AFormEditor.GetRootComponent;
  if (Trim(AComponentName) = '') or
    (Assigned(LRoot) and SameText(
      GetComponentName(LRoot),
      AComponentName
    )) then
    Exit(LRoot);
  Result := AFormEditor.FindComponent(AComponentName);
end;

function IsSelected(
  const AComponent: IOTAComponent;
  const AFormEditor: IOTAFormEditor
): Boolean;
var
  LIndex: Integer;
  LSelected: IOTAComponent;
begin
  Result := False;
  for LIndex := 0 to AFormEditor.GetSelCount - 1 do
  begin
    LSelected := AFormEditor.GetSelComponent(LIndex);
    if Assigned(LSelected) and
      (LSelected.GetComponentHandle =
        AComponent.GetComponentHandle) then
      Exit(True);
  end;
end;

function CreateComponentSnapshot(
  const AComponent: IOTAComponent;
  const AFormEditor: IOTAFormEditor
): TRadIAFormComponentSnapshot;
var
  LControl: TControl;
  LNative: TComponent;
  LParent: IOTAComponent;
begin
  LNative := GetNativeComponent(AComponent);
  LParent := AComponent.GetParent;
  Result := TRadIAFormComponentSnapshot.Create(
    GetComponentName(AComponent),
    AComponent.GetComponentType,
    GetComponentName(LParent),
    AComponent.IsTControl,
    IsSelected(AComponent, AFormEditor),
    0,
    0
  );

  if Assigned(LNative) and (LNative is TControl) then
  begin
    LControl := TControl(LNative);
    Result := TRadIAFormComponentSnapshot.Create(
      LControl.Name,
      AComponent.GetComponentType,
      GetComponentName(LParent),
      True,
      IsSelected(AComponent, AFormEditor),
      LControl.Left,
      LControl.Top
    );
    Result.SetSize(LControl.Width, LControl.Height);
  end;
end;

{ TRadIAOTAFormDesignerFacade }

function TRadIAOTAFormDesignerFacade.CreateComponent(
  const AFormFileName: string;
  const AParentName: string;
  const AClassName: string;
  const AComponentName: string;
  const ABounds: TRadIAComponentBounds;
  out ACreated: TRadIAFormComponentSnapshot
): Boolean;
var
  LCreated: TRadIAFormComponentSnapshot;
  LResult: Boolean;
begin
  LCreated := Default(TRadIAFormComponentSnapshot);
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LComponentClass: TComponentClass;
      LDesigner: INTAFormEditor;
      LEditor: IOTAFormEditor;
      LModule: IOTAModule;
      LNative: TComponent;
      LNativeParent: TComponent;
      LParent: IOTAComponent;
    begin
      if not FindActiveFormEditor(LModule, LEditor) or
        not SameFileName(LEditor.FileName, AFormFileName) or
        Assigned(FindNamedComponent(LEditor, AComponentName)) then
        Exit;
      if Trim(AParentName) = '' then
        LParent := LEditor.GetRootComponent
      else
        LParent := FindNamedComponent(LEditor, AParentName);
      if not Assigned(LParent) then
        Exit;
      LComponentClass := ResolveAllowedComponentClass(AClassName);
      LNativeParent := GetNativeComponent(LParent);
      if not Assigned(LComponentClass) or
        not Assigned(LNativeParent) or
        not Supports(LEditor, INTAFormEditor, LDesigner) or
        not Assigned(LDesigner.FormDesigner) then
        Exit;

      LNative := LDesigner.FormDesigner.CreateComponent(
        LComponentClass,
        LNativeParent,
        ABounds.Left,
        ABounds.Top,
        ABounds.Width,
        ABounds.Height
      );
      if not Assigned(LNative) then
        Exit;
      try
        if not (LNative is TControl) then
          Exit;
        LNative.Name := AComponentName;
        TControl(LNative).SetBounds(
          ABounds.Left,
          ABounds.Top,
          ABounds.Width,
          ABounds.Height
        );
        LComponent := LEditor.FindComponent(AComponentName);
        if not Assigned(LComponent) then
          Exit;
        LCreated := CreateComponentSnapshot(LComponent, LEditor);
        if not SameText(LCreated.Name, AComponentName) or
          not SameText(LCreated.ClassName, AClassName) then
          Exit;
        LDesigner.FormDesigner.Modified;
        LResult := True;
      finally
        if not LResult then
        begin
          if Assigned(LComponent) then
            LComponent.Delete
          else
            LNative.Free;
        end;
      end;
    end
  );
  ACreated := LCreated;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.ApplyEvent(
  const AExpected: TRadIAFormEventState;
  out AApplied: TRadIAFormEventState
): Boolean;
var
  LApplied: TRadIAFormEventState;
  LResult: Boolean;
begin
  LApplied := Default(TRadIAFormEventState);
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LDesignerEditor: INTAFormEditor;
      LEditor: IOTAFormEditor;
      LMethod: TMethod;
      LModule: IOTAModule;
      LNative: TComponent;
      LPropInfo: PPropInfo;
      LSourceAfter: string;
      LSourceEditor: IOTASourceEditor;
    begin
      if not FindActiveFormEditor(LModule, LEditor) or
        not SameFileName(
          LEditor.FileName,
          AExpected.Identity.FormFileName
        ) or
        not SameFileName(
          LModule.FileName,
          AExpected.Identity.UnitFileName
        ) or
        not FindSourceEditor(LModule, LSourceEditor) or
        not Supports(LEditor, INTAFormEditor, LDesignerEditor) or
        not Assigned(LDesignerEditor.FormDesigner) then
        Exit;
      LComponent := FindNamedComponent(
        LEditor,
        AExpected.Identity.ComponentName
      );
      LNative := GetNativeComponent(LComponent);
      if not IsWritableEvent(
        LNative,
        AExpected.Identity.EventName,
        LPropInfo
      ) or
        not SameText(
          string(LPropInfo.PropType^.Name),
          AExpected.Identity.EventTypeName
        ) or
        (GetEventHandlerName(
          LDesignerEditor.FormDesigner,
          LNative,
          LPropInfo
        ) <> AExpected.OriginalHandlerName) or
        (ReadRadIAEditReaderText(
          LSourceEditor.CreateReader
        ) <> AExpected.BeforeSource) or
        LDesignerEditor.FormDesigner.MethodExists(
          AExpected.Identity.HandlerName
        ) then
        Exit;

      try
        LMethod := LDesignerEditor.FormDesigner.CreateMethod(
          AExpected.Identity.HandlerName,
          GetTypeData(LPropInfo.PropType^)
        );
        if not Assigned(LMethod.Code) then
          raise EInvalidOperation.Create(
            'The Form Designer did not create the requested method.'
          );
        SetMethodProp(LNative, LPropInfo, LMethod);
        LDesignerEditor.FormDesigner.Modified;
        LSourceAfter := ReadRadIAEditReaderText(
          LSourceEditor.CreateReader
        );
        if (LSourceAfter = AExpected.BeforeSource) or
          not SameText(
            GetEventHandlerName(
              LDesignerEditor.FormDesigner,
              LNative,
              LPropInfo
            ),
            AExpected.Identity.HandlerName
          ) then
          raise EInvalidOperation.Create(
            'The event handler transaction was not persisted.'
          );
        LApplied := AExpected.WithAfterSource(LSourceAfter);
        LResult := True;
      except
        try
          ClearEventHandler(LNative, LPropInfo);
          LSourceAfter := ReadRadIAEditReaderText(
            LSourceEditor.CreateReader
          );
          ReplaceSourceText(
            LSourceEditor,
            LSourceAfter,
            AExpected.BeforeSource
          );
          LDesignerEditor.FormDesigner.Modified;
        except
          // The transaction reports failure after the best-effort rollback.
        end;
      end;
    end
  );
  AApplied := LApplied;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.GetComponentSnapshot(
  const AComponentName: string;
  out AFormFileName: string;
  out ASnapshot: TRadIAFormComponentSnapshot
): Boolean;
var
  LFileName: string;
  LResult: Boolean;
  LSnapshot: TRadIAFormComponentSnapshot;
begin
  LFileName := '';
  LResult := False;
  LSnapshot := Default(TRadIAFormComponentSnapshot);
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LEditor: IOTAFormEditor;
      LModule: IOTAModule;
    begin
      if not FindActiveFormEditor(LModule, LEditor) then
        Exit;
      LComponent := FindNamedComponent(LEditor, AComponentName);
      if not Assigned(LComponent) then
        Exit;
      LFileName := LEditor.FileName;
      LSnapshot := CreateComponentSnapshot(LComponent, LEditor);
      LResult := True;
    end
  );
  AFormFileName := LFileName;
  ASnapshot := LSnapshot;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.PrepareEvent(
  const AComponentName: string;
  const AEventName: string;
  const AHandlerName: string;
  out AState: TRadIAFormEventState
): Boolean;
var
  LResult: Boolean;
  LState: TRadIAFormEventState;
begin
  LResult := False;
  LState := Default(TRadIAFormEventState);
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LDesignerEditor: INTAFormEditor;
      LEditor: IOTAFormEditor;
      LIdentity: TRadIAFormEventIdentity;
      LModule: IOTAModule;
      LNative: TComponent;
      LOriginalHandler: string;
      LPropInfo: PPropInfo;
      LSource: string;
      LSourceEditor: IOTASourceEditor;
    begin
      if not FindActiveFormEditor(LModule, LEditor) or
        not FindSourceEditor(LModule, LSourceEditor) or
        not Supports(LEditor, INTAFormEditor, LDesignerEditor) or
        not Assigned(LDesignerEditor.FormDesigner) or
        LDesignerEditor.FormDesigner.IsSourceReadOnly or
        LDesignerEditor.FormDesigner.MethodExists(AHandlerName) then
        Exit;
      LComponent := FindNamedComponent(LEditor, AComponentName);
      LNative := GetNativeComponent(LComponent);
      if not IsWritableEvent(LNative, AEventName, LPropInfo) then
        Exit;
      LOriginalHandler := GetEventHandlerName(
        LDesignerEditor.FormDesigner,
        LNative,
        LPropInfo
      );
      if LOriginalHandler <> '' then
        Exit;
      LSource := ReadRadIAEditReaderText(
        LSourceEditor.CreateReader
      );
      if LSource = '' then
        Exit;
      LIdentity := TRadIAFormEventIdentity.Create(
        LEditor.FileName,
        LModule.FileName,
        AComponentName,
        string(LPropInfo.Name),
        string(LPropInfo.PropType^.Name),
        AHandlerName
      );
      LState := TRadIAFormEventState.Create(
        LIdentity,
        LOriginalHandler,
        LSource,
        ''
      );
      LResult := True;
    end
  );
  AState := LState;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.RemoveComponent(
  const AFormFileName: string;
  const AExpected: TRadIAFormComponentSnapshot;
  out AActual: TRadIAFormComponentSnapshot
): Boolean;
var
  LActual: TRadIAFormComponentSnapshot;
  LResult: Boolean;
begin
  LActual := Default(TRadIAFormComponentSnapshot);
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LDesigner: INTAFormEditor;
      LEditor: IOTAFormEditor;
      LModule: IOTAModule;
    begin
      if not FindActiveFormEditor(LModule, LEditor) or
        not SameFileName(LEditor.FileName, AFormFileName) then
        Exit;
      LComponent := FindNamedComponent(LEditor, AExpected.Name);
      if not Assigned(LComponent) then
        Exit;
      if (LComponent.GetComponentCount > 0) or
        (LComponent.GetControlCount > 0) then
        Exit;
      LActual := CreateComponentSnapshot(LComponent, LEditor);
      if not SameText(LActual.ClassName, AExpected.ClassName) or
        not SameText(LActual.ParentName, AExpected.ParentName) or
        (LActual.Left <> AExpected.Left) or
        (LActual.Top <> AExpected.Top) or
        (LActual.Width <> AExpected.Width) or
        (LActual.Height <> AExpected.Height) then
        Exit;
      if not LComponent.Delete then
        Exit;
      LComponent := nil;
      if Supports(LEditor, INTAFormEditor, LDesigner) and
        Assigned(LDesigner.FormDesigner) then
        LDesigner.FormDesigner.Modified;
      LResult := True;
    end
  );
  AActual := LActual;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.RevertEvent(
  const AExpected: TRadIAFormEventState
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LDesignerEditor: INTAFormEditor;
      LEditor: IOTAFormEditor;
      LMethod: TMethod;
      LModule: IOTAModule;
      LNative: TComponent;
      LPropInfo: PPropInfo;
      LSourceEditor: IOTASourceEditor;
    begin
      if (AExpected.AfterSource = '') or
        not FindActiveFormEditor(LModule, LEditor) or
        not SameFileName(
          LEditor.FileName,
          AExpected.Identity.FormFileName
        ) or
        not SameFileName(
          LModule.FileName,
          AExpected.Identity.UnitFileName
        ) or
        not FindSourceEditor(LModule, LSourceEditor) or
        not Supports(LEditor, INTAFormEditor, LDesignerEditor) or
        not Assigned(LDesignerEditor.FormDesigner) then
        Exit;
      LComponent := FindNamedComponent(
        LEditor,
        AExpected.Identity.ComponentName
      );
      LNative := GetNativeComponent(LComponent);
      if not IsWritableEvent(
        LNative,
        AExpected.Identity.EventName,
        LPropInfo
      ) or
        not SameText(
          GetEventHandlerName(
            LDesignerEditor.FormDesigner,
            LNative,
            LPropInfo
          ),
          AExpected.Identity.HandlerName
        ) or
        (ReadRadIAEditReaderText(
          LSourceEditor.CreateReader
        ) <> AExpected.AfterSource) then
        Exit;
      try
        ClearEventHandler(LNative, LPropInfo);
        if not ReplaceSourceText(
          LSourceEditor,
          AExpected.AfterSource,
          AExpected.BeforeSource
        ) then
        begin
          LMethod := LDesignerEditor.FormDesigner.CreateMethod(
            AExpected.Identity.HandlerName,
            GetTypeData(LPropInfo.PropType^)
          );
          SetMethodProp(LNative, LPropInfo, LMethod);
          Exit;
        end;
        LDesignerEditor.FormDesigner.Modified;
        LResult := True;
      except
        LResult := False;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.ApplyComponentBounds(
  const AFormFileName: string;
  const AComponentName: string;
  const AExpectedBounds: TRadIAComponentBounds;
  const ANewBounds: TRadIAComponentBounds;
  out AActualBounds: TRadIAComponentBounds
): Boolean;
var
  LActualBounds: TRadIAComponentBounds;
  LResult: Boolean;
begin
  LActualBounds := Default(TRadIAComponentBounds);
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LControl: TControl;
      LFormDesigner: INTAFormEditor;
      LFormEditor: IOTAFormEditor;
      LModule: IOTAModule;
      LNative: TComponent;
    begin
      if not FindActiveFormEditor(LModule, LFormEditor) then
        Exit;
      if not SameFileName(LFormEditor.FileName, AFormFileName) then
        Exit;

      LComponent := FindNamedComponent(LFormEditor, AComponentName);
      LNative := GetNativeComponent(LComponent);
      if not Assigned(LNative) or
        not (LNative is TControl) then
        Exit;
      LControl := TControl(LNative);

      LActualBounds := TRadIAComponentBounds.Create(
        LControl.Left,
        LControl.Top,
        LControl.Width,
        LControl.Height
      );
      if not LActualBounds.Equals(AExpectedBounds) then
        Exit;
      if not Supports(
        LFormEditor,
        INTAFormEditor,
        LFormDesigner
      ) or not Assigned(LFormDesigner.FormDesigner) then
        Exit;

      try
        LControl.SetBounds(
          ANewBounds.Left,
          ANewBounds.Top,
          ANewBounds.Width,
          ANewBounds.Height
        );
        LFormDesigner.FormDesigner.Modified;
      except
        LControl.SetBounds(
          AExpectedBounds.Left,
          AExpectedBounds.Top,
          AExpectedBounds.Width,
          AExpectedBounds.Height
        );
        LActualBounds := TRadIAComponentBounds.Create(
          LControl.Left,
          LControl.Top,
          LControl.Width,
          LControl.Height
        );
        Exit;
      end;
      LActualBounds := TRadIAComponentBounds.Create(
        LControl.Left,
        LControl.Top,
        LControl.Width,
        LControl.Height
      );
      if not LActualBounds.Equals(ANewBounds) then
      begin
        LControl.SetBounds(
          AExpectedBounds.Left,
          AExpectedBounds.Top,
          AExpectedBounds.Width,
          AExpectedBounds.Height
        );
        LActualBounds := TRadIAComponentBounds.Create(
          LControl.Left,
          LControl.Top,
          LControl.Width,
          LControl.Height
        );
        Exit;
      end;

      LResult := True;
    end
  );
  AActualBounds := LActualBounds;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.ApplyComponentProperty(
  const AFormFileName: string;
  const AComponentName: string;
  const AExpectedValue: TRadIAComponentPropertyValue;
  const ANewValue: TRadIAComponentPropertyValue;
  out AActualValue: TRadIAComponentPropertyValue
): Boolean;
var
  LActualValue: TRadIAComponentPropertyValue;
  LResult: Boolean;
begin
  LActualValue := Default(TRadIAComponentPropertyValue);
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LFormDesigner: INTAFormEditor;
      LFormEditor: IOTAFormEditor;
      LModule: IOTAModule;
      LNative: TComponent;
      LPropInfo: PPropInfo;
    begin
      if not FindActiveFormEditor(LModule, LFormEditor) then
        Exit;
      if not SameFileName(LFormEditor.FileName, AFormFileName) then
        Exit;

      LComponent := FindNamedComponent(LFormEditor, AComponentName);
      LNative := GetNativeComponent(LComponent);
      if not TryReadProperty(
        LNative,
        AExpectedValue.Name,
        LActualValue
      ) or not LActualValue.Equals(AExpectedValue) then
        Exit;
      if (ANewValue.Name <> AExpectedValue.Name) or
        (ANewValue.TypeName <> AExpectedValue.TypeName) then
        Exit;
      if not Supports(
        LFormEditor,
        INTAFormEditor,
        LFormDesigner
      ) or not Assigned(LFormDesigner.FormDesigner) then
        Exit;

      LPropInfo := GetPropInfo(
        LNative.ClassInfo,
        AExpectedValue.Name
      );
      try
        SetPropValue(LNative, LPropInfo, ANewValue.Value);
        if not TryReadProperty(
          LNative,
          AExpectedValue.Name,
          LActualValue
        ) or not LActualValue.Equals(ANewValue) then
        begin
          SetPropValue(LNative, LPropInfo, AExpectedValue.Value);
          TryReadProperty(
            LNative,
            AExpectedValue.Name,
            LActualValue
          );
          Exit;
        end;
        LFormDesigner.FormDesigner.Modified;
      except
        try
          SetPropValue(LNative, LPropInfo, AExpectedValue.Value);
          TryReadProperty(
            LNative,
            AExpectedValue.Name,
            LActualValue
          );
        except
          LActualValue := Default(TRadIAComponentPropertyValue);
        end;
        Exit;
      end;
      LResult := True;
    end
  );
  AActualValue := LActualValue;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.GetActiveForm:
  TRadIAFormSnapshot;
var
  LResult: TRadIAFormSnapshot;
begin
  LResult := Default(TRadIAFormSnapshot);
  RunOnMainThread(
    procedure
    var
      LFormEditor: IOTAFormEditor;
      LModule: IOTAModule;
      LRoot: IOTAComponent;
    begin
      if not FindActiveFormEditor(LModule, LFormEditor) then
        Exit;

      LRoot := LFormEditor.GetRootComponent;
      if not Assigned(LRoot) then
        Exit;

      LResult := TRadIAFormSnapshot.Create(
        True,
        GetComponentName(LRoot),
        LRoot.GetComponentType,
        LModule.FileName,
        LFormEditor.FileName,
        LRoot.GetComponentCount,
        LFormEditor.GetSelCount
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.GetComponentBounds(
  const AComponentName: string;
  out AFormFileName: string;
  out ABounds: TRadIAComponentBounds
): Boolean;
var
  LBounds: TRadIAComponentBounds;
  LFormFileName: string;
  LResult: Boolean;
begin
  LBounds := Default(TRadIAComponentBounds);
  LFormFileName := '';
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LControl: TControl;
      LFormEditor: IOTAFormEditor;
      LModule: IOTAModule;
      LNative: TComponent;
    begin
      if not FindActiveFormEditor(LModule, LFormEditor) then
        Exit;
      LComponent := FindNamedComponent(LFormEditor, AComponentName);
      if not Assigned(LComponent) or
        not LComponent.IsTControl then
        Exit;
      LNative := GetNativeComponent(LComponent);
      if not Assigned(LNative) or
        not (LNative is TControl) then
        Exit;
      LControl := TControl(LNative);

      LFormFileName := LFormEditor.FileName;
      LBounds := TRadIAComponentBounds.Create(
        LControl.Left,
        LControl.Top,
        LControl.Width,
        LControl.Height
      );
      LResult := True;
    end
  );
  AFormFileName := LFormFileName;
  ABounds := LBounds;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.GetComponentProperty(
  const AComponentName: string;
  const APropertyName: string;
  out AFormFileName: string;
  out AValue: TRadIAComponentPropertyValue
): Boolean;
var
  LFormFileName: string;
  LResult: Boolean;
  LValue: TRadIAComponentPropertyValue;
begin
  LFormFileName := '';
  LResult := False;
  LValue := Default(TRadIAComponentPropertyValue);
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LFormEditor: IOTAFormEditor;
      LModule: IOTAModule;
      LNative: TComponent;
    begin
      if not FindActiveFormEditor(LModule, LFormEditor) then
        Exit;
      LComponent := FindNamedComponent(LFormEditor, AComponentName);
      LNative := GetNativeComponent(LComponent);
      if not TryReadProperty(LNative, APropertyName, LValue) then
        Exit;

      LFormFileName := LFormEditor.FileName;
      LResult := True;
    end
  );
  AFormFileName := LFormFileName;
  AValue := LValue;
  Result := LResult;
end;

function TRadIAOTAFormDesignerFacade.ListFormComponents(
  const AMaxCount: Integer
): TArray<TRadIAFormComponentSnapshot>;
var
  LResult: TArray<TRadIAFormComponentSnapshot>;
begin
  SetLength(LResult, 0);
  RunOnMainThread(
    procedure
    var
      LComponent: IOTAComponent;
      LCount: Integer;
      LFormEditor: IOTAFormEditor;
      LIndex: Integer;
      LModule: IOTAModule;
      LRoot: IOTAComponent;
    begin
      if AMaxCount <= 0 then
        Exit;
      if not FindActiveFormEditor(LModule, LFormEditor) then
        Exit;

      LRoot := LFormEditor.GetRootComponent;
      if not Assigned(LRoot) then
        Exit;

      LCount := Min(LRoot.GetComponentCount, AMaxCount);
      SetLength(LResult, LCount);
      for LIndex := 0 to LCount - 1 do
      begin
        LComponent := LRoot.GetComponent(LIndex);
        if Assigned(LComponent) then
          LResult[LIndex] := CreateComponentSnapshot(
            LComponent,
            LFormEditor
          );
      end;
    end
  );
  Result := LResult;
end;

procedure TRadIAOTAFormDesignerFacade.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    raise EInvalidOperation.Create(CDesignerUnavailable);

  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

end.
