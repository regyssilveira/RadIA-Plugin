object FormAIDiff: TRadIAFormAIDiff
  Left = 0
  Top = 0
  Caption = 'Rad IA - Smart Diff'
  ClientHeight = 620
  ClientWidth = 860
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlFooter: TPanel
    Left = 0
    Top = 568
    Width = 860
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitTop = 551
    ExplicitWidth = 854
    object lblSeparator: TLabel
      Left = 0
      Top = 0
      Width = 860
      Height = 15
      Align = alTop
      ExplicitWidth = 3
    end
    object btnPrevConflict: TButton
      AlignWithMargins = True
      Left = 3
      Top = 18
      Width = 140
      Height = 31
      Hint = 'Bloco anterior com diff'
      Align = alLeft
      Caption = #8592' Previous'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      OnClick = btnPrevConflictClick
      ExplicitLeft = 149
    end
    object btnNextConflict: TButton
      AlignWithMargins = True
      Left = 149
      Top = 18
      Width = 140
      Height = 31
      Hint = 'Pr'#243'ximo bloco com diff'
      Align = alLeft
      Caption = 'Next '#8594
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnClick = btnNextConflictClick
      ExplicitLeft = 288
      ExplicitTop = 21
    end
    object btnApply: TButton
      AlignWithMargins = True
      Left = 571
      Top = 18
      Width = 140
      Height = 31
      Hint = 'Aplicar altera'#231#245'es no editor'
      Align = alRight
      Caption = #10003' Apply Changes'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI Symbol'
      Font.Style = [fsBold]
      ModalResult = 1
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 2
      ExplicitLeft = 591
    end
    object btnCancel: TButton
      AlignWithMargins = True
      Left = 717
      Top = 18
      Width = 140
      Height = 31
      Hint = 'Descartar sugest'#227'o'
      Align = alRight
      Caption = #10007' Cancel'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI Symbol'
      Font.Style = []
      ModalResult = 2
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 3
      ExplicitLeft = 727
    end
  end
  object pnlBrowser: TPanel
    Left = 0
    Top = 0
    Width = 860
    Height = 568
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitWidth = 854
    ExplicitHeight = 551
    object EdgeBrowser: TEdgeBrowser
      Left = 0
      Top = 0
      Width = 860
      Height = 568
      Align = alClient
      TabOrder = 0
      AllowSingleSignOnUsingOSPrimaryAccount = False
      TargetCompatibleBrowserVersion = '137.0.3296.44'
      UserDataFolder = '%LOCALAPPDATA%\bds.exe.WebView2'
      OnCreateWebViewCompleted = EdgeBrowserCreateWebViewCompleted
      OnNavigationCompleted = EdgeBrowserNavigationCompleted
      OnWebMessageReceived = EdgeBrowserWebMessageReceived
      ExplicitWidth = 854
      ExplicitHeight = 551
    end
  end
end
