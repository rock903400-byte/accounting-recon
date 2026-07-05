# accounting-recon

![CI](https://github.com/rock903400-byte/accounting-recon/actions/workflows/ci.yml/badge.svg)

> 對帳單異常社員偵測工具 — PowerShell 開源版

## 功能

- **異常分數評估**：針對股金、貸款差異、關係人放款等指標進行自動評分。
- **指標視覺化說明**：內置 `異常社員偵測指標說明.html` 提供圖形化指標與說明。
- **完整的測試**：提供基於 Pester 的單元與整合測試用例。

## 使用方式

```bash
# 執行 Pester 測試
powershell -File run_tests.ps1
# 執行對帳單分析
.\對帳單.bat
```

## 環境需求

- Windows PowerShell 5.1+ / Pester 測試模組

## License

MIT
