@ECHO OFF

rem Convert (load) 1C data processor or report from 1C:Designer XML format to binary format (*.epf, *.erf)
rem %1 - path to main file of 1C data processor or report in 1C:Designer XML format (*.xml)
rem %2 - path to folder to save data processor & report in binary format
rem %3 - path to 1C configuration (binary (*.cf), 1C:Designer XML format or 1C:EDT format)
rem      or folder contains 1C infobase used for convertion

IF not defined V8_VERSION set V8_VERSION=8.3.20.2290
IF not defined V8_TEMP set V8_TEMP=%TEMP%\1c

set V8_TOOL="C:\Program Files\1cv8\%V8_VERSION%\bin\1cv8.exe"

set IB_PATH=%V8_TEMP%\tmp_db

set DP_FILE=%1
IF defined DP_FILE set DP_FILE=%DP_FILE:"=%
set DP_PATH=%2
IF defined DP_PATH set DP_PATH=%DP_PATH:"=%
set BASE_CONFIG=%3
IF defined BASE_CONFIG set BASE_CONFIG=%BASE_CONFIG:"=%

IF not defined DP_FILE (
    echo Missed parameter 1 "path to main file of 1C data processor or report in 1C:Designer XML format (*.xml)"
    exit /b 1
)
IF not defined DP_PATH (
    echo Missed parameter 2 "path to folder to save data processor & report in binary format"
    exit /b 1
)
IF not exist "%BASE_CONFIG%" (
    echo Path "%BASE_CONFIG%" doesn't exist ^(parameter 3^), empty infobase will be used.
    set BASE_CONFIG=
)

echo Clear temporary files...
IF exist "%V8_TEMP%" rd /S /Q "%V8_TEMP%"
md "%V8_TEMP%"
IF not exist "%DP_PATH%" md "%DP_PATH%"

echo Set infobase for import data processor/report...
IF "%BASE_CONFIG%" equ "" (
    echo Creating infobase "%IB_PATH%"...
    md "%IB_PATH%"
    set BASE_CONFIG_DESCRIPTION=empty configuration
    %V8_TOOL% CREATEINFOBASE File=%IB_PATH%; /DisableStartupDialogs
) ELSE (
    set BASE_CONFIG_DESCRIPTION=configuration from "%BASE_CONFIG%"
    IF exist "%BASE_CONFIG%\DT-INF\" (
        md "%IB_PATH%"
        call %~dp0edt2ib.cmd "%BASE_CONFIG%" "%IB_PATH%"
    ) ELSE (
        IF exist "%BASE_CONFIG%\Configuration.xml" (
            md "%IB_PATH%"
            call %~dp0xml2ib.cmd "%BASE_CONFIG%" "%IB_PATH%"
        ) ELSE (
            IF exist "%BASE_CONFIG%\1cv8.1cd" (
                set BASE_CONFIG_DESCRIPTION=existed configuration
                set IB_PATH=%BASE_CONFIG%
            ) ELSE (
                md "%IB_PATH%"
                call %~dp0cf2ib.cmd "%BASE_CONFIG%" "%IB_PATH%"
            )
        )
    )
)

echo Import dataprocessor / report "%DP_FILE%" to 1C:Designer format "%DP_PATH%" using infobase "%IB_PATH%" with %BASE_CONFIG_DESCRIPTION%...
%V8_TOOL% DESIGNER /IBConnectionString File="%IB_PATH%"; /DisableStartupDialogs /LoadExternalDataProcessorOrReportFromFiles "%DP_FILE%" "%DP_PATH%"

echo Clear temporary files...
IF exist "%V8_TEMP%" rd /S /Q "%V8_TEMP%"
