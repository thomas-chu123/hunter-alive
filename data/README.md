# 遊戲設定資料

| 檔案 | 內容 |
|---|---|
| `characters/monsters.json` | 以怪物 ID 對應生命、移動、攻擊、受擊、音效、姿勢檔、碰撞框與遭遇提示。 |
| `characters/monster_loot.json` | 以怪物 ID 對應擊倒與繳械的掉落、隨機武器防具的掉落機率，以及任務物品設定。 |
| `characters/monster_rules.json` | 共用移動、攻擊節奏、預設碰撞框及姿勢圖尺寸。 |
| `campaign/stage_change.json` | 主選單、陷阱測試場，以及各區入口與依順序排列的關卡場景。 |
| `dialogue/villagers.dialogue` | 各區村民對話。 |
| `campaign/campaign.json` | 四區的 ID、名稱、頭目等級加成與倍率、關卡寬度、出生偏移、鏡頭、環境光及火盆間距。 |
| `characters/hunter.json` | 獵人移動、體力與法力、動作時間及異常狀態。 |
| `equipment/equipment.json` | 初始武器、道具與防具的欄位、圖示、說明、武器數值、投射物、符印判定及裝備效果。 |
| `equipment/progression.json` | 等級與品階上限、品階顏色、費用、容量、回收與減傷。 |
| `audio/music.json` | 依區域 ID 指定探索及頭目曲目，另含標題、最終階段曲目與淡入淡出設定。 |
| `audio/sound.json` | 怪物腳步與攻擊、陷阱音檔、武器合成音色及各類音量與音高。 |
| `traps/traps.json` | 陷阱週期、傷害、落石、火球、爆炸、毒霧及傳送門參數。 |
| `campaign/rewards.json` | 營火贈裝、各區石匣裝備、共用石匣素材數量。 |
| `campaign/stage_rules.json` | 各場景的環境亮度、共用互動距離，以及關卡的水位、地板崩落、石栓與遭遇條件。 |
| `effects/effects.json` | 元素與格擋顏色、受擊停頓、鏡頭震動、斬擊與火花時間，以及各種命中事件的效果組合。 |

修改後重新啟動遊戲。時間使用秒，距離使用像素，音量使用 dB。向量使用 `[x, y]`。裝備說明為顯示文字，變更效果數值時請一併更新說明。品階顏色以品階為索引，第 0 格保留；提高上限時也要補齊顏色。

區域陣列的順序對應存檔的數字編號，既有區域應保留順序及 ID。音樂以相同區域 ID 連結。`final_boss` 可填入最終階段的音檔路徑，留空會延續當區頭目曲目。陷阱場景透過 `cycle_profile` 選擇週期，每個實例可在 Inspector 將 `cycle_seconds` 設為正值覆寫。地形、怪物與道具的位置由 TileMap 編輯。

調整弓箭或火球時，從裝備的 `projectile` 找到同檔 `projectiles` 的對應項目；速度乘上壽命為無碰撞時的射程。`scribe_staff.glyph.hitbox` 使用相對於符印落點的 `[x, y, 寬, 高]`。石匣的區域鍵沿用戰役 ID，裝備清單填入裝備 ID，每筆清單的 ID 應唯一。

單一區域可在 `campaign/campaign.json` 的區域項目加入 `presentation`，只填要覆寫的欄位。單一物種可在 `characters/monsters.json` 加入 `motion_rules` 覆寫 `characters/monster_rules.json` 的移動規則。密室規則位於 `campaign/stage_rules.json` 的 `stages.ruins_1`。

戰役入口與關卡各有一個 `ambient_brightness`。在 `campaign/stage_rules.json` 的 `stages` 下，以場景檔名（省略 `.tscn`）找到設定。例：`ruins` 是入口，`ruins_2` 是第二關。設為 20 可讓密林更暗，設為 75 可讓開闊地更亮。

- **1** 接近全暗，**33** 保留戰役或區域原有的環境光，**100** 讓環境光調色達到純白。
- 缺少設定或填入非數值時使用 33。超出範圍的數值取最近的端點。
- 亮度會套用至場景和視差背景。HUD 使用獨立畫布。

`effects/effects.json` 的事件依序播放各層：`wave` 為震波、`burst` 為光芒、`scar` 為斬痕、`flash` 為全螢幕閃光。每層的 `duration` 使用正秒數；`color` 使用 0 到 1 的 RGBA，省略時繼承觸發事件的顏色。

怪物的 `characters/monsters.json` 內 `level` 與 `health` 是各物種的基礎數值。`characters/monster_rules.json` 的 `tiers` 定義五階與外框色；每升一階加 5 級、10 HP。頭目在品階加成後套用區域頭目加成。怪物掉出的裝備沿用品階，魂與素材維持原規則。`characters/monster_loot.json` 的 `random_equipment.chance` 控制額外隨機裝備掉率，預設 38.75%。

在 Godot 的 `Landscape > Monster` 圖層，於 TileMap 面板選擇「預設、鐵、銅、銀、金」來源，再選物種並繪製。來源 0 對應原有的 1 階圖塊。五個來源共用物種場景與縮圖，遊戲中才會顯示品階外框。金蜘蛛為 Lv.21／HP 45，掉出裝備即為 5 階。

在 Godot 選取關卡的 `Landscape > Monster`，用 TileMap 面板新增、移動或擦除怪物。遭遇提示以圖塊上的出生位置為準。載入存檔時，若 `defeat_flag` 已成立，該怪物會略過生成。

要放大個別怪物，在 Monster 圖層的 TileMap 面板選「巨型」，再從全部 21 種巨型版本中選擇物種。巨型圖塊的外觀為 1.5 倍，等同金色 5 階怪物的 HP、等級、金色外框及掉落規則。要新增其他巨型圖塊，可從原物種的場景建立繼承場景，保留 `monster_species`，加入數值型的 `monster_scale` metadata，再把場景加入 Monster TileSet 的場景集合。場景的 `Sprite2D.scale` 控制編輯器預覽大小。

要調整整個物種，在 `characters/monsters.json` 的物種條目加入 `"scale": 1.5`，與 `health` 同層。遊戲優先採用圖塊的有效倍率，其次採用物種倍率，最後預設為 1.0。倍率須為有限正數，只縮放角色動畫。頭目動畫會再乘上區域的 `boss.size`。

擊倒和繳械分別讀取 `defeat`、`disarm`。掉落條目可設定 `item`、`amount`、`chance`、`offset` 與取得限制。機率使用 0 到 1。`materials` 可覆蓋一般素材規則，填 `null` 時該怪物略過一般素材掉落。

四區場景分別位於 `scenes/ruins/`、`scenes/flooded_corridor/`、`scenes/buried_court/` 與 `scenes/volcanic_caldera/`。主選單位於 `scenes/title/`。存檔保留既有區域編號與進度旗標。

```sh
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script tests/game/config_tables_test.gd
godot --headless --path . --fixed-fps 60 --script tests/game/stage_rules_test.gd
```

`campaign/stage_change.json` 的 `regions` 以戰役區域 ID 為鍵。`entry` 對應存檔的第 0 關，`stages` 的第一筆對應第 1 關。出口依序前往同區下一關或下一區首關。各區清單應包含戰役設定的關卡數。更名或移動場景時可更新對應路徑，既有存檔依區域與關卡編號定位。Godot 啟動場景仍由 `project.godot` 的 `run/main_scene` 指定，若移動標題場景須一併更新。
