# Valhalla Elevation（高程）是什么
**Elevation = 高程/海拔查询能力**，读取地形海拔数据，给路径规划增加坡度信息。

## x.1 核心作用
1. **高程查询接口 `/elevation`**：输入一批经纬度，返回每个点的海拔高度。
2. **骑行、步行路径代价计算**：
    - 上坡：增加时间代价，骑行更费力，路线会尽量避开陡坡。
    - 下坡：可以设置惩罚或者奖励。
> 如果**没有高程数据**：valhalla做骑行/步行路由时，**完全不考虑坡度**，只看距离、道路类型。驾车不受高程影响。

### 数据来源：Skadi tiles
Valhalla 使用一套叫 **Skadi** 的高程瓦片，是把全球DEM地形数据处理成特殊压缩瓦片（`.hgt.lz4`）。
工具：`valhalla_build_elevation`，专门用来下载/生成skadi高程瓦片。

> 文档里的 Elevation Lookup Service：是HTTP服务上的 `/elevation`接口，需要开启 `ENABLE_SERVICES=ON`。

## x.2 和编译选项的对应关系
- `ENABLE_GDAL=ON`：开启GDAL，才能编译`valhalla_build_elevation`工具，用来构建skadi高程瓦片。
- `elevation‑lz4`（vcpkg.json里的feature）：依赖lz4，用来解压skadi高程瓦片。
- `ENABLE_GDAL=OFF`：
  - ❌ 不能运行 `valhalla_build_elevation`，无法生成高程瓦片
  - ❌ 不能用 `/elevation` http接口
  - ✅ **路由本身还可以跑，只是骑行/步行不计算坡度**

## x.3 两种使用场景
### 场景1：HTTP高程查询服务（文档描述的 Elevation Lookup Service）
需要：
1. `ENABLE_SERVICES=ON`（启动valhalla_service http服务）
2. 下载skadi高程瓦片数据集
3. valhalla.json配置`elevation:`路径指向skadi瓦片目录
4. 请求 `/elevation`，输入坐标，返回海拔。

### 场景2：离线库模式（你的机器人场景，`ENABLE_SERVICES=OFF`）
即使不开HTTP服务，只要本地有skadi瓦片，**Actor C++接口内部也可以使用高程做坡度代价**。
前提：编译时打开`ENABLE_GDAL=ON`，构建出skadi瓦片，valhalla配置文件指定高程目录。
> 代价：GDAL会引入整套geotiff/proj/curl，就是你刚才踩的那一堆vcpkg静态target坑。

## x.4 对你项目的建议
1. **现阶段先保持 `‑DENABLE_GDAL=OFF`**：把核心路由、瓦片构建调通，机器人路径先跑起来，骑行坡度先不考虑。
2. 业务跑通之后，如果需要坡度计算，再回头开启`ENABLE_GDAL=ON`，处理高程相关编译与数据。

## x.5 简单流程回顾（开启高程完整流程）
1. 编译valhalla开启`ENABLE_GDAL=ON`，得到`valhalla_build_elevation`工具
2. 下载skadi高程瓦片（或者用工具从原始DEM生成）
3. valhalla.json配置`elevation: {tile_dir:"xxx"}`
4. 构建OSM瓦片时，加载高程；sif代价模型会读取每个edge两端的海拔，计算坡度，改变骑行/步行cost。

### 补充区分
- OSM本身**不带海拔**；道路上没有坡度信息；坡度全部靠外部skadi高程瓦片，通过道路节点坐标去查询海拔再计算。
- 汽车auto模式路由几乎不用高程，主要影响bicycle/pedestrian。

如果你需要，我可以简单讲下skadi瓦片的目录结构、valhalla.json高程配置片段。