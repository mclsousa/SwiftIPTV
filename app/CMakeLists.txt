cmake_minimum_required(VERSION 3.21)

project(SwiftIPTV VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# Windows 10 1809 (10.0.17763.0) como alvo mínimo
if(WIN32)
    add_compile_definitions(_WIN32_WINNT=0x0A00 WINVER=0x0A00 NTDDI_VERSION=0x0A000005)
endif()

# ----------------------------------------------------------------------------
# Qt 6
# ----------------------------------------------------------------------------
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui OpenGL Qml Quick Network PrintSupport Widgets)
qt_standard_project_setup(REQUIRES 6.5)

# ----------------------------------------------------------------------------
# libmpv
#   Defina MPV_ROOT (cmake -DMPV_ROOT=C:/libs/mpv) apontando para a pasta com
#   include/mpv/*.h e a lib de importação (mpv.lib / libmpv.dll.a).
# ----------------------------------------------------------------------------
set(MPV_ROOT "" CACHE PATH "Pasta raiz do libmpv para Windows")

find_path(MPV_INCLUDE_DIR
    NAMES mpv/client.h
    HINTS "${MPV_ROOT}/include" ENV MPV_ROOT
)
find_library(MPV_LIBRARY
    NAMES mpv libmpv mpv.dll
    HINTS "${MPV_ROOT}/lib" "${MPV_ROOT}" ENV MPV_ROOT
)

if(NOT MPV_INCLUDE_DIR OR NOT MPV_LIBRARY)
    message(FATAL_ERROR
        "libmpv não encontrada. Baixe os arquivos de desenvolvimento (libmpv-dev) e "
        "rode: cmake -DMPV_ROOT=C:/caminho/para/mpv .  "
        "Esperado: \${MPV_ROOT}/include/mpv/client.h e \${MPV_ROOT}/lib/mpv.lib")
endif()
message(STATUS "libmpv include: ${MPV_INCLUDE_DIR}")
message(STATUS "libmpv lib:     ${MPV_LIBRARY}")

# ----------------------------------------------------------------------------
# Fontes
# ----------------------------------------------------------------------------
set(SOURCES
    src/main.cpp

    src/core/Settings.cpp        src/core/Settings.h
    src/core/AuthManager.cpp     src/core/AuthManager.h
    src/core/ChannelManager.cpp  src/core/ChannelManager.h
    src/core/StreamPlayer.cpp    src/core/StreamPlayer.h
    src/core/M3UParser.cpp       src/core/M3UParser.h
    src/core/NetworkThread.cpp   src/core/NetworkThread.h
    src/core/EPGManager.cpp      src/core/EPGManager.h
    src/core/DnsChanger.cpp      src/core/DnsChanger.h
    src/core/DiagnosticEngine.cpp src/core/DiagnosticEngine.h
    src/core/PrefetchEngine.cpp  src/core/PrefetchEngine.h

    src/ui/LoginWindow.cpp       src/ui/LoginWindow.h
    src/ui/DnsSetupWindow.cpp    src/ui/DnsSetupWindow.h
    src/ui/MainWindow.cpp        src/ui/MainWindow.h
    src/ui/ChannelList.cpp       src/ui/ChannelList.h
    src/ui/PlayerWidget.cpp      src/ui/PlayerWidget.h
    src/ui/DiagnosticPanel.cpp   src/ui/DiagnosticPanel.h
)

qt_add_executable(SwiftIPTV WIN32 ${SOURCES})

# Manifesto: asInvoker (elevação sob demanda via ShellExecuteEx no DnsChanger)
if(MSVC)
    target_sources(SwiftIPTV PRIVATE app.manifest)
endif()

# ----------------------------------------------------------------------------
# Módulo QML
# ----------------------------------------------------------------------------
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(SwiftIPTV
    URI SwiftIPTV
    VERSION 1.0
    QML_FILES
        qml/Theme.qml
        qml/Main.qml
        qml/LoginScreen.qml
        qml/DnsSetup.qml
        qml/HomeScreen.qml
        qml/TopNav.qml
        qml/CategorySidebar.qml
        qml/LiveTV.qml
        qml/DiagnosticView.qml
    RESOURCES
        resources/icons/logo.svg
        resources/icons/mi/tv.svg
        resources/icons/mi/movie.svg
        resources/icons/mi/series.svg
        resources/icons/mi/settings.svg
        resources/icons/mi/refresh.svg
        resources/icons/mi/logout.svg
        resources/icons/mi/account.svg
        resources/icons/mi/servers.svg
        resources/logos/logo-tvdig.png
        resources/logos/logo-tvdig-square.png
        resources/patterns/hexagons.svg
)

# ----------------------------------------------------------------------------
# Includes / links
# ----------------------------------------------------------------------------
target_include_directories(SwiftIPTV PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${MPV_INCLUDE_DIR}
)

target_link_libraries(SwiftIPTV PRIVATE
    Qt6::Core Qt6::Gui Qt6::OpenGL Qt6::Qml Qt6::Quick Qt6::Network Qt6::PrintSupport Qt6::Widgets
    ${MPV_LIBRARY}
)

if(WIN32)
    target_link_libraries(SwiftIPTV PRIVATE shell32 ole32 iphlpapi ws2_32)
endif()

# ----------------------------------------------------------------------------
# Flags de otimização (Release / MSVC)
# ----------------------------------------------------------------------------
if(MSVC)
    target_compile_options(SwiftIPTV PRIVATE
        $<$<CONFIG:Release>:/O2 /arch:AVX2 /GL /GS- /fp:fast>
    )
    target_link_options(SwiftIPTV PRIVATE
        $<$<CONFIG:Release>:/LTCG /OPT:REF /OPT:ICF>
    )
endif()

# ----------------------------------------------------------------------------
# Instalador NSIS (opcional): cpack -G NSIS
# ----------------------------------------------------------------------------
install(TARGETS SwiftIPTV RUNTIME DESTINATION .)
set(CPACK_GENERATOR "NSIS")
set(CPACK_PACKAGE_NAME "SwiftIPTV")
set(CPACK_PACKAGE_VENDOR "SwiftIPTV")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "SwiftIPTV")
set(CPACK_NSIS_MODIFY_PATH OFF)
include(CPack)
