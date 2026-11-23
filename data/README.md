# 怪物資料

| 檔案 | 內容 |
|---|---|
| `monsters.json` | 以怪物 ID 對應生命、移動、攻擊、受擊、音效、姿勢檔、碰撞框與怪物個別行為。 |
| `monster_encounters.json` | 以場景目錄名對應怪物與出現的位置。`x` 是橫座標，`y` 可省略以沿用地板高度。 |
| `monster_loot.json` | 以怪物 ID 對應擊倒與繳械的掉落、隨機武器防具的品階機率，以及任務物品設定。 |
| `monster_rules.json` | 共用移動、攻擊節奏、預設碰撞框及姿勢圖尺寸。 |

在遭遇表調整 `x` 可改變生成位置；`skip_if` 可依已存在的關卡進度旗標跳過生成。擊倒和繳械分別讀取 `defeat`、`disarm`。掉落條目可設定 `item`、`amount`、`chance`、`offset` 與取得限制。機率使用 0 到 1。`materials` 可覆蓋一般素材規則，填 `null` 時該怪物略過一般素材掉落。

三關的場景在 `scenes/ruins/`、`scenes/flooded_corridor/`、`scenes/buried_court/`。主選單獨立在 `scenes/title/`，共享斷柱和蕨類場景在 `scenes/misc/`。存檔保留既有區域編號與進度旗標。

```sh
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script tests/monster_data_smoke.gd
```
