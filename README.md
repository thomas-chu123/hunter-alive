# hunter-alive

## Godot 程式與測試

| 目錄 | 用途 |
|---|---|
| `scripts/game/` | 戰役流程、存檔、偏好設定、武器與裝備系統、角色成長 |
| `scripts/scene/` | 標題畫面、關卡控制、地形 |
| `scripts/character/` | 獵人、怪物圖鑑與行為、角色動畫與武器圖像 |
| `scripts/music/`、`scripts/sound/` | 背景音樂、武器與敵人音效 |
| `scripts/ui/`、`scripts/effects/` | 介面、命中與敵人特效 |
| `tests/game/`、`tests/scene/` | 戰役、存檔、裝備與成長，及各關卡的流程、地形與場景載入 |
| `tests/character/`、`tests/combat/` | 角色圖像、怪物資料與移動，以及武器攻擊、命中與戰鬥 |
| `tests/audio/`、`tests/ui/` | 背景音樂與音效的整合測試，以及遊戲 HUD |

從專案根目錄匯入資源，再用分類後的路徑執行測試。例如：

```sh
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script tests/character/monster_data_smoke.gd
```

`tests/audio/game_audio_smoke.gd` 需用 Godot 視窗或 `--write-movie` 執行，才會跑音訊播放檢查。
