# 獵人武器 Sprite Sheets

遊戲依武器 ID 從同名目錄讀取 4×4 圖集。每個移動動作占一列四幀，從左到右播放。

| 圖集 | 由上到下的列順序 |
| --- | --- |
| `locomotion.png` | 待機、走路、跑步、後退 |
| `traversal.png` | 跳躍、滑翔、落地、攀爬 |
| `reaction.png` | 蹲姿、受傷、第 3 列為獵弓的四幀攻擊 |

其他武器有獨立的 `attack.png`，從左到右、由上到下播放十六幀。需要獨立蹲姿的武器另有 `attack_crouch.png`。蛛牙短刃的 `attack_2`、`attack_3` 對應連擊後兩段，也各有蹲姿版本。未使用的格保留透明。格尺寸、腳底錨點與取幀規則定義在 `scripts/character/hunter_sprites.gd`。

`_source/` 保留角色底圖及原始姿勢，供 Godot 的烘焙工具重製圖表。要更新整套，可先調整底圖或 `scripts/character/hunter_weapon_art.gd` 的握點與姿勢，再用有圖形渲染器的 Godot 執行以下命令。烘焙會更新各武器目錄裡的 PNG。

```sh
godot --path . --script tools/bake_hunter_sprites.gd
godot --headless --path . --import
godot --headless --path . --script tests/character/hunter_sprite_library_smoke.gd
```

只重烘焙指定武器的攻擊圖集時，可執行 `godot --path . --script tools/bake_hunter_sprites.gd -- --attack-only hunter_knife`。
