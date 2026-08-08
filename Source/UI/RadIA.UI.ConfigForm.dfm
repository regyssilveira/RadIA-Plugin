object FormAIConfig: TRadIAFormAIConfig
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = 'Rad IA Configuration'
  ClientHeight = 520
  ClientWidth = 840
  Color = clBtnFace
  Constraints.MinHeight = 559
  Constraints.MinWidth = 856
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 15
  object splSidebar: TSplitter
    Left = 200
    Top = 0
    Height = 487
  end
  object pnlSidebar: TPanel
    Left = 0
    Top = 0
    Width = 200
    Height = 487
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object tvCategories: TTreeView
      Left = 0
      Top = 0
      Width = 200
      Height = 487
      Align = alClient
      Indent = 19
      ReadOnly = True
      ShowLines = False
      TabOrder = 0
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 487
    Width = 840
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object btnSave: TButton
      AlignWithMargins = True
      Left = 681
      Top = 3
      Width = 75
      Height = 27
      Align = alRight
      Caption = 'Save'
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnCancel: TButton
      AlignWithMargins = True
      Left = 762
      Top = 3
      Width = 75
      Height = 27
      Align = alRight
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
end
