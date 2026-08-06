object RadIARuntimeLabMainForm: TRadIARuntimeLabMainForm
  Left = 0
  Top = 0
  Caption = 'RadIA Runtime Automation Laboratory'
  ClientHeight = 180
  ClientWidth = 460
  Position = poScreenCenter
  object lblInstructions: TLabel
    Left = 24
    Top = 24
    Width = 412
    Height = 30
    AutoSize = False
    Caption = 'Choose a deterministic Access Violation scenario.'
    WordWrap = True
  end
  object btnFailOnOpen: TButton
    Left = 24
    Top = 88
    Width = 185
    Height = 40
    Caption = 'Fail when form opens'
    TabOrder = 0
    OnClick = btnFailOnOpenClick
  end
  object btnFailOnCancel: TButton
    Left = 248
    Top = 88
    Width = 185
    Height = 40
    Caption = 'Fail when form cancels'
    TabOrder = 1
    OnClick = btnFailOnCancelClick
  end
end
