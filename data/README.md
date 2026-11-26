# 遊戲設定資料

| 檔案 | 內容 |
|---|---|
| `monsters.json` | 以怪物 ID 對應生命、移動、攻擊、受擊、音效、姿勢檔、碰撞框與遭遇提示。 |
| `monster_loot.json` | 以怪物 ID 對應擊倒與繳械的掉落、隨機武器防具的品階機率，以及任務物品設定。 |
| `monster_rules.json` | 共用移動、攻擊節奏、預設碰撞框及姿勢圖尺寸。 |
| `campaign.json` | 四區的 ID、名稱、入口、頭目等級加成與倍率、關卡寬度、出生偏移、鏡頭、環境光及火盆間距。 |
| `hunter.json` | 獵人移動、體力與法力、動作時間及異常狀態。 |
| `equipment.json` | 初始武器、道具與防具的欄位、圖示、說明、武器數值、投射物、符印判定及裝備效果。 |
| `progression.json` | 等級與品階上限、品階顏色、費用、容量、回收與減傷。 |
| `music.json` | 依區域 ID 指定探索及頭目曲目，另含標題、最終階段曲目與淡入淡出設定。 |
| `sound.json` | 怪物腳步與攻擊、陷阱音檔、武器合成音色及各類音量與音高。 |
| `traps.json` | 陷阱週期、傷害、落石、火球、爆炸、毒霧及傳送門參數。 |
| `rewards.json` | 營火贈裝、各區石匣裝備、共用石匣素材數量。 |
| `stage_rules.json` | 共用互動距離與各關的水位、地板崩落、石栓及遭遇條件。 |
| `effects.json` | 元素與格擋顏色、受擊停頓、鏡頭震動、斬擊與火花時間，以及各種命中事件的效果組合。 |

修改後重新啟動遊戲。時間使用秒，距離使用像素，音量使用 dB。向量使用 `[x, y]`。裝備說明為顯示文字，變更效果數值時請一併更新說明。品階顏色以品階為索引，第 0 格保留；提高上限時也要補齊顏色。

區域陣列的順序對應存檔的數字編號，既有區域應保留順序及 ID。音樂以相同區域 ID 連結。`final_boss` 可填入最終階段的音檔路徑，留空會延續當區頭目曲目。陷阱場景透過 `cycle_profile` 選擇週期，每個實例可在 Inspector 將 `cycle_seconds` 設為正值覆寫。地形、怪物與道具的位置由 TileMap 編輯。

調整弓箭或火球時，從裝備的 `projectile` 找到同檔 `projectiles` 的對應項目；速度乘上壽命為無碰撞時的射程。`scribe_staff.glyph.hitbox` 使用相對於符印落點的 `[x, y, 寬, 高]`。石匣的區域鍵沿用戰役 ID，裝備清單填入裝備 ID，每筆清單的 ID 應唯一。

單一區域可在 `campaign.json` 的區域項目加入 `presentation`，只填要覆寫的欄位。單一物種可在 `monsters.json` 加入 `motion_rules` 覆寫 `monster_rules.json` 的移動規則。密室規則位於 `stage_rules.json` 的 `stages.ruins_1`。

`effects.json` 的事件依序播放各層：`wave` 為震波、`burst` 為光芒、`scar` 為斬痕、`flash` 為全螢幕閃光。每層的 `duration` 使用正秒數；`color` 使用 0 到 1 的 RGBA，省略時繼承觸發事件的顏色。

在 Godot 選取關卡的 `Landscape > Monster`，用 TileMap 面板新增、移動或擦除怪物。遭遇提示以圖塊上的出生位置為準。載入存檔時，若 `defeat_flag` 已成立，該怪物會略過生成。

擊倒和繳械分別讀取 `defeat`、`disarm`。掉落條目可設定 `item`、`amount`、`chance`、`offset` 與取得限制。機率使用 0 到 1。`materials` 可覆蓋一般素材規則，填 `null` 時該怪物略過一般素材掉落。

四區場景分別位於 `scenes/ruins/`、`scenes/flooded_corridor/`、`scenes/buried_court/` 與 `scenes/volcanic_caldera/`。主選單位於 `scenes/title/`。存檔保留既有區域編號與進度旗標。

```sh
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script tests/game/config_tables_test.gd
godot --headless --path . --fixed-fps 60 --script tests/game/stage_rules_test.gd
```
