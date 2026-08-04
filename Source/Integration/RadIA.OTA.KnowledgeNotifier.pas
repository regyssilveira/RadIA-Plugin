unit RadIA.OTA.KnowledgeNotifier;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.ExtCtrls,
  ToolsAPI,
  RadIA.Core.KnowledgeScheduler;

type
  IRadIAKnowledgeModuleNotifierControl = interface
    ['{01D61062-F268-463C-814D-2617D0670950}']
    procedure Deactivate;
  end;

  TRadIAKnowledgeModuleAttachment = record
  private
    FModuleIdentity: NativeUInt;
    FNotifierIndex: Integer;
  public
    constructor Create(
      const AModuleIdentity: NativeUInt;
      const ANotifierIndex: Integer
    );
    property ModuleIdentity: NativeUInt read FModuleIdentity;
    property NotifierIndex: Integer read FNotifierIndex;
  end;

  TRadIAOTAKnowledgeNotifier = class(TComponent)
  private
    FAttachments:
      TDictionary<string, TRadIAKnowledgeModuleAttachment>;
    FInstalled: Boolean;
    FModuleNotifier: IInterface;
    FModuleNotifierControl: IRadIAKnowledgeModuleNotifierControl;
    FScheduler: IRadIAKnowledgeRefreshScheduler;
    FTimer: TTimer;
    function TryFindAttachment(
      const AModuleIdentity: NativeUInt;
      out AFileName: string;
      out AAttachment: TRadIAKnowledgeModuleAttachment
    ): Boolean;
    function CanRefreshAttachments(
      out AModuleServices: IOTAModuleServices
    ): Boolean;
    procedure RefreshModuleAttachment(
      const AModule: IOTAModule;
      const ANotifier: IOTAModuleNotifier;
      const ACurrentFiles: TDictionary<string, Boolean>
    );
    procedure RemoveStaleAttachments(
      const ACurrentFiles: TDictionary<string, Boolean>
    );
    procedure RemoveInstalledNotifiers(
      const AModuleServices: IOTAModuleServices
    );
    procedure RefreshAttachments;
    procedure TimerEvent(Sender: TObject);
  public
    constructor Create(
      AOwner: TComponent;
      const AScheduler: IRadIAKnowledgeRefreshScheduler
    ); reintroduce;
    destructor Destroy; override;
    class function SupportsSourceFile(
      const AFileName: string
    ): Boolean; static;
    procedure Install;
    procedure PrepareForShutdown;
    procedure Uninstall;
  end;

function CreateRadIAKnowledgeModuleNotifier(
  const AScheduler: IRadIAKnowledgeRefreshScheduler
): IInterface;

implementation

uses
  System.IOUtils,
  System.SyncObjs,
  System.SysUtils,
  RadIA.Core.Logger,
  RadIA.Core.Types;

type
  TRadIAKnowledgeModuleNotifier = class(
    TNotifierObject,
    IOTAModuleNotifier,
    IRadIAKnowledgeModuleNotifierControl
  )
  private
    FScheduler: IRadIAKnowledgeRefreshScheduler;
  public
    constructor Create(
      const AScheduler: IRadIAKnowledgeRefreshScheduler
    );
    procedure Deactivate;
    procedure AfterSave;
    procedure BeforeSave;
    function CheckOverwrite: Boolean;
    procedure Destroyed;
    procedure Modified;
    procedure ModuleRenamed(const NewName: string);
  end;

{ TRadIAKnowledgeModuleAttachment }

constructor TRadIAKnowledgeModuleAttachment.Create(
  const AModuleIdentity: NativeUInt;
  const ANotifierIndex: Integer
);
begin
  FModuleIdentity := AModuleIdentity;
  FNotifierIndex := ANotifierIndex;
end;

{ TRadIAKnowledgeModuleNotifier }

procedure TRadIAKnowledgeModuleNotifier.AfterSave;
begin
  if Assigned(FScheduler) then
    FScheduler.MarkDirty;
end;

procedure TRadIAKnowledgeModuleNotifier.BeforeSave;
begin
  if True then ;
end;

function TRadIAKnowledgeModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

constructor TRadIAKnowledgeModuleNotifier.Create(
  const AScheduler: IRadIAKnowledgeRefreshScheduler
);
begin
  inherited Create;
  FScheduler := AScheduler;
end;

