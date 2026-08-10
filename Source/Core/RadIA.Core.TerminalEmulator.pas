unit RadIA.Core.TerminalEmulator;

interface

uses
  RadIA.Core.Terminal;

type
  IRadIATerminalEmulator = interface
    ['{42A2E631-F495-40F4-B98D-07C72EF879BE}']
    procedure Clear;
    procedure Feed(const AText: string);
    function GetColumns: Integer;
    function GetCursorColumn: Integer;
    function RenderSegments: TArray<TRadIATerminalTextSegment>;
    procedure Resize(const AColumns: Integer);
    property Columns: Integer read GetColumns;
    property CursorColumn: Integer read GetCursorColumn;
  end;

  TRadIATerminalEmulatorFactory = class
  public
    class function CreateNative(
      const AColumns: Integer = 120
    ): IRadIATerminalEmulator; static;
  end;

implementation

uses
  RadIA.Core.TerminalScreen;

type
  TRadIANativeTerminalEmulator = class(
    TInterfacedObject,
    IRadIATerminalEmulator
  )
  private
    FScreen: TRadIATerminalScreen;
  public
    constructor Create(const AColumns: Integer);
    destructor Destroy; override;
    procedure Clear;
    procedure Feed(const AText: string);
    function GetColumns: Integer;
    function GetCursorColumn: Integer;
    function RenderSegments: TArray<TRadIATerminalTextSegment>;
    procedure Resize(const AColumns: Integer);
  end;

{ TRadIANativeTerminalEmulator }

constructor TRadIANativeTerminalEmulator.Create(const AColumns: Integer);
begin
  inherited Create;
  FScreen := TRadIATerminalScreen.Create(AColumns);
end;

destructor TRadIANativeTerminalEmulator.Destroy;
begin
  FScreen.Free;
  inherited Destroy;
end;

procedure TRadIANativeTerminalEmulator.Clear;
begin
  FScreen.Clear;
end;

procedure TRadIANativeTerminalEmulator.Feed(const AText: string);
begin
  FScreen.Feed(AText);
end;

function TRadIANativeTerminalEmulator.GetColumns: Integer;
begin
  Result := FScreen.Columns;
end;

function TRadIANativeTerminalEmulator.GetCursorColumn: Integer;
begin
  Result := FScreen.CursorColumn;
end;

function TRadIANativeTerminalEmulator.RenderSegments:
  TArray<TRadIATerminalTextSegment>;
begin
  Result := FScreen.RenderSegments;
end;

procedure TRadIANativeTerminalEmulator.Resize(const AColumns: Integer);
begin
  FScreen.Resize(AColumns);
end;

{ TRadIATerminalEmulatorFactory }

class function TRadIATerminalEmulatorFactory.CreateNative(
  const AColumns: Integer
): IRadIATerminalEmulator;
begin
  Result := TRadIANativeTerminalEmulator.Create(AColumns);
end;

end.
