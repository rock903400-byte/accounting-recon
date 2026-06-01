$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
$libPath = Join-Path $root 'lib\AnomalyScore.psm1'

Import-Module $libPath -Force

function Get-ScriptAst {
    param([string]$Path)
    $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$err)
    if ($err) { throw "Parse error in $Path`: line $($err[0].Extent.StartLineNumber) - $($err[0].Message)" }
    return $ast
}

function Find-FunctionCall {
    param(
        [System.Management.Automation.Language.Ast] $Ast,
        [string] $Name
    )
    $Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq $Name
    }, $true)
}

Describe 'find_anomaly_members.ps1 結構檢查' {
    BeforeAll {
        $script:findPath = Join-Path $root 'find_anomaly_members.ps1'
        $script:findAst  = Get-ScriptAst -Path $script:findPath
    }

    It '檔案存在' { Test-Path $script:findPath | Should Be $true }
    It '語法正確' { $script:findAst | Should Not Be $null }
    It '有 param 區塊' {
        $script:findAst.ParamBlock | Should Not Be $null
    }
    It '參數含 CubPath / CubPassword' {
        $names = $script:findAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }
        $names | Should Be @('CubPath','CubPassword')
    }
    It '引用了 lib\AnomalyScore.psm1' {
        $text = [System.IO.File]::ReadAllText($script:findPath)
        $text.Contains('AnomalyScore.psm1') | Should Be $true
    }
    It '呼叫 Get-AnomalyScore' {
        (Find-FunctionCall -Ast $script:findAst -Name 'Get-AnomalyScore').Count | Should BeGreaterThan 0
    }
    It '呼叫 Get-ScoreCategory' {
        (Find-FunctionCall -Ast $script:findAst -Name 'Get-ScoreCategory').Count | Should BeGreaterThan 0
    }
    It '呼叫 Get-ResultCsvName' {
        (Find-FunctionCall -Ast $script:findAst -Name 'Get-ResultCsvName').Count | Should BeGreaterThan 0
    }
    It '已移除內嵌的 score 計算 (股金差字串)' {
        $text = [System.IO.File]::ReadAllText($script:findPath)
        $text.Contains('股金差') | Should Be $false
    }
    It '含 DAO.DBEngine 初始化' {
        $text = [System.IO.File]::ReadAllText($script:findPath)
        $text.Contains('DAO.DBEngine.120') | Should Be $true
    }
}

Describe 'filter_by_percent.ps1 結構檢查' {
    BeforeAll {
        $script:fpPath = Join-Path $root 'filter_by_percent.ps1'
        $script:fpAst  = Get-ScriptAst -Path $script:fpPath
    }

    It '檔案存在' { Test-Path $script:fpPath | Should Be $true }
    It '語法正確' { $script:fpAst | Should Not Be $null }
    It '有 param 區塊' {
        $script:fpAst.ParamBlock | Should Not Be $null
    }
    It '參數含 CubPassword / Percent' {
        $names = $script:fpAst.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }
        $names | Should Be @('CubPassword','Percent')
    }
    It '引用了 lib\AnomalyScore.psm1' {
        $text = [System.IO.File]::ReadAllText($script:fpPath)
        $text.Contains('AnomalyScore.psm1') | Should Be $true
    }
    It '呼叫 Get-TopPercentCount' {
        (Find-FunctionCall -Ast $script:fpAst -Name 'Get-TopPercentCount').Count | Should BeGreaterThan 0
    }
    It '已移除內嵌的 [Math]::Max 百分比計算' {
        $text = [System.IO.File]::ReadAllText($script:fpPath)
        $text.Contains('[Math]::Max(1, [int]') | Should Be $false
    }
    It '含 M_對帳明細 字串' {
        $text = [System.IO.File]::ReadAllText($script:fpPath)
        $text.Contains('M_對帳明細') | Should Be $true
    }
}

Describe '模組與腳本整合' {
    It 'lib\AnomalyScore.psm1 載入後 6 個函式皆可用' {
        $cmd = Get-Command -Module AnomalyScore -ErrorAction SilentlyContinue
        $cmd.Count | Should Be 6
    }

    It 'find_anomaly_members.ps1 的指令碼中, Import-Module 為第一個 Import-Module 呼叫' {
        $imports = Find-FunctionCall -Ast $script:findAst -Name 'Import-Module'
        $imports.Count | Should BeGreaterThan 0
    }
}
