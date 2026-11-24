# 陷阱圖塊

從主選單選 **陷阱試煉**。用 A／D 移動、空白鍵跳躍、S 蹲下、R 回到起點，Esc 返回主選單。

- 在四個主線關卡或陷阱試煉選取 `Landscape/Traps`，即可用 **TileMap → Tiles** 繪製陷阱。新關卡也可實例化 `trap_tilemap.tscn`。陷阱格為 20 × 20 px。天花板型以懸掛點為格心。牆面型以發射口為格心。可噴發的熔岩陷阱、電擊和傳送門的格心對齊地板頂面。讓飛行路徑避開發射端的實體牆面，並將滾石孔洞放在地板上方約 20 px。
- **Environment Effects** 包含原有的 180、240 和 280 px 寬熔岩與光暈圖塊。火山熔爐的對應碰撞圖塊在 `ObstacleProps`。
- 左側圖塊向右發射，右側圖塊向左發射。固定門 A 尋找同一 Trap 圖層上最近且有空間站立的 B。隨機門使用同一圖層的 RandomLanding 格，請把落點標在有地板且遠離陷阱的位置。
- 週期從關卡開始、獵人可行動時起算。下降針刺固定每 5 秒啟動。試煉場左右牆刺分別每 3.0、3.6 秒啟動，毒霧每 4.1 秒啟動。

## ImageGen 素材

`trap_atlas.png` 使用內建 ImageGen 生成的透明底圖，再裁切成 16 格。熔岩噴發和電弧各有兩個圖像幀，其他圖塊使用位移、旋轉、縮放或淡出來呈現動態。

> Use case: stylized-concept. Asset type: a single 4 columns by 4 rows sprite atlas for a side-view Godot dark fantasy platformer. Absolutely uniform cells, center each isolated sprite at the exact center of its cell, generous transparent gutters, full alpha background, no grid lines, words, numbers, ground shadows or decoration outside cells. Detailed crisp hand-painted pixel art, cold basalt stone and weathered bronze with legible warm highlights. Row 1 left to right: wide ceiling-mounted piston housing; horizontal row of downward silver spike teeth with a thin joining strip on top; square recessed wall launcher with a round black hole; heavy swung mace head with a short eyelet on top. Row 2: wide thin horizontal bubbling lava pool; narrow upright orange lava geyser with hot base; horizontally flying orange fireball oriented to the right; round orange explosion. Row 3: sideways pointed green poison cloud; round rough dark stone boulder; vertical bronze arch portal with blue energy; same arch with violet energy. Row 4: horizontal floor electrode plate; branching electric cyan lightning arcs forming an upright oval; second frame of the same narrow upright orange lava geyser with a slightly different plume; second frame of the branching cyan lightning with different branches. Exact 4-by-4 layout, keep all items fully isolated, transparent negative space between them.
