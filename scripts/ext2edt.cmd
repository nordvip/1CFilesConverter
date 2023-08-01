@rem ----------------------------------------------------------
@rem This Source Code Form is subject to the terms of the
@rem Mozilla Public License, v.2.0. If a copy of the MPL
@rem was not distributed with this file, You can obtain one
@rem at http://mozilla.org/MPL/2.0/.
@rem ----------------------------------------------------------
@rem Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
@rem ----------------------------------------------------------

@ECHO OFF

SETLOCAL

set CONVERT_VERSION=UNKNOWN
IF exist "..\VERSION" FOR /F "usebackq tokens=* delims=" %%i IN ("..\VERSION") DO set CONVERT_VERSION=%%i
echo 1C files converter v.%CONVERT_VERSION%
echo ===
echo Convert 1C configuration extension to 1C:EDT project

set ERROR_CODE=0

IF not defined V8_VERSION set V8_VERSION=8.3.20.2290
IF not defined V8_TEMP set V8_TEMP=%TEMP%\1c

IF not "%V8_CONVERT_TOOL%" equ "designer" IF not "%V8_CONVERT_TOOL%" equ "ibcmd" set V8_CONVERT_TOOL=designer
set V8_TOOL="C:\Program Files\1cv8\%V8_VERSION%\bin\1cv8.exe"
set IBCMD_TOOL="C:\Program Files\1cv8\%V8_VERSION%\bin\ibcmd.exe"
IF not defined V8_RING_TOOL (
    FOR /F "usebackq tokens=1 delims=" %%i IN (`where ring`) DO (
        set V8_RING_TOOL="%%i"
    )
)

set LOCAL_TEMP=%V8_TEMP%\%~n0
set IB_PATH=%LOCAL_TEMP%\tmp_db
set XML_PATH=%LOCAL_TEMP%\tmp_xml
set WS_PATH=%LOCAL_TEMP%\edt_ws

set ARG=%1
IF defined ARG set ARG=%ARG:"=%
IF "%ARG%" neq "" set V8_SRC_PATH=%ARG%
set ARG=%2
IF defined ARG set ARG=%ARG:"=%
IF "%ARG%" neq "" set V8_DST_PATH=%ARG%
set ARG=%3
IF defined ARG set ARG=%ARG:"=%
IF "%ARG%" neq "" set V8_EXT_NAME=%ARG%
set ARG=%4
IF defined ARG set ARG=%ARG:"=%
IF "%ARG%" neq "" set V8_BASE_CONFIG=%ARG%

IF not defined V8_SRC_PATH (
    echo [ERROR] Missed parameter 1 - "path to folder contains 1C extension binary file (*.cfe) or in 1C:Designer XML format"
    set ERROR_CODE=1
) ELSE (
    IF not exist "%V8_SRC_PATH%" (
        echo [ERROR] Path "%V8_SRC_PATH%" doesn't exist ^(parameter 1^).
        set ERROR_CODE=1
    )
)
IF not defined V8_DST_PATH (
    echo [ERROR] Missed parameter 2 - "path to folder to save configuration extension in 1C:EDT project format"
    set ERROR_CODE=1
)
IF not defined V8_EXT_NAME (
    echo [ERROR] Missed parameter 3 - "configuration extension name"
    set ERROR_CODE=1
)
IF not exist "%V8_BASE_CONFIG%" (
    echo [INFO] Path "%V8_BASE_CONFIG%" doesn't exist ^(parameter 4^), empty infobase will be used.
    set V8_BASE_CONFIG=
)
IF %ERROR_CODE% neq 0 (
    echo ===
    echo [ERROR] Input parameters error. Expected:
    echo     %%1 - path to folder contains 1C extension binary file ^(*.cfe^) or in 1C:Designer XML format
    echo     %%2 - path to folder to save configuration extension in 1C:EDT project format
    echo     %%3 - configuration extension name
    echo     %%4 - ^(optional^) path to 1C configuration ^(binary ^(*.cf^), 1C:Designer XML format or 1C:EDT project^)
    echo           or folder contains 1C infobase used for convertion
    echo.
    exit /b %ERROR_CODE%
)

