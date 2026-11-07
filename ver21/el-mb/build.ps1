param([string]$Assembler=$env:SJASMPLUS)
$ErrorActionPreference='Stop'
if(-not $Assembler){$found=Get-Command sjasmplus -ErrorAction SilentlyContinue;if($found){$Assembler=$found.Source}elseif(Test-Path -LiteralPath 'D:\zx\Tools\SjasmPlus\sjasmplus.exe'){$Assembler='D:\zx\Tools\SjasmPlus\sjasmplus.exe'}else{throw 'Install SjASMPlus 1.20.3; set SJASMPLUS or pass -Assembler.'}}
$config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'build-config.json') -Raw|ConvertFrom-Json
$working=Join-Path $PSScriptRoot $config.directory
Push-Location $working
try{foreach($stem in $config.targets){$ext=if($stem -like 'WifiBios*'){'.a80'}else{'.asm'};& $Assembler "--lst=$stem.lst" "--sym=$stem.sym" ($stem+$ext);if($LASTEXITCODE -ne 0){throw "Assembly failed: $stem"}}}finally{Pop-Location}
$runable=Join-Path $PSScriptRoot 'runable';New-Item -ItemType Directory -Path $runable -Force|Out-Null
foreach($entry in $config.outputs){$src=Join-Path $working $entry.source;if((Get-FileHash -LiteralPath $src).Hash -ne $entry.sha256){throw "Build differs from tested release: $($entry.source)"};Copy-Item -LiteralPath $src -Destination (Join-Path $runable $entry.file)}
'PASS: rebuilt outputs match the tested release hashes.'