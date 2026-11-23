# 場景環境素材

環境素材以用途和場景歸檔。專用素材放在與 `scenes/<場景名>.tscn` 同名的目錄。兩個以上場景引用的素材集中在 `common/`。

| 路徑 | 內容 |
|---|---|
| `buried_court/` | 埋碑內庭專用背景 |
| `flooded_corridor/` | 淹沒的迴廊專用背景 |
| `common/backdrops/` | 主選單與崩塌神殿共用的背景 |
| `common/props/` | 營火、斷柱、蕨類、石門與石匣 |
| `common/terrain/` | 三個關卡共用的地形 TileSet 與遊戲使用的圖集 |
| `common/terrain/source/` | 保留供美術編修的石材、踏台原圖與舊版圖集 |

個別場景新增專用素材時，可在這裡建立同名目錄。搬移已匯入的 PNG 時要保留其 `.png.import` 對應檔，以延續 Godot 的資源 UID。
