object FrameAIChat: TRadIAFrameAIChat
  Left = 0
  Top = 0
  Width = 990
  Height = 650
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 990
    Height = 44
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    Visible = False
    object lblTitle: TLabel
      Left = 40
      Top = 11
      Width = 120
      Height = 20
      Caption = 'Rad IA - AI ASSISTANT'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      Transparent = True
    end
    object btnSettings: TSpeedButton
      AlignWithMargins = True
      Left = 955
      Top = 3
      Width = 32
      Height = 38
      Hint = 'Settings'
      Align = alRight
      Caption = #9881
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI Symbol'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnSettingsClick
    end
    object btnToggleSessions: TSpeedButton
      AlignWithMargins = True
      Left = 917
      Top = 3
      Width = 32
      Height = 38
      Hint = 'History'
      Align = alRight
      Caption = #128340
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI Symbol'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnToggleSessionsClick
    end
    object btnNewSession: TSpeedButton
      AlignWithMargins = True
      Left = 879
      Top = 3
      Width = 32
      Height = 38
      Hint = 'New Conversation'
      Align = alRight
      Caption = '+'
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI Symbol'
      Font.Style = [fsBold]
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnNewSessionClick
    end
    object btnClear: TSpeedButton
      AlignWithMargins = True
      Left = 841
      Top = 3
      Width = 32
      Height = 38
      Hint = 'Clear History'
      Align = alRight
      Caption = #9851
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI Symbol'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnClearClick
    end
    object btnExport: TSpeedButton
      AlignWithMargins = True
      Left = 803
      Top = 3
      Width = 32
      Height = 38
      Hint = 'Export Conversation'
      Align = alRight
      Caption = #10515
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI Symbol'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnExportClick
    end
    object btnTemplates: TSpeedButton
      AlignWithMargins = True
      Left = 765
      Top = 3
      Width = 32
      Height = 38
      Hint = 'Prompt Templates'
      Align = alRight
      Caption = #9889
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Segoe UI Symbol'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnTemplatesClick
    end
    object btnTerminal: TSpeedButton
      AlignWithMargins = True
      Left = 727
      Top = 3
      Width = 32
      Height = 38
      Hint = 'Open Terminal'
      Align = alRight
      Caption = '>_'
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Consolas'
      Font.Style = [fsBold]
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      OnClick = btnTerminalClick
    end
  end
  object pnlInput: TPanel
    AlignWithMargins = True
    Left = 3
    Top = 507
    Width = 984
    Height = 140
    Align = alBottom
    BevelOuter = bvNone
    StyleElements = [seFont]
    TabOrder = 1
    Visible = False
    object lblContext: TLabel
      Left = 0
      Top = 0
      Width = 984
      Height = 13
      Align = alTop
      Caption = '  Ready'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ExplicitWidth = 37
    end
    object shpInputBg: TShape
      Left = 10
      Top = 46
      Width = 964
      Height = 84
      Anchors = [akLeft, akTop, akRight, akBottom]
      Shape = stRoundRect
    end
    object shpSendBg: TShape
      Left = 944
      Top = 94
      Width = 28
      Height = 28
      Anchors = [akRight, akBottom]
      Shape = stCircle
    end
    object btnSend: TSpeedButton
      Left = 944
      Top = 94
      Width = 28
      Height = 28
      Cursor = crHandPoint
      Anchors = [akRight, akBottom]
      Caption = #10148
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -14
      Font.Name = 'Segoe UI Symbol'
      Font.Style = [fsBold]
      ParentFont = False
      StyleElements = [seFont]
      OnClick = btnSendClick
    end
    object memPrompt: TMemo
      Left = 20
      Top = 54
      Width = 910
      Height = 68
      Anchors = [akLeft, akTop, akRight, akBottom]
      BorderStyle = bsNone
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssNone
      TabOrder = 0
    end
    object cbProvider: TComboBox
      Left = 10
      Top = 18
      Width = 120
      Height = 21
      Style = csDropDownList
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnChange = cbProviderChange
    end
    object cbModel: TComboBox
      Left = 138
      Top = 18
      Width = 200
      Height = 21
      Style = csDropDownList
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 2
      OnChange = cbModelChange
    end
  end
  object pnlSessions: TPanel
    Left = 0
    Top = 44
    Width = 180
    Height = 493
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 3
    Visible = False
    object pnlSessionsHeader: TPanel
      Left = 0
      Top = 0
      Width = 180
      Height = 30
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object btnRenameSession: TSpeedButton
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 24
        Height = 24
        Hint = 'Rename Conversation'
        Align = alLeft
        Caption = #9998
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -14
        Font.Name = 'Segoe UI Symbol'
        Font.Style = []
        ParentFont = False
        ParentShowHint = False
        ShowHint = True
        OnClick = btnRenameSessionClick
      end
      object btnDeleteSession: TSpeedButton
        AlignWithMargins = True
        Left = 63
        Top = 3
        Width = 24
        Height = 24
        Hint = 'Delete Conversation'
        Align = alLeft
        Caption = #57607
        Flat = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -14
        Font.Name = 'Segoe UI Symbol'
        Font.Style = []
        ParentFont = False
        ParentShowHint = False
        ShowHint = True
        OnClick = btnDeleteSessionClick
      end
    end
    object lstSessions: TListBox
      Left = 0
      Top = 30
      Width = 180
      Height = 463
      Align = alClient
      BorderStyle = bsNone
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ItemHeight = 20
      ParentFont = False
      TabOrder = 1
      OnClick = lstSessionsClick
    end
  end
  object splitterSessions: TSplitter
    Left = 180
    Top = 44
    Width = 3
    Height = 493
    Align = alLeft
    Visible = False
  end
  object pnlBrowser: TPanel
    Left = 183
    Top = 44
    Width = 807
    Height = 493
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'md'
    Filter = 'Markdown File (*.md)|*.md|HTML File (*.html)|*.html'
    Left = 150
    Top = 200
  end
end
