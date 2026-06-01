$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
Import-Module (Join-Path $root 'lib\AnomalyScore.psm1') -Force

Describe 'Get-AnomalyScore' {
    Context '會員資料無任何異常' {
        It '應回傳 Score=0, Flags 空' {
            $m = @{
                ACCNO='A001'
                LGR_Share=0; SER_Share=0
                LGR_Loan=0;  SER_Loan=0
                LGR_Reserve=0; SER_Reserve=0
                BadLoanCount=0; TotOWEBR=0; TotOWEINT=0
                IsNonMember=$false; HasUnderageLoan=$false
                HasRecentNewLoan=$false; HasRateDiscrepancy=$false
                HasLPNonClaimLoan=$false; HasSameAddressMultiple=$false
                HasType2Activity=$false; HasRelatedPartyLoan=$false
                HasNewJoinLoan=$false; RecentTxn=0
            }
            $r = Get-AnomalyScore -Member $m
            $r.Score | Should Be 0
            $r.Flags.Count | Should Be 0
        }
    }

    Context 'LGR vs SER 差異檢測' {
        It '股金差 100 應 +5 分 (LGR!=0 再 +1 hasBalance = 6)' {
            $m = @{ LGR_Share=1100; SER_Share=1000; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 6
        }
        It '貸款差 50 應 +5 分 (LGR!=0 再 +1 hasBalance = 6)' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=50000; SER_Loan=49950; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 6
        }
        It '備轉差 200 應 +5 分 (LGR!=0 再 +1 hasBalance = 6)' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=200; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 6
        }
        It '三項都有差應 +15 分 (有 LGR 餘額, +1 hasBalance = 16)' {
            $m = @{ LGR_Share=100; SER_Share=0; LGR_Loan=200; SER_Loan=0; LGR_Reserve=300; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 16
        }
        It '負向差異 (-100) 仍應 +5 分 (LGR 全 0, 無 hasBalance = 5)' {
            $m = @{ LGR_Share=0; SER_Share=100; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 5
        }
    }

    Context '逾期貸款權重計算' {
        It '1 筆逾期、本 30000 應 +1 分' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=1; TotOWEBR=30000; TotOWEINT=500; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 1
        }
        It '1 筆逾期、本 100000 應 +2 分 (ceil(100000/50000))' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=1; TotOWEBR=100000; TotOWEINT=1000; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 2
        }
        It '本 1000000 應被 cap 在 4 分' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=2; TotOWEBR=1000000; TotOWEINT=99999; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 4
        }
    }

    Context '布林異常旗標' {
        It 'IsNonMember 應 +5' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; IsNonMember=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 5
        }
        It 'HasUnderageLoan 應 +4' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasUnderageLoan=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 4
        }
        It 'HasRecentNewLoan 應 +4' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasRecentNewLoan=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 4
        }
        It 'HasRateDiscrepancy 應 +3' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasRateDiscrepancy=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 3
        }
        It 'HasLPNonClaimLoan 應 +2' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasLPNonClaimLoan=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 2
        }
        It 'HasSameAddressMultiple 應 +2' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasSameAddressMultiple=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 2
        }
        It 'HasType2Activity 應 +3' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasType2Activity=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 3
        }
        It 'HasRelatedPartyLoan 應 +3' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasRelatedPartyLoan=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 3
        }
        It 'HasNewJoinLoan 應 +2' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; HasNewJoinLoan=$true; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 2
        }
    }

    Context '近期交易' {
        It 'RecentTxn=1 應 +1' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; RecentTxn=1 }
            (Get-AnomalyScore -Member $m).Score | Should Be 1
        }
        It 'RecentTxn=10 仍只 +1 (per call)' {
            $m = @{ LGR_Share=0; SER_Share=0; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; RecentTxn=10 }
            (Get-AnomalyScore -Member $m).Score | Should Be 1
        }
    }

    Context '邊界' {
        It '缺欄位應視為 0, 不拋例外' {
            $m = @{}
            { Get-AnomalyScore -Member $m } | Should Not Throw
            (Get-AnomalyScore -Member $m).Score | Should Be 0
        }
        It 'null 值應視為 0' {
            $m = @{ LGR_Share=$null; SER_Share=$null; LGR_Loan=$null; SER_Loan=$null; LGR_Reserve=$null; SER_Reserve=$null; BadLoanCount=$null; TotOWEBR=$null; TotOWEINT=$null; RecentTxn=$null }
            (Get-AnomalyScore -Member $m).Score | Should Be 0
        }
        It '有 LGR 餘額但無異常旗標應 +1 (hasBalance)' {
            $m = @{ LGR_Share=100; SER_Share=100; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Score | Should Be 1
        }
    }

    Context '回傳物件結構' {
        It '應含 Score, Flags, Flags_cn, DiffShare/DiffLoan/DiffReserve' {
            $m = @{ LGR_Share=1100; SER_Share=1000; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            $r = Get-AnomalyScore -Member $m
            $r.PSObject.Properties.Name | Should Be @('Score','Flags','Flags_cn','DiffShare','DiffLoan','DiffReserve')
        }
        It 'Flags_cn 應以 "; " 串接' {
            $m = @{ LGR_Share=100; SER_Share=0; LGR_Loan=200; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; BadLoanCount=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).Flags_cn | Should Be '股金差100; 貸款差200'
        }
        It 'DiffShare 應正確回傳 (LGR-SER)' {
            $m = @{ LGR_Share=1234.5; SER_Share=1000; LGR_Loan=0; SER_Loan=0; LGR_Reserve=0; SER_Reserve=0; RecentTxn=0 }
            (Get-AnomalyScore -Member $m).DiffShare | Should Be 234.5
        }
    }
}

Describe 'Get-ScoreCategory' {
    It 'score=0 → None' { Get-ScoreCategory -Score 0   | Should Be 'None' }
    It 'score=1 → Low'  { Get-ScoreCategory -Score 1   | Should Be 'Low'  }
    It 'score=4 → Low'  { Get-ScoreCategory -Score 4   | Should Be 'Low'  }
    It 'score=5 → Mid'  { Get-ScoreCategory -Score 5   | Should Be 'Mid'  }
    It 'score=9 → Mid'  { Get-ScoreCategory -Score 9   | Should Be 'Mid'  }
    It 'score=10 → High'{ Get-ScoreCategory -Score 10  | Should Be 'High' }
    It 'score=99 → High'{ Get-ScoreCategory -Score 99  | Should Be 'High' }
}

Describe 'Test-AnomalyShouldInclude' {
    It 'score=0 不應列入' { Test-AnomalyShouldInclude -Score 0 | Should Be $false }
    It 'score=1 應列入'   { Test-AnomalyShouldInclude -Score 1 | Should Be $true  }
    It 'score=10 應列入'  { Test-AnomalyShouldInclude -Score 10| Should Be $true  }
}

Describe 'Get-TopPercentCount' {
    It '100 人取 30% 應為 30' { Get-TopPercentCount -Total 100 -Percent 30 | Should Be 30 }
    It '10 人取 50% 應為 5'   { Get-TopPercentCount -Total 10  -Percent 50 | Should Be 5  }
    It '3 人取 50% (1.5) 經 PowerShell 四捨五入為 2' { Get-TopPercentCount -Total 3 -Percent 50 | Should Be 2 }
    It '1 人取 1% (0.01) 應為 1 (最小值)' { Get-TopPercentCount -Total 1 -Percent 1 | Should Be 1 }
    It '100% 應等於總人數'    { Get-TopPercentCount -Total 100 -Percent 100 | Should Be 100 }
    It 'Total=0 應為 0'        { Get-TopPercentCount -Total 0   -Percent 50 | Should Be 0 }
    It 'Percent=0 應拋例外'    { { Get-TopPercentCount -Total 100 -Percent 0 } | Should Throw }
    It 'Percent=101 應拋例外'  { { Get-TopPercentCount -Total 100 -Percent 101 } | Should Throw }
    It 'Percent=-1 應拋例外'   { { Get-TopPercentCount -Total 100 -Percent -1 } | Should Throw }
}

Describe 'Get-ResultCsvName' {
    It '應使用指定時間戳' {
        Get-ResultCsvName -When (Get-Date '2026-06-01 12:34:56') | Should Be 'CUB_異常社員_對帳單排序_20260601_123456.csv'
    }
    It '預設 prefix 應為異常社員排序' {
        (Get-ResultCsvName -When (Get-Date '2026-01-01 00:00:00')) -match '^CUB_異常社員_對帳單排序_\d{8}_\d{6}\.csv$' | Should Be $true
    }
    It '可自訂 prefix' {
        Get-ResultCsvName -Prefix 'X_' -When (Get-Date '2026-06-01 12:34:56') | Should Be 'X_20260601_123456.csv'
    }
}

Describe 'Get-AnomalyWeights' {
    It '應回傳有序權重表 (clone, 不污染原表)' {
        $w = Get-AnomalyWeights
        $w.DiffShare | Should Be 5
        $w.NonMember | Should Be 5
        $w.Underage  | Should Be 4
    }
    It '修改回傳值不應影響模組' {
        $w = Get-AnomalyWeights
        $w.DiffShare = 999
        (Get-AnomalyWeights).DiffShare | Should Be 5
    }
}