procedure TRadIAKnowledgeModuleNotifier.Deactivate;
begin
  FScheduler := nil;
end;

procedure TRadIAKnowledgeModuleNotifier.Destroyed;
begin
  if Assigned(FScheduler) then
    FScheduler.MarkDirty;
end;

procedure TRadIAKnowledgeModuleNotifier.Modified;
begin
  if Assigned(FScheduler) then
    FScheduler.MarkDirty;
end;

procedure TRadIAKnowledgeModuleNotifier.ModuleRenamed(
  const NewName: string
);
begin
  if Assigned(FScheduler) then
    FScheduler.MarkDirty;
end;

{ TRadIAOTAKnowledgeNotifier }

function CreateRadIAKnowledgeModuleNotifier(
  const AScheduler: IRadIAKnowledgeRefreshScheduler
): IInterface;
begin
  if not Assigned(AScheduler) then
    raise EArgumentNilException.Create('AScheduler');
  Result := TRadIAKnowledgeModuleNotifier.Create(AScheduler);
end;

constructor TRadIAOTAKnowledgeNotifier.Create(
  AOwner: TComponent;
  const AScheduler: IRadIAKnowledgeRefreshScheduler
);
var
  LNotifier: TRadIAKnowledgeModuleNotifier;
begin
  inherited Create(AOwner);
  if not Assigned(AScheduler) then
    raise EArgumentNilException.Create('AScheduler');
  FScheduler := AScheduler;
  FAttachments :=
    TDictionary<string, TRadIAKnowledgeModuleAttachment>.Create;
  LNotifier := TRadIAKnowledgeModuleNotifier.Create(FScheduler);
  FModuleNotifier := LNotifier;
  FModuleNotifierControl := LNotifier;
end;

function TRadIAOTAKnowledgeNotifier.CanRefreshAttachments(
  out AModuleServices: IOTAModuleServices
): Boolean;
begin
  Result := not GIsShuttingDown and
    (TInterlocked.CompareExchange(GProjectTransitionCount, 0, 0) = 0) and
    Supports(
      BorlandIDEServices,
      IOTAModuleServices,
      AModuleServices
    );
end;

destructor TRadIAOTAKnowledgeNotifier.Destroy;
begin
  Uninstall;
  FModuleNotifierControl := nil;
  FModuleNotifier := nil;
  FAttachments.Free;
  inherited;
end;

procedure TRadIAOTAKnowledgeNotifier.PrepareForShutdown;
begin
  FInstalled := False;
  if Assigned(FTimer) then
    FTimer.Enabled := False;
  FScheduler.Stop;
  if Assigned(FModuleNotifierControl) then
    FModuleNotifierControl.Deactivate;
  FAttachments.Clear;
end;

procedure TRadIAOTAKnowledgeNotifier.Install;
begin
  if FInstalled then
    Exit;
  FInstalled := True;
  RefreshAttachments;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 500;
  FTimer.OnTimer := TimerEvent;
  FTimer.Enabled := True;
end;

class function TRadIAOTAKnowledgeNotifier.SupportsSourceFile(
  const AFileName: string
): Boolean;
var
  LExtension: string;
begin
  LExtension := LowerCase(TPath.GetExtension(AFileName));
  Result := (LExtension = '.pas') or
    (LExtension = '.dpr') or
    (LExtension = '.dpk') or
    (LExtension = '.inc');
end;

procedure TRadIAOTAKnowledgeNotifier.RefreshAttachments;
var
  LCurrentFiles: TDictionary<string, Boolean>;
  LIndex: Integer;
  LModule: IOTAModule;
  LModuleServices: IOTAModuleServices;
  LNotifier: IOTAModuleNotifier;
begin
  if not CanRefreshAttachments(LModuleServices) then
    Exit;

  LCurrentFiles := TDictionary<string, Boolean>.Create;
  try
    Supports(FModuleNotifier, IOTAModuleNotifier, LNotifier);
    for LIndex := 0 to LModuleServices.ModuleCount - 1 do
    begin
      LModule := LModuleServices.Modules[LIndex];
      if Assigned(LModule) then
        RefreshModuleAttachment(LModule, LNotifier, LCurrentFiles);
      LModule := nil;
    end;
    RemoveStaleAttachments(LCurrentFiles);
  finally
    LCurrentFiles.Free;
  end;
end;

