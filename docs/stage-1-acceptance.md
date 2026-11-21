# Stage 1 三區流程與驗收

## 三區主線

```text
崩塌神殿 · 6 種怪物
營火 → 翼獸台取得蜥翼 → 守門庭擊倒樹靈 → 回營火補給
    → 用蜥翼越過西側斷橋 → 西門
    ↓
淹沒的迴廊 · 7 種怪物
水閘前營火 → 繳械提燈石蟹 → 取得潮火提燈 → 穿過暗水道 → 排水出口
    ↓
埋碑內庭 · 7 種怪物及 1 名最終首領
外庭營火 → 穿過門廊與王座外階 → 主祭壇擊倒古門封印者 → 結局
```

三個區域用營火保存進度。蜥翼和潮火提燈是主線必經道具，取得必須可重試，且不得依賴隨機掉落。裝備與武器的拾取方式見 [首發內容清冊](stage-1-content.md)。Stage 1 的 Windows 原型到神殿西門顯示完成畫面為止，後兩區與選單由後續階段交付。

## 選單流程草圖

```text
啟動 → 開始頁面
  新遊戲 → 首次進入神殿營火
  繼續   → 讀取上次營火與配裝 · 無存檔時停用
  設定   → 音量、顯示設定 → 返回開始頁面
  離開   → 關閉遊戲

遊戲中 → 裝備頁
  欄位列表  武器／頭部／身體／手部／腿部
  物品列表  目前欄位可用的已取得物品
  詳細區    已裝備標記／效果／穿戴或卸下
  返回     關閉裝備頁並繼續遊戲
```

選取欄位後進入對應物品列表，套用配裝後立即更新詳細區。營火保存目前配裝。從開始頁面選新遊戲時，已有存檔的情況先確認是否覆蓋。

## 首發最低測試規格

暫定 Windows 11 x64、Intel Core i3-8100 與 Intel UHD 630 或同級、8 GB RAM、鍵盤，使用 Godot Compatibility 渲染器。以 1280×720 視窗完成原型流程，目標一般場景達 60 FPS，戰鬥與滑翔片段的第 95 百分位畫面耗時不超過 25 ms。記錄 OS 版本、CPU／GPU、驅動版本、RAM、解析度、建置編號與量測方式，實測後再定為商店最低規格。

## 驗收矩陣

| 項目 | 操作 | 通過證據 |
|---|---|---|
| 清冊與流程 | 核對各區 ID、數量、位置及驗收欄，對照兩頁選單草圖。 | 一般怪物 6／7／7，另 1 名首領。20 件裝備，10 種武器含魔法杖。 |
| Windows 匯出 | 用 Godot 4.7.2 與相符模板匯出 Windows Desktop。 | 匯出日誌、可解壓 ZIP、x64 PE 執行檔、PCK 與 SHA-256。 |
| 原型啟動 | 在未安裝 Godot 的 Windows x64 電腦解壓 ZIP，保持 EXE、PCK 同目錄並執行 `HunterAlive.exe`。 | 錄下啟動、神殿畫面與可操作角色，記錄機器規格。 |
| 神殿通關 | 用 A／D 移動、Space 跳躍、J 攻擊、Q 切換短刀／獵弓。擊敗滑翔蜥蜴並靠近撿魂，用 F 裝備蜥翼。擊敗樹靈後回到營火西側斷崖，向左助跑跳躍並按住 Shift 滑翔，落地後靠近石門按 E。 | 同一段實機錄影能看見撿魂與裝備、樹靈敗北、越橋與過關畫面。 |
| 失敗後重試 | 優先驗證一次摔入斷橋下方，於營火重生後再過橋。另在樹靈仍存活時試開石門。 | 死亡重生後路線可重試，樹靈存活時石門會阻擋過關。 |
| 效能 | 在暫定測試規格下量測首次啟動、一般移動、敵人戰鬥、滑翔四段。 | 留存畫面時間紀錄、FPS、硬體配置及設定。 |
| Steamworks | 由發行帳號持有人登入、完成資料驗證並處理 App 費用。 | 記錄 Partner 登記或 App 建立狀態，驗收紀錄使用可公開資訊。 [Steam Direct](https://partner.steamgames.com/steamdirect) |

## 重現匯出及原型測試

使用 Godot `4.7.2.stable.official.ed1daf0bf`，以 Godot 的模板管理工具安裝 `4.7.2.stable` 模板，或把官方 TPZ 中的 `templates/windows_release_x86_64.exe` 放入 Linux 的 `${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable/`。 [Godot 4.7.2 下載](https://godotengine.org/download/archive/4.7.2-stable/) · [Godot 匯出命令](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html)

在專案根目錄執行，將 `godot` 換成實際的 4.7.2 指令或路徑。

```bash
mkdir -p dist/windows
godot --headless --path "$PWD" --import
godot --headless --path "$PWD" --export-release "Windows Desktop" \
  "$PWD/dist/windows/HunterAlive.exe" --log-file "$PWD/dist/stage-1-export.log"
godot --headless --path "$PWD" --script tests/stage_1_smoke.gd
repo_dir="$PWD"
(cd /tmp && godot --headless --main-pack "$repo_dir/dist/windows/HunterAlive.pck" \
  --script "$repo_dir/tests/stage_1_smoke.gd")
```

Smoke 測試使用程式設定敵人的受擊與繳械狀態，滑翔則走實際輸入和物理。來源版本與 Windows 匯出的 PCK 都應通過 8 個檢查。Windows 啟動、手動操作與效能以原生 Windows 實測驗收。
