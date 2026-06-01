# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 執行工具

```powershell
# 執行異常社員偵測（需 CUB.MDB 在同目錄）
.\find_anomaly_members.ps1
.\find_anomaly_members.ps1 -CubPath D:\CUB.MDB -CubPassword <密碼>

# 依百分比篩選（需先執行上面產生 CSV）
.\filter_by_percent.ps1
.\filter_by_percent.ps1 -Percent 30 -CubPassword <密碼>
```

## 執行測試

```powershell
# 執行所有測試（需先安裝 Pester）
.\run_tests.ps1

# 安裝 Pester（若尚未安裝）
Install-Module Pester -Force

# 執行單一測試檔
Invoke-Pester .\tests\AnomalyScore.Tests.ps1
Invoke-Pester .\tests\Smoke.Tests.ps1
```

## 架構

工具分三層：

**`對帳單.bat`** — 使用者入口，呼叫下方兩個 PS1 腳本，以 Big5 (CP950) 編碼儲存。編輯此檔時必須用能保留 Big5 位元組的方式寫入，否則中文會損壞（詳見下方編碼注意事項）。

**`find_anomaly_members.ps1`** — 主要偵測引擎。流程：
1. 互動詢問 CUB.MDB 密碼（若未以參數傳入）
2. 自動偵測 DAO 是否需要切換至 32-bit PowerShell（`SysWOW64`）
3. 逐步從 CUB.MDB 的 `SER`、`LGR`、`BOROW`、`RATE` 等資料表讀取資料
4. 呼叫 `Get-AnomalyScore`（來自模組）計算每位社員分數
5. 輸出排序後的 CSV（`CUB_異常社員_對帳單排序_YYYYMMDD_HHmmss.csv`）
6. 將結果寫入 CUB.MDB 的 `M_對帳明細` 資料表（若不存在則自動建立）

**`filter_by_percent.ps1`** — 二次篩選。讀取上一步產生的 CSV，依百分比保留分數最高的前 N% 社員，並從 `M_對帳明細` 刪除未入選的記錄。

**`lib/AnomalyScore.psm1`** — 純邏輯模組（無 I/O、無 DAO），匯出 6 個函式：
- `Get-AnomalyScore` — 核心評分，輸入社員 hashtable，回傳 Score + Flags
- `Get-ScoreCategory` — 分類（High ≥10, Mid 5-9, Low 1-4）
- `Get-TopPercentCount` — 計算前 N% 對應筆數
- `Get-ResultCsvName` — 產生帶時間戳的 CSV 檔名
- `Get-AnomalyWeights` — 回傳權重表複本
- `Test-AnomalyShouldInclude` — 判斷是否列入輸出

**`tests/`** — Pester 測試：
- `AnomalyScore.Tests.ps1` — 單元測試，覆蓋所有模組函式（50 個案例）
- `Smoke.Tests.ps1` — 結構測試，驗證腳本 AST 語法與關鍵函式呼叫（20 個案例）

## 異常偵測指標與分數

| 指標 | 分數 |
|------|------|
| LGR vs SER 股金/貸款/備轉差異 | 各 +5 |
| 非社員貸款 | +5 |
| 未成年貸款（<18歲）| +4 |
| 查核期間新增貸款 | +4 |
| 逾期貸款（依本金 ÷50000 計算，上限 4）| 最高 +4 |
| 利率與費率不符 | +3 |
| 非正規社員活動（TYPE=2）| +3 |
| 關係人放款（同 GRPNO）| +3 |
| LP 非出險貸款 | +2 |
| 同地址多戶（≥3）| +2 |
| 新入社立即貸款 | +2 |
| 近期交易 | +1 |
| 有 LGR 餘額 | +1 |

## 資料庫相依性

- 需要 **Microsoft Access Database Engine 2016**（DAO.DBEngine.120）
- 若 64-bit PowerShell 無法初始化 DAO，腳本會自動重啟為 32-bit（`SysWOW64`）
- CUB.MDB 以密碼保護，連線字串格式：`;PWD=<密碼>`
- `.mdb` 和輸出 `.csv` 均列於 `.gitignore`，不進版控

## 編碼注意事項

**`對帳單.bat` 以 Big5 (CP950) 儲存**，這是唯一使用此編碼的檔案，其餘所有 `.ps1` 為 UTF-8。

編輯 `.bat` 時，**不可用文字編輯器直接儲存**，否則 Big5 位元組會被轉為 UTF-8 替代字元（`EF BF BD`）且無法還原。正確做法：以 Latin-1（iso-8859-1）讀取位元組、修改 ASCII 部分、再以相同編碼寫回。範例：

```powershell
$latin1 = [System.Text.Encoding]::GetEncoding("iso-8859-1")
$bytes = [System.IO.File]::ReadAllBytes("對帳單.bat")
$content = $latin1.GetString($bytes)
$content = $content -replace '要替換的ASCII文字', '新文字'
[System.IO.File]::WriteAllBytes("對帳單.bat", $latin1.GetBytes($content))
```