procedure TRadIAOTAKnowledgeNotifier.RefreshModuleAttachment(
  const AModule: IOTAModule;
  const ANotifier: IOTAModuleNotifier;
  const ACurrentFiles: TDictionary<string, Boolean>
);
var
  LExistingAttachment: TRadIAKnowledgeModuleAttachment;
  LExistingFileName: string;
  LFileName: string;
  LModuleIdentity: NativeUInt;
  LNotifierIndex: Integer;
begin
  LFileName := AModule.FileName;
  if not SupportsSourceFile(LFileName) then
    Exit;
  ACurrentFiles.AddOrSetValue(LFileName, True);
  LModuleIdentity := NativeUInt(Pointer(AModule));
  if TryFindAttachment(
    LModuleIdentity,
    LExistingFileName,
    LExistingAttachment
  ) then
  begin
    if not SameText(LExistingFileName, LFileName) then
    begin
      FAttachments.Remove(LExistingFileName);
      FAttachments.AddOrSetValue(LFileName, LExistingAttachment);
    end;
    Exit;
  end;
  LNotifierIndex := AModule.AddNotifier(ANotifier);
  if LNotifierIndex >= 0 then
    FAttachments.Add(
      LFileName,
      TRadIAKnowledgeModuleAttachment.Create(
        LModuleIdentity,
        LNotifierIndex
      )
    );
end;

procedure TRadIAOTAKnowledgeNotifier.RemoveInstalledNotifiers(
  const AModuleServices: IOTAModuleServices
);
var
  LFileName: string;
  LIndex: Integer;
  LModule: IOTAModule;
begin
  for LIndex := 0 to AModuleServices.ModuleCount - 1 do
  begin
    LModule := AModuleServices.Modules[LIndex];
    if not Assigned(LModule) then
      Continue;
    LFileName := LModule.FileName;
    if FAttachments.ContainsKey(LFileName) then
    begin
      try
        LModule.RemoveNotifier(FAttachments[LFileName].NotifierIndex);
      except
        on E: Exception do
          TLogger.Log(
            'Knowledge notifier removal failed: ' + E.Message,
            'Knowledge'
          );
      end;
    end;
    LModule := nil;
  end;
end;

procedure TRadIAOTAKnowledgeNotifier.RemoveStaleAttachments(
  const ACurrentFiles: TDictionary<string, Boolean>
);
var
  LFileName: string;
  LStaleFiles: TList<string>;
begin
  LStaleFiles := TList<string>.Create;
  try
    for LFileName in FAttachments.Keys do
      if not ACurrentFiles.ContainsKey(LFileName) then
        LStaleFiles.Add(LFileName);
    for LFileName in LStaleFiles do
      FAttachments.Remove(LFileName);
  finally
    LStaleFiles.Free;
  end;
end;

function TRadIAOTAKnowledgeNotifier.TryFindAttachment(
  const AModuleIdentity: NativeUInt;
  out AFileName: string;
  out AAttachment: TRadIAKnowledgeModuleAttachment
): Boolean;
var
  LPair: TPair<string, TRadIAKnowledgeModuleAttachment>;
begin
  AFileName := '';
  AAttachment := Default(TRadIAKnowledgeModuleAttachment);
  for LPair in FAttachments do
  begin
    if LPair.Value.ModuleIdentity = AModuleIdentity then
    begin
      AFileName := LPair.Key;
      AAttachment := LPair.Value;
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TRadIAOTAKnowledgeNotifier.TimerEvent(Sender: TObject);
begin
  if TInterlocked.CompareExchange(
    GProjectTransitionCount,
    0,
    0
  ) > 0 then
    Exit;
  if GIsShuttingDown then
  begin
    FTimer.Enabled := False;
    FScheduler.Stop;
    Exit;
  end;
  RefreshAttachments;
  FScheduler.Poll;
end;

procedure TRadIAOTAKnowledgeNotifier.Uninstall;
var
  LModuleServices: IOTAModuleServices;
begin
  if not FInstalled then
    Exit;
  FInstalled := False;
  FScheduler.Stop;
  if Assigned(FTimer) then
  begin
    FTimer.Enabled := False;
    FreeAndNil(FTimer);
  end;

  if not GIsShuttingDown and Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  ) then
    RemoveInstalledNotifiers(LModuleServices);
  FAttachments.Clear;
end;

end.
