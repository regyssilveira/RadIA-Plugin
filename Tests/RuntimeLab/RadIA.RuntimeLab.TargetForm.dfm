object RadIARuntimeLabTargetForm: TRadIARuntimeLabTargetForm
  Left = 0
  Top = 0
  Caption = 'Runtime failure target'
  ClientHeight = 150
  ClientWidth = 360
  OnShow = FormShow
  Position = poOwnerFormCenter
  object lblScenario: TLabel
    Left = 24
    Top = 24
    Width = 312
    Height = 30
    AutoSize = False
    Caption = 'Cancel this modal form to trigger the reference failure.'
    WordWrap = True
  end
  object btnCancel: TButton
    Left = 112
    Top = 80
    Width = 136
    Height = 40
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 0
    OnClick = btnCancelClick
  end
end
