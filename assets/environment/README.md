# 場景環境素材

環境素材以用途和場景歸檔。專用素材放在與 `scenes/<場景名>.tscn` 同名的目錄。兩個以上場景引用的素材集中在 `common/`。

| 路徑 | 內容 |
|---|---|
| `buried_court/` | 埋碑內庭專用背景 |
| `flooded_corridor/` | 淹沒的迴廊專用背景 |
| `common/backdrops/` | 主選單與崩塌神殿共用的背景 |
| `common/props/` | 營火、斷柱、蕨類、石門與石匣的圖檔、場景及共用物件 TileSet |
| `common/terrain/` | 四個關卡共用的地形 TileSet 與遊戲使用的圖集 |
| `common/terrain/source/` | 保留供美術編修的石材、踏台原圖與舊版圖集 |

個別場景新增專用素材時，可在這裡建立同名目錄。搬移已匯入的 PNG 時要保留其 `.png.import` 對應檔，以延續 Godot 的資源 UID。


## 在 TileMap 編輯物件

1. 開啟關卡，在 `Landscape` 選取對應圖層。四關共用相同名稱。`Props` 放一般物件，`BackgroundProps` 放背景裝飾，`ObstacleProps` 放石閘、碰撞柱和熔岩碰撞，`Effects` 放環境效果。
2. 在下方 TileMap 面板的 **Tiles** 選來源，再選場景圖塊並點地圖放置。**Scene Props** 有營火、石門、斷柱、蕨類與石匣，**Weapons** 有武器寶箱，**Armor** 有防具寶箱。
3. 用 TileMap 選取工具框選格子後，可移動、複製或貼上至另一關卡的物件圖層。物件以 20 × 20 格移動，格子中心是物件的定位點。各圖層原點可在 Inspector 查看。
4. 要編輯外觀，可開啟 `common/props/` 下的對應 `.tscn`。武器和防具寶箱場景分別在 `assets/items/weapon/chests/` 和 `assets/items/armor/chests/`。要新增物件，可把新場景加入 `props_tileset.tres` 的對應來源。新增圖層時，指定同一個 TileSet 並在 **Node → Groups** 加入 `prop_tiles`，遊戲就會登記該層的互動物件。

營火與門的光效、互動位置，以及石閘與碰撞柱的碰撞形狀，都跟著物件格移動。複製同款裝備寶箱會共用該裝備的領取狀態，石匣則共用該關卡的開啟狀態。迴廊的光鎖石閘由提燈解鎖。地形在 `Landscape/Terrain` 編輯。

在火山熔爐，選取 `Landscape/Effects`，從 TileMap 的 **Effects** 來源選擇 180、240 或 280 px 寬的熔岩圖塊。每個圖塊是一個包含熔岩和光暈的 .tscn，兩者會一起移動、複製或刪除。熔岩圖塊的定位點在熔岩左上角。若要調整原有的熔岩碰撞區，可在 `ObstacleProps` 移動碰撞圖塊。
