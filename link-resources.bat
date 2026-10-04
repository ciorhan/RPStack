@echo off
echo Creating junctions for RPStack resources...

rem VORP deployment (ADR-005). Only resources that run on VORP are linked.
rem rpstack-identity, rpstack-economy, rpstack-permissions, and rpstack-factions are not linked yet.
set SERVER=C:\RedMServer\txData\FrontierHegemony\resources
set REPO=C:\dev\RPStack\resources
set TESTS=C:\dev\RPStack\tests

for %%N in (rpstack-core rpstack-persistence rpstack-vorp-bridge) do (
    if exist "%SERVER%\%%N" (
        echo SKIP: %%N already linked or exists
    ) else (
        mklink /J "%SERVER%\%%N" "%REPO%\%%N"
    )
)

set "SMOKE_LINK=%SERVER%\rpstack-vorp-bridge-smoke"
set "SMOKE_TARGET=%TESTS%\rpstack-vorp-bridge-smoke"

rem The smoke resource lives under tests but keeps its FXServer resource name.
rem Remove only an existing reparse point; never replace a real directory.
fsutil reparsepoint query "%SMOKE_LINK%" >nul 2>&1
if not errorlevel 1 (
    echo UPDATE: rpstack-vorp-bridge-smoke junction
    rmdir "%SMOKE_LINK%"
)

if exist "%SMOKE_LINK%" (
    echo ERROR: %SMOKE_LINK% exists and is not a junction
) else (
    mklink /J "%SMOKE_LINK%" "%SMOKE_TARGET%"
)

echo Done.
pause
