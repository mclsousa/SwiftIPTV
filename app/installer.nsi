; ---------------------------------------------------------------------------
;  SwiftIPTV - script de instalador NSIS
;  Empacota a pasta JA DEPLOYADA (build\Release) com o runtime do Qt + libmpv.
;  Gere com:  makensis installer.nsi   (a partir da pasta app\)
;  Saida:     SwiftIPTV-Setup.exe
; ---------------------------------------------------------------------------

!define APPNAME    "SwiftIPTV"
!define COMPANY    "SwiftIPTV"
!define VERSION    "1.0.0"
!define EXENAME    "SwiftIPTV.exe"
!define SRCDIR     "build\Release"

Name "${APPNAME}"
OutFile "SwiftIPTV-Setup.exe"
Unicode True
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "Software\${APPNAME}" "InstallDir"
RequestExecutionLevel admin
ShowInstDetails show
ShowUnInstDetails show

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

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
