; ---------------------------------------------------------------------------
;  SwiftIPTV - script de instalador NSIS
;  Empacota a pasta JA DEPLOYADA (build\Release) com o runtime do Qt + libmpv.
;  Gere com:  makensis installer.nsi   (a partir da pasta app\)
;  Saida:     SwiftIPTV-Setup.exe
; ---------------------------------------------------------------------------

!define APPNAME    "DIGTV+"
!define COMPANY    "DIGTV+"
!define VERSION    "1.0.0"
!define EXENAME    "SwiftIPTV.exe"
!define SRCDIR     "build\Release"

!include "MUI2.nsh"

Name "${APPNAME}"
OutFile "SwiftIPTV-Setup.exe"
Unicode True
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "Software\${APPNAME}" "InstallDir"
RequestExecutionLevel admin
ShowInstDetails show
ShowUnInstDetails show

; --- Páginas (MUI2): Welcome -> Directory -> Install -> Finish (com RUN) ---
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

; Página final com checkbox "Executar DIGTV+ agora" (marcado por padrão —
; pra definir desmarcado por default, basta definir MUI_FINISHPAGE_RUN_NOTCHECKED).
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Executar ${APPNAME} agora"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "PortugueseBR"

Section "Instalar ${APPNAME}"
    SetOutPath "$INSTDIR"

    ; Copia tudo que o windeployqt gerou (exe, DLLs do Qt, plugins, QML) + libmpv.
    File /r "${SRCDIR}\*.*"

    ; Atalhos
    CreateDirectory "$SMPROGRAMS\${APPNAME}"
    CreateShortcut  "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXENAME}"
    CreateShortcut  "$DESKTOP\${APPNAME}.lnk"               "$INSTDIR\${EXENAME}"

    ; Registro / Adicionar-Remover programas
    WriteRegStr HKLM "Software\${APPNAME}" "InstallDir" "$INSTDIR"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayName"     "${APPNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayVersion"  "${VERSION}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "Publisher"       "${COMPANY}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayIcon"     "$INSTDIR\${EXENAME}"

    WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
    Delete "$DESKTOP\${APPNAME}.lnk"
    Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
    RMDir  "$SMPROGRAMS\${APPNAME}"

    RMDir /r "$INSTDIR"

    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
    DeleteRegKey HKLM "Software\${APPNAME}"
SectionEnd
