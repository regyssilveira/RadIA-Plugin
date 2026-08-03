unit RadIA.Core.Designer;

interface

type
  TRadIAComponentPropertyValue = record
  private
    FName: string;
    FTypeName: string;
    FValue: string;
  public
    constructor Create(
      const AName: string;
      const ATypeName: string;
      const AValue: string
    );
    function Equals(
      const AOther: TRadIAComponentPropertyValue
    ): Boolean;
    property Name: string read FName;
    property TypeName: string read FTypeName;
    property Value: string read FValue;
  end;

  TRadIAComponentBounds = record
  private
    FHeight: Integer;
    FLeft: Integer;
    FTop: Integer;
    FWidth: Integer;
  public
    constructor Create(
      const ALeft: Integer;
      const ATop: Integer;
      const AWidth: Integer;
      const AHeight: Integer
    );
    function Equals(
      const AOther: TRadIAComponentBounds
    ): Boolean;
    property Left: Integer read FLeft;
    property Top: Integer read FTop;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

  TRadIAFormSnapshot = record
  private
    FAvailable: Boolean;
    FClassName: string;
    FComponentCount: Integer;
    FFormFileName: string;
    FName: string;
    FSelectionCount: Integer;
    FUnitFileName: string;
  public
    constructor Create(
      const AAvailable: Boolean;
      const AName: string;
      const AClassName: string;
      const AUnitFileName: string;
      const AFormFileName: string;
      const AComponentCount: Integer;
      const ASelectionCount: Integer
    );
    property Available: Boolean read FAvailable;
    property Name: string read FName;
    property ClassName: string read FClassName;
    property UnitFileName: string read FUnitFileName;
    property FormFileName: string read FFormFileName;
    property ComponentCount: Integer read FComponentCount;
    property SelectionCount: Integer read FSelectionCount;
  end;

  TRadIAFormComponentSnapshot = record
  private
    FClassName: string;
    FHeight: Integer;
    FIsControl: Boolean;
    FLeft: Integer;
    FName: string;
    FParentName: string;
    FSelected: Boolean;
    FTop: Integer;
    FWidth: Integer;
  public
    constructor Create(
      const AName: string;
      const AClassName: string;
      const AParentName: string;
      const AIsControl: Boolean;
      const ASelected: Boolean;
      const ALeft: Integer;
      const ATop: Integer
    );
    procedure SetSize(
      const AWidth: Integer;
      const AHeight: Integer
    );
    property Name: string read FName;
    property ClassName: string read FClassName;
    property ParentName: string read FParentName;
    property IsControl: Boolean read FIsControl;
    property Selected: Boolean read FSelected;
    property Left: Integer read FLeft;
    property Top: Integer read FTop;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

  IRadIAFormDesignerFacade = interface
    ['{1F96C5A2-3C30-41CB-8897-5866A3DDA91D}']
    function GetActiveForm: TRadIAFormSnapshot;
    function ListFormComponents(
      const AMaxCount: Integer
    ): TArray<TRadIAFormComponentSnapshot>;
  end;

  IRadIAFormDesignerMutationFacade = interface
    ['{129262BB-DBCF-42E5-8479-4F0752066C02}']
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
  end;

  IRadIAFormDesignerComponentFacade = interface
    ['{C4BA8DD9-BE15-44A5-9854-5D84989FD5CB}']
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
  end;

implementation

{ TRadIAComponentPropertyValue }

constructor TRadIAComponentPropertyValue.Create(
  const AName: string;
  const ATypeName: string;
  const AValue: string
);
begin
  FName := AName;
  FTypeName := ATypeName;
  FValue := AValue;
end;

function TRadIAComponentPropertyValue.Equals(
  const AOther: TRadIAComponentPropertyValue
): Boolean;
begin
  Result := (FName = AOther.Name) and
    (FTypeName = AOther.TypeName) and
    (FValue = AOther.Value);
end;

{ TRadIAComponentBounds }

constructor TRadIAComponentBounds.Create(
  const ALeft: Integer;
  const ATop: Integer;
  const AWidth: Integer;
  const AHeight: Integer
);
begin
  FLeft := ALeft;
  FTop := ATop;
  FWidth := AWidth;
  FHeight := AHeight;
end;

function TRadIAComponentBounds.Equals(
  const AOther: TRadIAComponentBounds
): Boolean;
begin
  Result := (FLeft = AOther.Left) and
    (FTop = AOther.Top) and
    (FWidth = AOther.Width) and
    (FHeight = AOther.Height);
end;

{ TRadIAFormSnapshot }

constructor TRadIAFormSnapshot.Create(
  const AAvailable: Boolean;
  const AName: string;
  const AClassName: string;
  const AUnitFileName: string;
  const AFormFileName: string;
  const AComponentCount: Integer;
  const ASelectionCount: Integer
);
begin
  FAvailable := AAvailable;
  FName := AName;
  FClassName := AClassName;
  FUnitFileName := AUnitFileName;
  FFormFileName := AFormFileName;
  FComponentCount := AComponentCount;
  FSelectionCount := ASelectionCount;
end;

{ TRadIAFormComponentSnapshot }

constructor TRadIAFormComponentSnapshot.Create(
  const AName: string;
  const AClassName: string;
  const AParentName: string;
  const AIsControl: Boolean;
  const ASelected: Boolean;
  const ALeft: Integer;
  const ATop: Integer
);
begin
  FName := AName;
  FClassName := AClassName;
  FParentName := AParentName;
  FIsControl := AIsControl;
  FSelected := ASelected;
  FLeft := ALeft;
  FTop := ATop;
  FWidth := 0;
  FHeight := 0;
end;

procedure TRadIAFormComponentSnapshot.SetSize(
  const AWidth: Integer;
  const AHeight: Integer
);
begin
  FWidth := AWidth;
  FHeight := AHeight;
end;

end.
