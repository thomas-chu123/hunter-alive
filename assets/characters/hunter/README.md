# 獵人武器 Sprite Sheets

遊戲依武器 ID 從同名目錄讀取 sprite。每套都有 `idle`（待機）、`walk`（走）、`run`（跑）、`jump`（起跳至下落）、`glide`（蜥翼滑翔）、`land`（落地）、`crouch`（蹲）、`hurt`（受傷）、`retreat`（面朝前方時的反向移動）、`climb`（蜘蛛步攀爬）和 `attack`（攻擊）。需要獨立蹲姿的武器另有 `attack_crouch`。蛛牙短刃的 `attack_2`、`attack_3` 對應連擊後兩段，也各有蹲姿版本。

每列四格，由左到右、由上到下讀取。各動作的格尺寸、腳底錨點與攻擊取幀規則由 `scripts/hunter_sprites.gd` 定義。一般移動各四幀。基本短刀、獵弓攻擊保留原四幀，其餘武器的攻擊各十六幀。

`_source/` 保留角色底圖及原始姿勢，供 Godot 的烘焙工具重製圖表。要更新整套，可先調整底圖或 `scripts/hunter_weapon_art.gd` 的握點與姿勢，再用有圖形渲染器的 Godot 執行以下命令。烘焙會更新各武器目錄裡的 PNG。

```sh
godot --path . --script tools/bake_hunter_sprites.gd
godot --headless --path . --import
godot --headless --path . --script tests/hunter_sprite_library_smoke.gd
```
