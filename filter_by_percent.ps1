# filter_by_percent.ps1 — 依比例挑選前 N% 異常社員
param(
    [string]$CubPassword = "",
    [int]$Percent = 0
)

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

$libPath = Join-Path $PSScriptRoot 'lib\AnomalyScore.psm1'
if (Test-Path $libPath) { Import-Module $libPath -Force -DisableNameChecking }

if ([string]::IsNullOrEmpty($CubPassword)) {
    Write-Host "════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "║   CUB.MDB 需要密碼                                          ║" -ForegroundColor Yellow
    Write-Host "║   提示: 也可用 -CubPassword <密碼> 略過此詢問                ║" -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    $secure = Read-Host -Prompt "  請輸入 CUB.MDB 密碼" -AsSecureString
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $CubPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) | Out-Null
    }
    Write-Host ""
}

# ── DAO.DBEngine 初始化（自動切換 64/32-bit）──────────────────────────
$daoAvailable = $false
try { $null = New-Object -ComObject DAO.DBEngine.120; $daoAvailable = $true } catch {}

if (-not $daoAvailable -and -not $env:DAO_RESTARTED) {
    $ps32 = "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $ps32) {
        Write-Host "  偵測到 32-bit 需求，自動切換..." -ForegroundColor Yellow
        $env:DAO_RESTARTED = '1'
        $argList = @()
        if ($Percent -gt 0) { $argList += '-Percent', $Percent }
        if ($CubPassword -ne '') { $argList += '-CubPassword', $CubPassword }
        & $ps32 -ExecutionPolicy Bypass -File "`"$PSCommandPath`"" @argList
        exit $LASTEXITCODE
    }
}

if (-not $daoAvailable) {
    Write-Host "════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "║   DAO.DBEngine 無法初始化                               ║" -ForegroundColor Red
    Write-Host "║   請安裝 Microsoft Access Database Engine 2016 (可再發行)    ║" -ForegroundColor Red
    Write-Host("║   下載: https://www.microsoft.com/download/details.aspx?id=54920") -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "`n按任意鍵結束..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Step 1: Find latest CSV
$csvFiles = Get-ChildItem "CUB_異常社員_對帳單排序_*.csv" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($csvFiles.Count -eq 0) {
    Write-Host "  找不到 CSV 檔，請先執行選項 1" -ForegroundColor Red
    exit 1
}
$latestCsv = $csvFiles[0].FullName
Write-Host "  CSV: $(Split-Path -Leaf $latestCsv)" -ForegroundColor DarkGray

# Step 2: Read CSV and get percentage
$allRows = Import-Csv $latestCsv
$total = $allRows.Count
Write-Host "  總計：$total 筆" -ForegroundColor Cyan

$percent = if ($Percent -gt 0) { $Percent } else { Read-Host "`n  請輸入比例 (1-100)" }
try {
    $pct = [int]$percent
    if ($pct -lt 1 -or $pct -gt 100) { throw "Invalid" }
} catch {
    Write-Host "  輸入無效 (1-100)" -ForegroundColor Red
    exit 1
}

$topCount = Get-TopPercentCount -Total $total -Percent $pct
$topRows = $allRows | Select-Object -First $topCount
$topAccNos = $topRows | ForEach-Object { $_.AccNo }
Write-Host "  前 $pct% : $topCount 筆" -ForegroundColor Green

# Step 3: Connect to CUB.MDB
$dbe = New-Object -ComObject DAO.DBEngine.120

$cubPath = Join-Path $PSScriptRoot "CUB.MDB"
if (-not (Test-Path $cubPath)) { Write-Host "  找不到 CUB.MDB" -ForegroundColor Red; exit 1 }
Write-Host "  CUB：$(Split-Path -Leaf $cubPath)" -ForegroundColor DarkGray

$connectStr = ";PWD=$CubPassword"
$cubDb = $dbe.OpenDatabase($cubPath, $false, $false, $connectStr)

# Step 4: Find M_對帳明細 table in CUB.MDB
$tables = @()
foreach ($t in $cubDb.TableDefs) {
    if ($t.Name -eq "M_對帳明細") {
        try {
            $rs = $cubDb.OpenRecordset("SELECT COUNT(*) FROM [$($t.Name)]")
            $cnt = $rs.Fields(0).Value
            $rs.Close()
            if ($cnt -gt 0) {
                $tables += [PSCustomObject]@{Name=$t.Name; Count=$cnt}
            }
        } catch {}
    }
}
if ($tables.Count -eq 0) {
    Write-Host "  找不到 M_對帳明細，請先執行選項 1" -ForegroundColor Red
    exit 1
}
Write-Host "  找到 $($tables.Count) 個對帳單表:" -ForegroundColor DarkGray
foreach ($tbl in $tables) {
    Write-Host "    $($tbl.Name): $($tbl.Count) 筆" -ForegroundColor DarkGray
}

# Step 5: Filter M_對帳明細 in CUB.MDB
foreach ($tbl in $tables) {
    $tableName = $tbl.Name
    Write-Host "`n  過濾 [$tableName] ..." -ForegroundColor Yellow
    
    $rs = $cubDb.OpenRecordset("SELECT 帳號 FROM [$tableName]")
    $toDelete = @()
    while (-not $rs.EOF) {
        $acc = $rs.Fields("帳號").Value
        if ($acc -notin $topAccNos) { $toDelete += $acc }
        $rs.MoveNext()
    }
    $rs.Close()
    
    if ($toDelete.Count -gt 0) {
        foreach ($acc in $toDelete) { $cubDb.Execute("DELETE FROM [$tableName] WHERE 帳號='$acc'") }
        Write-Host "  刪除 $($toDelete.Count) 筆" -ForegroundColor DarkGray
    }
    
    $rs = $cubDb.OpenRecordset("SELECT COUNT(*) FROM [$tableName]")
    Write-Host "  剩餘：$($rs.Fields(0).Value) 筆" -ForegroundColor Green
    $rs.Close()
}
$cubDb.Close()
[Runtime.InteropServices.Marshal]::ReleaseComObject($dbe) | Out-Null

Write-Host "`n  Done! Open Access and print" -ForegroundColor Green
Write-Host "  Accounts: $($topAccNos -join ', ')" -ForegroundColor Cyan
