@echo off
echo Creating junctions for RPStack resources...

set SERVER=C:\RedMServer\FrontierHegemony\resources
set REPO=C:\dev\RPStack\resources
set TESTS=C:\dev\RPStack\tests

for /d %%R in ("%REPO%\rpstack-*") do (
    set "NAME=%%~nxR"
    if exist "%SERVER%\%%~nxR" (
        echo SKIP: %%~nxR already linked or exists
    ) else (
        mklink /J "%SERVER%\%%~nxR" "%%R"
    )
)

set "SMOKE_LINK=%SERVER%\rpstack-factions-smoke"
set "SMOKE_TARGET=%TESTS%\rpstack-factions-smoke"

rem The smoke resource lives under tests but keeps its FXServer resource name.
rem Remove only an existing reparse point; never replace a real directory.
fsutil reparsepoint query "%SMOKE_LINK%" >nul 2>&1
if not errorlevel 1 (
    echo UPDATE: rpstack-factions-smoke junction
    rmdir "%SMOKE_LINK%"
)

if exist "%SMOKE_LINK%" (
    echo ERROR: %SMOKE_LINK% exists and is not a junction
) else (
    mklink /J "%SMOKE_LINK%" "%SMOKE_TARGET%"
)

echo Done.
pause
