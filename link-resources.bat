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

rem Smoke resources live under tests but keep their FXServer resource names.
rem The peer is part of the bridge smoke (second resource for cross-resource checks).
rem Remove only an existing reparse point; never replace a real directory.
for %%S in (rpstack-vorp-bridge-smoke rpstack-vorp-bridge-smoke-peer) do (
    fsutil reparsepoint query "%SERVER%\%%S" >nul 2>&1
    if not errorlevel 1 (
        echo UPDATE: %%S junction
        rmdir "%SERVER%\%%S"
    )
    if exist "%SERVER%\%%S" (
        echo ERROR: %SERVER%\%%S exists and is not a junction
    ) else (
        mklink /J "%SERVER%\%%S" "%TESTS%\%%S"
    )
)

echo Done.
pause
