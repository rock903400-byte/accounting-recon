param(
    [switch] $Detailed,
    [string] $Tag
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Get-Module -ListAvailable Pester)) {
    Write-Host "需要 Pester，請先安裝: Install-Module Pester -Force" -ForegroundColor Red
    exit 2
}

$testsDir = Join-Path (Get-Location) 'tests'
if (-not (Test-Path $testsDir)) {
    Write-Host "找不到 tests 目錄" -ForegroundColor Red
    exit 2
}

$libPath = Join-Path (Get-Location) 'lib\AnomalyScore.psm1'
if (-not (Test-Path $libPath)) {
    Write-Host "找不到 lib\AnomalyScore.psm1" -ForegroundColor Red
    exit 2
}

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  對帳單工具 — 自動測試" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ("  Pester:    {0}" -f (Get-Module -ListAvailable Pester | Select-Object -First 1).Version) -ForegroundColor DarkGray
Write-Host ("  PSVersion: {0}" -f $PSVersionTable.PSVersion) -ForegroundColor DarkGray
Write-Host ("  TestsDir:  {0}" -f $testsDir) -ForegroundColor DarkGray
Write-Host ""

$files = Get-ChildItem -Path $testsDir -Filter '*.Tests.ps1' | Sort-Object Name
if ($files.Count -eq 0) {
    Write-Host "沒有找到 .Tests.ps1 檔案" -ForegroundColor Yellow
    exit 1
}

$totalPassed = 0
$totalFailed = 0
$totalSkipped = 0
$failedFiles = @()

foreach ($f in $files) {
    Write-Host "▶ $($f.Name)" -ForegroundColor Yellow

    $params = @{
        Script = $f.FullName
    }
    if ($Detailed) { $params.EnableExit = $false }

    $result = Invoke-Pester @params -PassThru 2>$null

    if ($result) {
        $totalPassed  += $result.PassedCount
        $totalFailed  += $result.FailedCount
        $totalSkipped += $result.SkippedCount
        if ($result.FailedCount -gt 0) { $failedFiles += $f.Name }
    }
    Write-Host ""
}

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ("  總計: Passed={0}  Failed={1}  Skipped={2}" -f $totalPassed, $totalFailed, $totalSkipped) -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($totalFailed -gt 0) {
    Write-Host ""
    Write-Host "失敗檔案:" -ForegroundColor Red
    $failedFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

exit 0
