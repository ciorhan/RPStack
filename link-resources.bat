@echo off
echo Creating junctions for RPStack resources...

set SERVER=C:\RedMServer\FrontierHegemony\resources
set REPO=C:\dev\RPStack\resources

for /d %%R in ("%REPO%\rpstack-*") do (
    set "NAME=%%~nxR"
    if exist "%SERVER%\%%~nxR" (
        echo SKIP: %%~nxR already linked or exists
    ) else (
        mklink /J "%SERVER%\%%~nxR" "%%R"
    )
)

echo Done.
pause