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

## 室內圖塊與攀爬道具

- 在 `Terrain` 共用 TileSet 的筆刷選擇 `Interior Surfaces`、`Interior Fixtures`，或從「圖樣」蓋印整組牆面、地板和擺設。要把擺設疊在牆面上，可在牆面上方加一個使用同一 TileSet 的 TileMapLayer。室內圖塊只繪製背景，實體地板仍需鋪有碰撞的地形圖塊。
- 選取牆面上方的圖層，從 `Interior Lighting` 或「圖樣」放置 `Wall lantern` 與 `Hanging chandelier`。每格都包含動畫火焰與暖色光源，可直接用 TileMap 複製或移除。
- 在 `Props` 圖層選擇 `Traversal`，將圖塊原點放在下層地板線。木樓梯向右上升 80 px，上端承接平台的地板線位於原點右方 60 px。繩索和梯子長 120 px，可在同一垂直線每隔六格接續放置。上端留出可側移到平台的空間。
- 靠近繩索或梯子時，按 W／↑ 上爬、S／↓ 下爬。放開上下鍵會停在原處，左右鍵或空白鍵可離開。樓梯用左右鍵行走。