echo [INFO] Clear temporary files...
IF exist "%LOCAL_TEMP%" rd /S /Q "%LOCAL_TEMP%"
md "%LOCAL_TEMP%"
IF exist "%V8_DST_PATH%" rd /S /Q "%V8_DST_PATH%"
md %V8_DST_PATH%

echo [INFO] Set infobase for export data processor/report...

set V8_BASE_CONFIG_DESCRIPTION=configuration from "%V8_BASE_CONFIG%"

IF "%V8_BASE_CONFIG%" equ "" (
    md "%IB_PATH%"
    echo [INFO] Creating infobase "%IB_PATH%"...
    set V8_BASE_CONFIG_DESCRIPTION=empty configuration
    %V8_TOOL% CREATEINFOBASE File=%IB_PATH%; /DisableStartupDialogs
    goto export
)
IF exist "%V8_BASE_CONFIG%\1cv8.1cd" (
    echo [INFO] Basic config source type: Infobase
    set V8_BASE_CONFIG_DESCRIPTION=existed configuration
    set IB_PATH=%V8_BASE_CONFIG%
    goto export
)
md "%IB_PATH%"
call %~dp0conf2ib.cmd "%V8_BASE_CONFIG%" "%IB_PATH%"
IF ERRORLEVEL 0 goto export

echo [ERROR] Error cheking type of basic configuration "%V8_BASE_CONFIG%"!
echo Infobase, configuration file ^(*.cf^), 1C:Designer XML, 1C:EDT project or no configuration expected.
exit /b 1

:export

echo [INFO] Checking 1C extension source type...

IF /i "%V8_SRC_PATH:~-4%" equ ".cfe" (
    echo [INFO] Source type: Configuration extension file ^(CFE^)
    goto export_cfe
)
IF exist "%V8_SRC_PATH%\Configuration.xml" (
    FOR /F "delims=" %%t IN ('findstr /r /i "<objectBelonging>" "%V8_SRC_PATH%\Configuration.xml"') DO (
        echo [INFO] Source type: 1C:Designer XML files
        set XML_PATH=%V8_SRC_PATH%
        goto export_xml
    )
)

echo [ERROR] Wrong path "%V8_SRC_PATH%"!
echo Configuration extension binary ^(*.cfe^) or folder containing configuration extension in 1C:Designer XML format expected.
exit /b 1

:export_cfe

echo [INFO] Loading configuration extension from file "%V8_SRC_PATH%" to infobase "%IB_PATH%"...

IF "%V8_CONVERT_TOOL%" equ "designer" (
    %V8_TOOL% DESIGNER /IBConnectionString File=%IB_PATH%; /DisableStartupDialogs /LoadCfg %V8_SRC_PATH% -Extension %V8_EXT_NAME%
) ELSE (
    %IBCMD_TOOL% infobase config load --db-path="%IB_PATH%" --extension=%V8_EXT_NAME% "%V8_SRC_PATH%"
)

echo [INFO] Export configuration extension from infobase "%IB_PATH%" to 1C:Designer XML format "%XML_PATH%"...

md %XML_PATH%

IF "%V8_CONVERT_TOOL%" equ "designer" (
    %V8_TOOL% DESIGNER /IBConnectionString File="%IB_PATH%"; /DisableStartupDialogs /DumpConfigToFiles "%XML_PATH%" -Extension %V8_EXT_NAME% -force
) ELSE (
    %IBCMD_TOOL% infobase config export --db-path="%IB_PATH%" --extension=%V8_EXT_NAME% --force "%XML_PATH%"
)

:export_xml

echo [INFO] Export configuration extension from 1C:Designer XML format "%XML_PATH%" to 1C:EDT format "%V8_DST_PATH%"...

md %WS_PATH%

call %V8_RING_TOOL% edt workspace import --project "%V8_DST_PATH%" --configuration-files "%XML_PATH%" --workspace-location "%WS_PATH%" --version "%V8_VERSION%"

echo [INFO] Clear temporary files...
IF exist "%LOCAL_TEMP%" rd /S /Q "%LOCAL_TEMP%"
