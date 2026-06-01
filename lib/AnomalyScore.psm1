Set-StrictMode -Version Latest

$script:AnomalyWeights = [ordered]@{
    DiffShare       = 5
    DiffLoan        = 5
    DiffReserve     = 5
    NonMember       = 5
    Underage        = 4
    RecentNewLoan   = 4
    RateError       = 3
    Type2Active     = 3
    RelatedParty    = 3
    LPNonClaim      = 2
    SameAddrMul     = 2
    NewJoinLoan     = 2
    HasBalance      = 1
    RecentTxnPerHit = 1
    OverdueCap      = 4
}

function Get-MemberValue {
    param(
        [hashtable] $Hash,
        [string] $Key,
        $Default = 0
    )
    if ($Hash.ContainsKey($Key)) {
        $v = $Hash[$Key]
        if ($null -eq $v) { return $Default }
        return $v
    }
    return $Default
}

function Get-AnomalyScore {
    param(
        [Parameter(Mandatory)] [hashtable] $Member
    )

    $lgrShare   = [double](Get-MemberValue $Member 'LGR_Share')
    $serShare   = [double](Get-MemberValue $Member 'SER_Share')
    $lgrLoan    = [double](Get-MemberValue $Member 'LGR_Loan')
    $serLoan    = [double](Get-MemberValue $Member 'SER_Loan')
    $lgrReserve = [double](Get-MemberValue $Member 'LGR_Reserve')
    $serReserve = [double](Get-MemberValue $Member 'SER_Reserve')

    $diffShare   = $lgrShare   - $serShare
    $diffLoan    = $lgrLoan    - $serLoan
    $diffReserve = $lgrReserve - $serReserve

    $score = 0
    $flags = New-Object System.Collections.Generic.List[string]

    if ($diffShare -ne 0) {
        $score += $script:AnomalyWeights.DiffShare
        $flags.Add(('股金差{0}' -f $diffShare)) | Out-Null
    }
    if ($diffLoan -ne 0) {
        $score += $script:AnomalyWeights.DiffLoan
        $flags.Add(('貸款差{0}' -f $diffLoan)) | Out-Null
    }
    if ($diffReserve -ne 0) {
        $score += $script:AnomalyWeights.DiffReserve
        $flags.Add(('備轉差{0}' -f $diffReserve)) | Out-Null
    }

    $badLoans  = [int](Get-MemberValue $Member 'BadLoanCount')
    $totOwebr  = [double](Get-MemberValue $Member 'TotOWEBR')
    $totOweint = [double](Get-MemberValue $Member 'TotOWEINT')
    if ($badLoans -gt 0) {
        $overdueScore = [Math]::Min(
            $script:AnomalyWeights.OverdueCap,
            [Math]::Ceiling($totOwebr / 50000)
        )
        if ($overdueScore -lt 0) { $overdueScore = 0 }
        $score += [int]$overdueScore
        $flags.Add(('逾期{0}筆(本{1}/息{2})' -f $badLoans, $totOwebr, $totOweint)) | Out-Null
    }

    if ([bool](Get-MemberValue $Member 'IsNonMember' $false)) {
        $score += $script:AnomalyWeights.NonMember
        $flags.Add('非社員貸款') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasUnderageLoan' $false)) {
        $score += $script:AnomalyWeights.Underage
        $flags.Add('未成年貸款(<18)') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasRecentNewLoan' $false)) {
        $score += $script:AnomalyWeights.RecentNewLoan
        $flags.Add('查核期間新增貸款') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasRateDiscrepancy' $false)) {
        $score += $script:AnomalyWeights.RateError
        $flags.Add('利率與費率不符') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasLPNonClaimLoan' $false)) {
        $score += $script:AnomalyWeights.LPNonClaim
        $flags.Add('LP非出險貸款') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasSameAddressMultiple' $false)) {
        $score += $script:AnomalyWeights.SameAddrMul
        $flags.Add('同地址多戶貸款(>=3)') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasType2Activity' $false)) {
        $score += $script:AnomalyWeights.Type2Active
        $flags.Add('非正規社員活動') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasRelatedPartyLoan' $false)) {
        $score += $script:AnomalyWeights.RelatedParty
        $flags.Add('關係人放款(同GRPNO)') | Out-Null
    }
    if ([bool](Get-MemberValue $Member 'HasNewJoinLoan' $false)) {
        $score += $script:AnomalyWeights.NewJoinLoan
        $flags.Add('新入社立即貸款') | Out-Null
    }

    $recentTxn = [int](Get-MemberValue $Member 'RecentTxn')
    if ($recentTxn -gt 0) {
        $score += $script:AnomalyWeights.RecentTxnPerHit
        $flags.Add(('近期交易{0}筆' -f $recentTxn)) | Out-Null
    }

    $hasBalance = ($lgrShare -ne 0) -or ($lgrLoan -ne 0) -or ($lgrReserve -ne 0)
    if ($hasBalance) {
        $score += $script:AnomalyWeights.HasBalance
    }

    return [PSCustomObject]@{
        Score       = $score
        Flags       = $flags.ToArray()
        Flags_cn    = ($flags -join '; ')
        DiffShare   = $diffShare
        DiffLoan    = $diffLoan
        DiffReserve = $diffReserve
    }
}

function Get-ScoreCategory {
    param([int]$Score)

    if ($Score -ge 10) { return 'High' }
    if ($Score -ge 5)  { return 'Mid'  }
    if ($Score -gt 0)  { return 'Low'  }
    return 'None'
}

function Test-AnomalyShouldInclude {
    param([int]$Score)
    return $Score -gt 0
}

function Get-TopPercentCount {
    param(
        [Parameter(Mandatory)] [int] $Total,
        [Parameter(Mandatory)] [int] $Percent
    )

    if ($Total -le 0) { return 0 }
    if ($Percent -lt 1 -or $Percent -gt 100) {
        throw "Percent must be between 1 and 100 (got $Percent)"
    }
    return [Math]::Max(1, [int]($Total * $Percent / 100))
}

function Get-ResultCsvName {
    param(
        [string] $Prefix = 'CUB_異常社員_對帳單排序_',
        [datetime] $When = (Get-Date)
    )
    $ts = $When.ToString('yyyyMMdd_HHmmss')
    return "$Prefix$ts.csv"
}

function Get-AnomalyWeights {
    $copy = [ordered]@{}
    foreach ($k in $script:AnomalyWeights.Keys) {
        $copy[$k] = $script:AnomalyWeights[$k]
    }
    return $copy
}

Export-ModuleMember -Function @(
    'Get-AnomalyScore'
    'Get-ScoreCategory'
    'Test-AnomalyShouldInclude'
    'Get-TopPercentCount'
    'Get-ResultCsvName'
    'Get-AnomalyWeights'
)
