# 場景環境素材

環境素材以用途和場景歸檔。專用素材放在與 `scenes/<場景名>.tscn` 同名的目錄。兩個以上場景引用的素材集中在 `common/`。

| 路徑 | 內容 |
|---|---|
| `buried_court/` | 埋碑內庭專用背景 |
| `flooded_corridor/` | 淹沒的迴廊專用背景 |
| `common/backdrops/` | 主選單與崩塌神殿共用的背景 |
| `common/props/` | 營火、斷柱、蕨類、石門與石匣的圖檔、場景及四類物件 TileSet |
| `common/traps/` | [陷阱 TileSet、TileMap、圖集與編輯方式](common/traps/README.md) |
| `common/terrain/` | 四個關卡共用的地形 TileSet 與遊戲使用的圖集 |
| `common/terrain/source/` | 保留供美術編修的石材、踏台原圖與舊版圖集 |

個別場景新增專用素材時，可在這裡建立同名目錄。搬移已匯入的 PNG 時要保留其 `.png.import` 對應檔，以延續 Godot 的資源 UID。


## 在 TileMap 編輯物件

四個關卡都在 `Landscape` 使用下列圖層，每個圖層各自綁定一個 TileSet。

| 圖層 | TileSet | 適合放置 |
|---|---|---|
| `Props` | `props_tileset.tres` | 營火、一般石匣、出口拱門、前景柱或蕨類。武器與防具寶箱分別從 **Weapons** 與 **Armor** 選取。 |
| `BackgroundProps` | `background_props_tileset.tres` | 用來構圖的背景斷柱、黑曜石柱和蕨類。 |
| `ObstacleProps` | `obstacle_props_tileset.tres` | 迴廊提燈石閘、內庭碰撞柱、火山熔岩碰撞區。 |
| `Traps` | `trap_tileset.tres` | 陷阱、傳送門，以及熔岩和光暈等環境效果。 |

1. 在場景樹選取圖層，再從下方 **TileMap → Tiles** 選來源與圖塊。
2. 用 TileMap 選取工具框選後移動、複製或貼到另一關卡的同類圖層。各圖層的格子為 20 × 20 px。
3. 要新增圖塊，在 **TileSet → 圖塊來源** 選分類，從檔案系統將新 `.tscn` 拖到場景清單。新增同類圖層時，可指定對應 TileSet 並加入 `prop_tiles` 群組。

武器和防具寶箱場景分別在 `assets/items/weapon/chests/` 和 `assets/items/armor/chests/`。

營火與門的光效、互動位置，以及石閘與碰撞柱的碰撞形狀，都跟著物件格移動。複製同款裝備寶箱會共用該裝備的領取狀態，石匣則共用該關卡的開啟狀態。迴廊的光鎖石閘由提燈解鎖。地形在 `Landscape/Terrain` 編輯。

在火山熔爐，選取 `Landscape/Traps`，從 TileMap 的 **Environment Effects** 來源選擇 180、240 或 280 px 寬的熔岩圖塊。每個圖塊是一個包含熔岩和光暈的 .tscn，兩者會一起移動、複製或刪除。熔岩圖塊的定位點在熔岩左上角。若要調整原有的熔岩碰撞區，可在 `ObstacleProps` 移動碰撞圖塊。
