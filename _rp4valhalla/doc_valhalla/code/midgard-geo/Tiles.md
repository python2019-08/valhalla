# tiles
<!-- valhalla/midgard/tiles.h -->

## 一句话结论

✅ **是的，`Tiles` 的 `tilesize_` 是你传入、任意指定的（只要在边界范围内），不是固定按层级预定义的；**
✅ **和 Google Maps / OSM 标准 Web Mercator 瓦片（XYZ 四叉树、zoom level）完全两套体系。**

下面拆开对比，结合你这份 `valhalla::midgard::Tiles` 代码来讲：

## 1. Valhalla midgard::Tiles 是【均匀等大小网格，不是四叉树】

构造函数参数：

```
Tiles(const AABB2<coord_t>& bounds,
      const float tilesize,    // <===== 直接传入瓦片尺寸
      const unsigned short subdivisions = 1,
      bool wrapx = true);
```

- `tilesize`：**地理单位的边长**。如果 `coord_t=PointLL`（经纬度），那 `tilesize` 单位就是 **度（degree）**。
比如你传 `tilesize=4.0`，就是大家常听说的 Valhalla **4°×4° 的瓦片**；你也可以传 1°、0.5°，随便指定。
- 它先给一个全局包围盒 `tilebounds_`，然后在这个包围盒里面，**横向、纵向均匀切一样大的正方形格子**。
- 瓦片 ID 编码规则：```
tileid = row * ncolumns + col
```

row = (y - miny) / tilesize
col = (x - minx) / tilesize
- 没有 zoom 层级！**这个 Tiles 实例只有单一固定尺寸**。> 
> 如果你想要多分辨率，Valhalla 是**单独构造多个 Tiles 对象，每个对象用不同 tilesize**，而不是像 XYZ 那样一套四叉树自动包含所有层级。

> 
> 里面的 `subdivisions`：是**单个 tile 内部再切成小格子（bin）**，不是地图层级！
> 比如 subdivisions=16，一块4度瓦片里面切成 16×16 个 bin，用于局部精细查询、线段求交、最近点搜索，**不是地图缩放层级**。

## 2. Google Maps / Web Mercator XYZ 瓦片（四叉树）特点

标准XYZ：

1. 固定投影：Web Mercator（不是经纬度直接切）
2. 层级 zoom 是离散预定义：zoom 0 全球1张，zoom1 4张，zoom2 16张，**每一级长宽都是上一级的 1/2**，严格四叉树
3. 瓦片地理尺寸**不是任意指定**，由 zoom 唯一决定：```
单张瓦片宽度 = 地球周长 / 2^zoom
```
4. 瓦片坐标系：`(z, x, y)`，父子瓦片有明确包含关系，上级瓦片可以拆成4个子瓦片。

核心差异点：

| 项目 | valhalla midgard::Tiles | Google XYZ 四叉树瓦片 |
| --- | --- | --- |
| 瓦片大小 | 任意传入，固定单一级别 | 由zoom决定，固定二分，多级嵌套 |
| 划分方式 | 在给定bounds内均匀网格 | 全球递归四等分 |
| 父子关系 | 无父子瓦片关系；subdivisions只是tile内小格子 | 强父子，1父→4子 |
| 用途 | Valhalla路由引擎内部瓦片索引（baldr瓦片就是基于这套） | 地图前端渲染、图片瓦片 |
| 环绕 | 支持 `wrapx_` 经度180°环绕 | 原生支持经度环绕 |

## 3. 但注意：Valhalla baldr 里的路由瓦片，**习惯固定 4°**

虽然代码支持随便传 tilesize，但 Valhalla 生产构建的时候，默认就是用 **4度瓦片**，这是工程约定，不是代码强制约束。
你完全可以改代码、生成 1° 瓦片，只是：

- 所有预生成的瓦片数据（.tile）、NodeInfo/EdgeInfo 存储布局是跟着这套网格来的；
- 路由算法、缓存、加载逻辑都假设是4度；你随便换 tilesize 等于整套瓦片数据集都要重新生成。

## 4. 容易混淆的两个东西（重点）

1. `midgard::Tiles`：**通用网格工具类**，只做坐标↔tileid、邻接tile、线段和网格求交、bin细分；**它不包含路网数据**，只是数学网格。
2. `baldr` 瓦片：存 NodeInfo、边、路网的二进制瓦片文件，底层网格规则就是用 `midgard::Tiles(tilesize=4.0)` 生成的。

## 5. 补充：Neighbor 枚举和 GetNeighboringBins

你上面代码里的 `Neighbor`、`GetNeighboringBins`，是**tile内部bin（subdivision小格子）的8邻域**，不是四叉树子节点！

- 四叉树是“一个瓦片分成4个孩子瓦片”；
- 这里是：同一个大瓦片内部，小格子找上下左右斜邻居；也支持跨tile的bin邻居查找。

## 6. 一句话区分记忆

- XYZ：**zoom驱动、全球四叉树、瓦片大小是算死的**（给zoom，尺寸就定了），适合地图渲染；
- midgard::Tiles：**尺寸驱动、给定bounds均匀切网格、tilesize由调用方传入**，适合路由引擎做空间索引。

如果你想，我可以写一小段demo，实例化 `Tiles<PointLL>`，传入 tilesize=4.0，演示：经纬度 → tileid、找邻居tile、bin细分。