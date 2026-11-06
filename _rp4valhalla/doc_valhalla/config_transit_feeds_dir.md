# ch01.transit_feeds_dir
<!-- scripts/valhalla_build_config -->
```json
"transit_feeds_dir": "Location of all GTFS transit feeds, needs to contain one subdirectory per feed"
```
**译文**：
> `"transit_feeds_dir"`：全部GTFS公交数据源的存放目录，**每个GTFS数据源单独放在一个子文件夹内**

## 术语说明
1. **GTFS**：General Transit Feed Specification，通用交通数据源规范，公交/轨道交通的标准静态时刻表数据格式（包含站点、线路、班次、时间等csv文件）
2. **transit feeds**：GTFS数据包（feed = 一套完整GTFS数据）

## 目录结构要求（重点）
`transit_feeds_dir` 是**根目录**，不能直接放GTFS的csv文件，必须按feed分一级子目录：
```
transit_feeds_dir/
├── feed_beijing/          # 第1套GTFS数据包
│   ├── agency.txt
│   ├── stops.txt
│   ├── routes.txt
│   └── ...
├── feed_shanghai/         # 第2套GTFS数据包
│   ├── agency.txt
│   ├── stops.txt
│   └── ...
```
❌ 错误：直接把所有GTFS csv文件丢在 `transit_feeds_dir` 下

如果你需要，我可以顺带说明这一般是**Valhalla**的配置项。

=====================================

# ch02.附：Valhalla 全量配置项解释（`scripts/valhalla_build_config` 的 help_text 逐条）

> 来源：`scripts/valhalla_build_config`（生成 `valhalla.json` 的官方脚本）
> 覆盖范围：`help_text` 字典的全部 **236 个叶子条目**，并给出 `config` 字典中的对应默认值
> 键名写法：`valhalla.json` 的层级路径（脚本内部用 `_` 拼成命令行参数，如 `--mjolnir-tile-dir`）

## 0. 前置知识

> Valhalla 整套组件都是北欧神话命名体系：
>   Valhalla英灵殿、Mjolnir雷神之锤、Thor托尔、Loki洛基、Odin奥丁、skadi女巨人斯卡蒂、Meili雷神索尔的亲弟弟

### 0.1 help_text 是什么

脚本里有两份同构的字典：

- `config`：默认配置树，最终 `json.dumps()` 成 `valhalla.json`
- `help_text`：与 `config` 结构一一对应的“注释树”，给每个叶子键一句话说明

`add_leaf_args()` 递归遍历 `config`，走到叶子时按路径去 `help_text` 取那句话，注册成命令行参数 `--<路径>`（`_` 换成 `-`）。所以 `valhalla_build_config --help` 打印出来的说明文字，就是 `help_text` 的原文。

```bash
# 逐条查看（推荐配合 less / grep）
python3 scripts/valhalla_build_config --help

# 用法示例：直接指定要覆盖的项，不指定的用默认值
valhalla_build_config --mjolnir-tile-dir /data/valhalla --loki-actions locate,route
```

### 0.2 阅读约定

- **默认值**：取自 `config`。`<optional:xxx>` = 该项在 `config` 里是 `Optional(xxx)`，**默认不写进生成的 JSON**（可选项），只是提示类型。可选 bool 一律“不写 = 关闭”。
- **单位**：距离=米，时间=秒，除非标注了别的单位（`max_time_contour` 是分钟、`max_distance_contour` 是公里、`mvt_max_age` 是秒的字符串）。
- **生效阶段**：`mjolnir` 节里我标了【构建期】/【运行期】，其余各节基本都是运行期。构建期 = `valhalla_build_tiles` 等工具；运行期 = 服务 / `GraphReader`。

### 0.3 两个非配置项的特殊条目

1. `logging.__note__`：不是配置项，不会出现在 JSON 里，只是写在 `help_text` 里的提示——**文件日志器不适用于多进程模式，日志滚动可能引发竞态甚至崩溃**。
2. `meili.default` 下的 `gps_accuracy` / `geometry` / `route`、`meili.grid.*`：原文写的是 `TODO:`（脚本作者没写完）。本文按源码（`valhalla/meili/config.h`、`src/meili/config.cc`）的实际语义补齐，并标出哪些键其实根本没人读。

---

## 1. `logging` — 进程日志（5 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `logging.type` | `"std_out"` | Type of logger either std_out or file | 日志去处：`std_out` 打标准输出（容器/系统日志友好，默认）；`file` 写进 `file_name`。 |
| `logging.color` | `true` | Use colored log level in std_out logger | 仅 `std_out` 有效：给日志级别加 ANSI 颜色。输出重定向到文件时建议关掉，否则混入转义字符。 |
| `logging.file_name` | `"path_to_some_file.log"` | Output log file for the file logger | `type=file` 时的输出文件路径。默认值是**占位符**，会原样出现在生成的 JSON 里，用文件日志前必须改。 |
| `logging.max_file_size` | `<optional:int>` | Maximum file size in bytes before rolling to a new file (0 = disabled) | 单文件字节上限，超过就滚动出新文件；0 = 关闭滚动。默认不写进 JSON（等同关闭）。 |
| `logging.max_archived_files` | `<optional:int>` | Maximum number of archived log files to keep (0 = disabled) | 滚动后保留的历史日志份数上限；0 = 不保留。默认不写进 JSON。 |

---

## 2. `mjolnir` — 建图 / 瓦片缓存（53 项）

> 这一节最杂：既有 `valhalla_build_tiles` 的建图开关，也有 **运行时** `GraphReader` 读的瓦片来源与缓存策略（`tile_dir` / `tile_extract` / `tile_url` / `max_cache_size` 等），生产部署改得最多。

> **Mjolnir = Valhalla 的地图图块构建器（离线数据预处理模块）**
>    
> - 作用：把原始 OSM 地图数据 + GTFS 公交数据，**敲碎、处理、打包成 Valhalla 可用于实时路径规划的分层图块（tile）**valhalla.g...
> - 一句话区分：
>   - **Mjolnir：离线预处理，构建路由图块（一次性 / 定期跑）**
>   - **Thor：在线路径搜索（A*/ 双向 A*，接收请求算路线）**
>   - **Loki：坐标匹配 / 点 Snap**
>   - **Odin：生成导航转向提示文字**

### 2.1 内存与缓存

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `mjolnir.max_cache_size` | `1000000000` | Number of bytes per thread used to store tile data in memory | 【运行期+构建期】每线程用于缓存 tile 数据的字节数上限（运行期即 `GraphReader` 的瓦片缓存）。默认 1 GB，**注意是每线程**：内存占用约 = 线程数 × 该值。 |
| `mjolnir.id_table_size` | `1300000000` | Value controls the initial size of the Id table | 【构建期】Id 表的初始容量，建图时把 OSM id / 瓦片内 id 映射到内部索引。默认 13 亿是按行星规模给的；区域小可调小省内存，区域大调小只会触发多次扩容（更慢）。 |
| `mjolnir.use_lru_mem_cache` | `false` | Use memory cache with LRU eviction policy | 【运行期】用 LRU 淘汰策略的缓存，淘汰单块而非整体。默认用 FlatTileCache（固定大小数组，超限整体清空）。 |
| `mjolnir.lru_mem_cache_hard_control` | `false` | Use hard memory limit control for LRU memory cache (i.e. on every put) - never allow overcommit | 【运行期】LRU 的硬/软内存控制：`true` = 每次写入都校验，绝不超额（更稳、更慢）；`false` = 软限制，允许短暂超出。 |
| `mjolnir.use_simple_mem_cache` | `false` | Use memory cache within a simple hash map the clears all tiles when overcommitted | 【运行期】用简单哈希表缓存，超额时清空全部 tile（实现简单、抖动大）。与 `use_lru_mem_cache` 同时为 true 时 LRU 优先；且 `global_synchronized_cache=true` 时源码里该分支被注释掉，会退化成 FlatTileCache。 |
| `mjolnir.global_synchronized_cache` | `false` | bool indicating whether global_synchronized_cache is used - default to False | 【运行期】所有线程共享**一个加锁的全局缓存**（而不是每线程一份），省内存但引入锁竞争。配合 `use_lru_mem_cache=true` 时即“全局共享 LRU”。 |
| `mjolnir.max_concurrent_reader_users` | `1` | number of threads in the threadpool which can be used to fetch tiles over the network via curl | 【运行期】通过 curl 下载瓦片的线程池大小（`tile_url` 拉瓦片、远程 skadi 高程都用它），默认 1。 |

### 2.2 瓦片来源与外部数据

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `mjolnir.tile_dir` | `"/data/valhalla"` | Location to read/write tiles to/from | 【运行期+构建期】瓦片树的根目录（散文件形式），建瓦片写这里，运行时读这里。 |
| `mjolnir.tile_extract` | `"/data/valhalla/tiles.tar"` | Location to read tiles from tar | 【运行期】从 tar 包读瓦片（生产推荐，比散文件快）。与 `tile_dir` 可共存，tar 命中优先。 |
| `mjolnir.traffic_extract` | `"/data/valhalla/traffic.tar"` | Location to read traffic from tar | 【运行期】实时交通（live traffic）覆盖层的 tar，独立于路由瓦片。 |
| `mjolnir.incident_dir` | `<optional:str>` | Location to read incident tiles from | 【运行期】交通事件（incident）瓦片目录。与 `incident_log` **任一非空即启用** incident 功能。 |
| `mjolnir.incident_log` | `<optional:str>` | Location to read change events of incident tiles | 【运行期】事件的变更日志（增量更新用）。 |
| `mjolnir.user_agent` | `<optional:str>` | User-Agent http header to request single tiles | 经 `tile_url` 拉单块瓦片时发送的 HTTP `User-Agent` 头。 |
| `mjolnir.tile_url` | `<optional:str>` | Http location to read tiles from if they are not found in the tile_dir, e.g.: http://your_valhalla_tile_server_host:8000/some/Optional/path/{tilePath}?some=Optional&query=params. Valhalla will look for the {tilePath} portion of the url and fill this out with a given tile path when it make a request for that tile | 【运行期】`tile_dir` 里找不到瓦片时改为按需 HTTP 下载。URL 里**必须包含 `{tilePath}` 占位符**，Valhalla 会替换为具体瓦片路径。默认空 = 不启用。 |
| `mjolnir.tile_url_gz` | `<optional:bool>` | Whether or not to request for compressed tiles | 【运行期】请求瓦片时是否要 gzip 压缩版（配套 `tile_url`）。 |
| `mjolnir.tile_url_user_pw` | `<optional:str>` | User & password for HTTP basic auth in the form of "user:password" | 【运行期】瓦片服务的 HTTP Basic 认证，格式 `user:password`。 |
| `mjolnir.shortcut_caching` | `<optional:bool>` | Precaches the superseded edges of all shortcuts in the graph. Defaults to false | 【运行期】启动时预缓存所有 shortcut 的 `superseded` 边（base edge），加速 `RecoverShortcut()` 还原路径。默认关闭，开启换来启动耗时 + 内存。 |
| `mjolnir.admin` | `"/data/valhalla/admin.sqlite"` | Location of sqlite file holding admin polygons created with valhalla_build_admins | 【构建期(+运行期)】行政多边形 sqlite，由 `valhalla_build_admins` 生成；用于国/州界、国家级限速与通行覆盖。 |
| `mjolnir.landmarks` | `"/data/valhalla/landmarks.sqlite"` | Location of sqlite file holding landmark POI created with valhalla_build_landmarks | 【构建期】地标 POI sqlite，由 `valhalla_build_landmarks` 生成（用于地标 POI 相关的图增强/名称）。 |
| `mjolnir.timezone` | `"/data/valhalla/tz_world.sqlite"` | Location of sqlite file holding timezone information created with valhalla_build_timezones | 【运行期+构建期】IANA 时区 sqlite，由 `valhalla_build_timezones` 生成；时间依赖路由（`depart_at`/`arrive_by`）与本地时间显示依赖它。 |
| `mjolnir.transit_dir` | `"/data/valhalla/transit"` | Location of intermediate transit tiles created with valhalla_build_transit | 【构建期】`valhalla_build_transit` 产出的**中间**公交瓦片目录（GTFS → 瓦片的中间产物）。 |
| `mjolnir.transit_feeds_dir` | `"/data/valhalla/transit_feeds"` | Location of all GTFS transit feeds, needs to contain one subdirectory per feed | 【构建期】所有 GTFS 数据包的根目录，**每个 feed 一个子目录**（详见本文件顶部 ch01）。 |
| `mjolnir.transit_bounding_box` | `<optional:str>` | Add comma separated bounding box values to only download transit data inside the given bounding box | 【构建期】逗号分隔的 bbox，只处理框内的公交数据（小范围测试/裁剪用）。 |
| `mjolnir.transit_pbf_limit` | `20000` | Limit individual PBF files to this many trips (needed for PBF's stupid size limit) | 【构建期】单个 PBF 文件最多装多少条 trip，超过就拆分文件——为绕开 protobuf 单文件大小上限。原文自带吐槽 “PBF's stupid size limit”。 |

### 2.3 建图开关（true/false 类）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `mjolnir.hierarchy` | `true` | bool indicating whether road hierarchy is to be built - default to True | 【构建期】是否构建路网层级（level 0/1/2）。关掉会明显拖慢长途路由，一般不动。 |
| `mjolnir.shortcuts` | `true` | bool indicating whether shortcuts are to be built - default to True | 【构建期】是否构建 shortcut 边（把可收缩节点串成一条边，供 BidirectionalAStar 用；只影响 level 0/1）。 |
| `mjolnir.keep_all_osm_node_ids` | `false` | bool indicating whether to store all OSM node ids in the graph data - defaults to False | 【构建期】是否在图中保存**所有** OSM node id（含几何中间点）。瓦片显著变大，用于回溯到 OSM 原始数据。 |
| `mjolnir.keep_osm_node_ids` | `false` | bool indicating whether to store OSM node ids (at topological/graph nodes) in the graph data - defaults to False | 【构建期】只保存拓扑节点（graph node）上的 OSM node id，比上一条省空间。 |
| `mjolnir.include_platforms` | `false` | bool indicating whether to include highway=platform - default to False | 【构建期】是否把 `highway=platform` 纳入图。 |
| `mjolnir.include_driveways` | `true` | bool indicating whether private driveways are included - default to True | 【构建期】是否纳入私有车道（driveway）。 |
| `mjolnir.include_construction` | `false` | bool indicating where roads under construction are included - default to False | 【构建期】是否纳入在建道路（`highway=construction`）。 |
| `mjolnir.include_bicycle` | `true` | bool indicating whether cycling only ways are included - default to True | 【构建期】是否纳入“仅自行车”的 way；设 false 会让 bicycle costing 在图里无路可走。 |
| `mjolnir.include_pedestrian` | `true` | bool indicating whether pedestrian only ways are included - default to True | 【构建期】是否纳入“仅步行”的 way。 |
| `mjolnir.include_driving` | `true` | bool indicating whether driving only ways are included - default to True | 【构建期】是否纳入“仅机动车”的 way。 |
| `mjolnir.import_bike_share_stations` | `false` | bool indicating whether importing bike share stations(BSS). Set to True when using multimodal - default to False | 【构建期】是否导入共享单车站点（BSS）；`multimodal` / `bikeshare` costing 依赖它，用多式联运时必须开。 |
| `mjolnir.reclassify_links` | `true` | bool indicating whether or not to reclassify links - reclassifies ramps based on the lowest class connecting road | 【构建期】是否重分类 link：匝道按“与之相连的最低等级道路”重新定级（影响可达性/限速判定）。 |
| `mjolnir.pedestrian_areas` | `false` | bool indicating whether or not to generate traversal edges for pedestrian areas - default to False | 【构建期】是否为步行区（pedestrian area，如广场）生成可穿行边；需要 `include_pedestrian=true` 才一起生效。 |

> **注意**：`include_bicycle` / `include_pedestrian` / `include_driving` 是在解析**之后**做图过滤（`src/mjolnir/graphfilter.cc`）。过滤会删边，随后的聚合步骤会把“只剩 2 条边”的节点合并回去，**可能改变边拓扑**——排查路由差异时要留意。

### 2.4 建图参数

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `mjolnir.concurrency` | `<optional:int>` | How many threads to use in the concurrent parts of tile building | 【构建期】并行阶段线程数，默认不写 → 用 `std::thread::hardware_concurrency()`。 |
| `mjolnir.data_quality_dir` | `<optional:str>` | The directory where we output files regarding data quality issues, e.g. duplicateways.txt | 【构建期】数据质量问题报告的输出目录（如 `duplicateways.txt`）。 |
| `mjolnir.graph_lua_name` | `<optional:str>` | Location of the lua file to use for graph customization during tile building instead of default one | 【构建期】替换默认 `lua/graph.lua` 的自定义 lua，用于改 tag→图属性映射而不改 C++（注意：用别的 lua 建出的就是另一套数据集）。 |
| `mjolnir.default_speeds_config` | `<optional:str>` | a path indicating the json config file which graph enhancer will use to set the speeds of edges in the graph based on their geographic location (state/country), density (urban/rural), road class, road use (form of way) | 【构建期】JSON 配置，让 graph enhancer 按 地理位置（州/国家）+ 密度（城乡）+ 道路等级 + form of way 写速度。详见 `docs/docs/concepts/speeds.md`。 |
| `mjolnir.dataset_id` | `<optional:int>` | Optional integer id to identify the tile dataset. By default we try to set the maximum OSM changeset ID. | 【构建期】给这套瓦片一个整数标识；不填则自动取最大 OSM changeset id。 |

### 2.5 `mjolnir.data_processing` — 解析/增强阶段细节（11 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `data_processing.infer_internal_intersections` | `true` | bool indicating whether or not to infer internal intersections during the graph enhancer phase or use the internal_intersection key from the pbf | 【构建期】内部交叉口：自动推断，还是用 pbf 里的 `internal_intersection` 键。 |
| `data_processing.infer_turn_channels` | `true` | bool indicating whether or not to infer turn channels during the graph enhancer phase or use the turn_channel key from the pbf | 【构建期】转向渠化道（turn channel）：自动推断，还是用 pbf 的 `turn_channel` 键。 |
| `data_processing.apply_country_overrides` | `true` | bool indicating whether or not to apply country overrides during the graph enhancer phase | 【构建期】是否应用国家级覆盖规则（限速/通行等按国家修正）。 |
| `data_processing.grid_divisions_within_tile` | `32` | number of grid subdivisions within a tile. Used for spatial sorting of nodes within a tile. Set to 0 to disable spatial sorting of nodes | 【构建期】瓦片内做节点空间排序时的网格细分数；**0 = 关闭节点空间排序**。 |
| `data_processing.use_admin_db` | `true` | bool indicating whether or not to use the administrative database during the graph enhancer phase or use the admin keys from the pbf that are set on the node | 【构建期】判定国家/州：用 admin 数据库，还是用 pbf 节点上的 admin 键。 |
| `data_processing.use_direction_on_ways` | `false` | bool indicating whether or not to process the direction key on the ways or utilize the guidance relation tags during the parsing phase | 【构建期】二选一：解析 way 上的 `direction` 键，还是用 guidance relation 标签。 |
| `data_processing.allow_alt_name` | `false` | bool indicating whether or not to process the alt_name key on the ways during the parsing phase | 【构建期】解析阶段是否处理 way 的 `alt_name`。 |
| `data_processing.use_urban_tag` | `false` | bool indicating whether or not to use the urban area tag on the ways or to utilize the getDensity function within the graph enhancer phase | 【构建期】判定城乡：用 way 上的 urban 标签，还是用 graph enhancer 的 `getDensity()`（影响默认速度）。 |
| `data_processing.use_rest_area` | `false` | bool indicating whether or not to use the rest/service area tag on the ways | 【构建期】是否使用 rest/service area（服务区/停车区）标签。 |
| `data_processing.scan_tar` | `false` | bool indicating whether or not to pre-scan the tar ball(s) when loading an extract with an index file, to warm up the OS page cache. | 【运行期】用带索引的 tar 加载瓦片时先扫一遍预热 OS 页缓存：首次请求更快，启动更慢。 |
| `data_processing.build_bounding_circles` | `true` | bool indicating whether to store 32-bit bounding circles for edges analogous to the edge bins inside level 2 graph tiles. This option is currently disabled. | 【构建期】是否给边额外存 32 位包围圆（类比 level2 瓦片里的 edge bin）。文案自称“目前禁用”，但配置默认值仍是 `true`——是否真生效以 `graphvalidator.cc` 里的分支为准。 |

---

## 3. `additional_data` — 高程（3 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `additional_data.elevation` | `"/data/valhalla/elevation/"` | Location of elevation tiles | Skadi 高程瓦片目录。没有它，骑行/步行**完全不考虑坡度**（见 `0.concept/elevation.md`）。 |
| `additional_data.elevation_url` | `<optional:str>` | Http location to read elevations from. this address is used if elevation tiles were not found in the elevation directory. Ex.: http://<your_valhalla_tile_server_host>:<your_valhalla_tile_server_port>/some/Optional/path/{tilePath}?some=Optional&query=params. Valhalla will look for the {tilePath} portion of the url and fill this out with an elevation path when it makes a request for that particular elevation | 目录里找不到高程瓦片时改从 HTTP 按需取；同样必须含 `{tilePath}` 占位符。 |
| `additional_data.elevation_url_user_pw` | `<optional:str>` | User & password for HTTP basic auth in the form of "user:password" | 高程服务的 HTTP Basic 认证，格式 `user:password`。 |

---

## 4. `loki` — 定位/相关（14 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `loki.actions` | 13 项列表（locate, route, height, sources_to_targets, optimized_route, isochrone, trace_route, trace_attributes, transit_available, expansion, centroid, status, tile） | Comma separated list of allowable actions for the service, one or more of: locate, route, height, optimized_route, isochrone, trace_route, trace_attributes, transit_available, expansion, centroid, status, tile | 允许的动作白名单（逗号分隔），不在名单里的接口不可用。**help_text 的枚举漏了 `sources_to_targets`**，但默认列表里是有的——写文档/写配置时以 `config` 列表为准。 |
| `loki.use_connectivity` | `true` | a boolean value to know whether or not to construct the connectivity maps | 是否构建连通性图（correlation 阶段判断候选点之间是否真的可达，避免把不可达的点硬配到路网）。用内存/启动时间换正确性。 |
| `loki.service_defaults.radius` | `0` | Default radius to apply to incoming locations should one not be supplied | 请求没给 `radius` 时用的默认搜索半径（米）；**0 = 由 Valhalla 按 costing 自动决定**。 |
| `loki.service_defaults.minimum_reachability` | `50` | Default minimum reachability to apply to incoming locations should one not be supplied | 默认最小可达性（能到达多少节点）；低于阈值的边会被视为孤岛而忽略。 |
| `loki.service_defaults.search_cutoff` | `35000` | The cutoff at which we will assume the input is too far away from civilisation to be worth correlating to the nearest graph elements | 距离阈值（米，默认 35 km）：超过就认为输入点太偏远，不再去关联最近的图元素。 |
| `loki.service_defaults.node_snap_tolerance` | `5` | During edge correlation this is the tolerance used to determine whether or not to snap to the intersection rather than along the street, if the snap location is within this distance from the intersection the intersection is used instead | 相关时，若吸附点距路口小于该值（米），就吸附到**路口**而不是路段上的投影点。 |
| `loki.service_defaults.street_side_tolerance` | `5` | If your input coordinate is less than this tolerance away from the edge centerline then we set your side of street to none otherwise your side of street will be left or right depending on direction of travel | 输入点离道路中心线小于该值（米）→ `side_of_street = none`；否则按行进方向给 left/right。 |
| `loki.service_defaults.street_side_max_distance` | `1000` | The max distance in meters that the input coordinates or display ll can be from the edge centerline for them to be used for determining the side of street. Beyond this distance the side of street is set to none | 判定 side_of_street 的最大距离（米），超过一律 `none`。 |
| `loki.service_defaults.heading_tolerance` | `60` | When a heading is supplied, this is the tolerance around that heading with which we determine whether an edges heading is similar enough to match the supplied heading | 请求给了 `heading` 时，允许的角度偏差（度），用来筛选匹配的边。 |
| `loki.service_defaults.mvt_min_zoom_road_class` | `[7, 7, 8, 11, 11, 12, 13, 14]` | Minimum zoom level for each road class (8 values: Motorway, Trunk, Primary, Secondary, Tertiary, Unclassified, Residential, Service/Other). Roads will only be rendered at or above their minimum zoom level. | 8 类道路（Motorway…Service/Other）各自的最小渲染 zoom；道路只在该 zoom 及以上才渲染。**源码校验必须非递减**，写成降序会直接抛异常。 |
| `loki.service_defaults.mvt_cache_dir` | `<optional:str>` | The cache directory for MVT tiles. If empty/omitted, we disable MVT caching | MVT 瓦片缓存目录；空/不写 = 关闭 MVT 缓存（源码：目录不存在会自动创建）。 |
| `loki.service_defaults.mvt_cache_min_zoom` | `11` | The minimum zoom level which will be cached, the maximum will be determined by mvt_min_zoom_road_class | 缓存的最小 zoom，最大值由 `mvt_min_zoom_road_class` 决定。 |
| `loki.service_defaults.mvt_max_age` | `"1800"` | The value used for 'max-age' in the Cache-Control response header for the MVT end point | MVT 接口响应头 `Cache-Control: max-age` 的值（秒，注意是**字符串**）。 |
| `loki.service.proxy` | `"ipc:///tmp/loki"` | IPC linux domain socket file location | Loki worker 的 ZeroMQ IPC socket 地址，仅多进程（worker 分离部署）时需要；one-shot CLI / 库模式用不到。 |

---

## 5. `thor` — 路径算法与矩阵（31 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `thor.source_to_target_algorithm` | `"select_optimal"` | Which matrix algorithm should be used, one of "timedistancematrix" or "costmatrix". If blank, the optimal will be selected. | 矩阵用哪个算法。**实际只认字符串 `timedistancematrix` / `costmatrix`**，其它任何值（含 `select_optimal`、空）都落到 SELECT_OPTIMAL 自动挑：自行车/步行且 source 或 target ≤ 5 用 TimeDistanceMatrix，transit 用 TimeDistanceMatrix，其余用 CostMatrix。 |
| `thor.service.proxy` | `"ipc:///tmp/thor"` | IPC linux domain socket file location | Thor worker 的 IPC socket（多进程部署）。 |
| `thor.max_reserved_labels_count_astar` | `2000000` | Maximum capacity allowed to keep reserved for unidirectional A*. | 单向 A* 单次请求预分配的 label 容量上限（超了会扩容/重分配，影响性能）。 |
| `thor.max_reserved_labels_count_bidir_astar` | `1000000` | Maximum capacity allowed to keep reserved for bidirectional A*. | 双向 A* 同上。 |
| `thor.max_reserved_labels_count_dijkstras` | `4000000` | Maximum capacity allowed to keep reserved for unidirectional Dijkstras. | 单向 Dijkstra（矩阵）同上。 |
| `thor.max_reserved_labels_count_bidir_dijkstras` | `2000000` | Maximum capacity allowed to keep reserved for bidirectional Dijkstras. | 双向 Dijkstra 同上。 |
| `thor.clear_reserved_memory` | `false` | If True clean reserved memory in path algorithms | `true` = 每次算完释放预分配内存（省内存、变慢）；`false` = 留着下次复用（默认，快）。 |
| `thor.extended_search` | `false` | If True and 1 side of the bidirectional search is exhausted, causes the other side to continue if the starting location of that side began on a not_thru or closed edge | `true` 时，双向搜索一侧已耗尽，但该侧起点位于 not_thru / closed 边，则让另一侧继续搜（避免误判无路）。 |

### 5.1 `thor.costmatrix` — 矩阵 CostMatrix 算法

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `costmatrix.check_reverse_connection` | `true` | Whether to check for expansion connections on the reverse tree, which has an adverse effect on performance | 是否也在反向树上检查连接点：更准，但性能更差。 |
| `costmatrix.allow_second_pass` | `false` | Whether to allow a second pass for unfound CostMatrix connections, where we turn off destination-only, relax hierarchies and expand into "semi-islands" | 第一遍没连上的连接是否允许再跑一遍（关掉 destination-only、放开层级限制、向“半孤岛”扩展）。 |
| `costmatrix.max_reserved_locations` | `25` | Maximum amount of locations allowed to to keep reserved between requests for CostMatrix | 跨请求为 CostMatrix 保留的 location 容量上限。 |
| `costmatrix.max_iterations` | `2800` | Upper bound on the number of iterations per expansion once a path has been found. Must be a positive integer | 找到路径后，每轮扩展的迭代次数上限（正整数）。 |
| `costmatrix.min_iterations` | `100` | Lower bound on the number of iterations per expansion once a path has been found. Must be a positive integer | 同上，下限。源码对 `min_iterations` 与 `max_iterations` 各自只做“≥1”保护，两者大小关系不校验。 |
| `costmatrix.hierarchy_limits.max_up_transitions.1` / `.2` | `400` / `100` | The default maximum up transitions for level 1 / 2 in CostMatrix | 各层级允许的最大“向上跳级”次数默认值。 |
| `costmatrix.hierarchy_limits.expand_within_distance.0` / `.1` / `.2` | `1e8` / `20000` / `5000` | The default distance within which expansion is allowed from the origin/destination on level 0 / 1 / 2 in costmatrix | 起点/终点在各层级允许扩展的最大距离（米）。 |

### 5.2 `thor.bidirectional_astar` — 主路由算法（含备选路线）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `bidirectional_astar.threshold_delta` | `420.0` | Time (seconds) to extend search once the first connection has been found | 找到第一条连接后，再多搜多少**秒**（时间预算），用于继续找更优/备选路径。 |
| `bidirectional_astar.alternative_cost_extend` | `1.2` | Relative cost extension to find alternative routes | 找备选路线时的相对代价放宽系数：1.2 = 允许比最优贵 20%。 |
| `bidirectional_astar.alternative_iterations_delta` | `100000` | Number of extra iterations to allow when searching for alternative paths. Higher values will find more alternatives but will be slower | 找备选时额外允许的迭代次数；越大备选越多、越慢。 |
| `bidirectional_astar.hierarchy_limits.*` | 同上（level1 expand = `20000`） | （原文与 costmatrix 完全一致） | 同 5.1 的层级限制语义，作用于双向 A*。 |

### 5.3 `thor.unidirectional_astar` — 时间依赖路由用

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `unidirectional_astar.hierarchy_limits.*` | level1 expand = `100000`，其余同上 | （原文与 costmatrix 完全一致） | 同 5.1 的层级限制语义，作用于单向 A*（`depart_at`/`arrive_by` 场景）。 |

> **help_text 的一处瑕疵**：`bidirectional_astar` / `unidirectional_astar` 的 `max_up_transitions` 文案也写成 “in CostMatrix”，是复制粘贴遗留；实际各自作用于对应算法。

---

## 6. `odin` — 导航文案（3 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `odin.service.proxy` | `"ipc:///tmp/odin"` | IPC linux domain socket file location | Odin worker 的 IPC socket（多进程部署）。 |
| `odin.markup_formatter.markup_enabled` | `false` | Boolean flag to use markup formatting | 是否启用 markup 格式化（在导航指令里插入自定义标记，给下游 TTS/UI 用）。 |
| `odin.markup_formatter.phoneme_format` | `"<TEXTUAL_STRING> (<span class=<QUOTES>phoneme<QUOTES>>/<VERBAL_STRING>/</span>)"` | The phoneme format string that will be used by street names and signs | 街道名/路牌的音素（发音）格式模板。 |

---

## 7. `meili` — 地图匹配（24 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `meili.mode` | `"auto"` | Specify the default transport mode | 服务默认交通方式（匹配用哪个 costing）。注意官方文档写的是 `multimodal`，而本脚本默认 `auto`。 |
| `meili.customizable` | 9 项列表 | Specify which parameters are allowed to be customized by URL query parameters | 允许被 URL 查询参数覆盖的参数白名单。**不在名单里的参数，请求里给了也会被忽略**。 |
| `meili.verbose` | `false` | Control verbose output for debugging | 调试用的详细输出。 |
| `meili.default.sigma_z` | `4.07` | A non-negative value to specify the GPS accuracy (the variance of the normal distribution) of an incoming GPS sequence. It is also used to weight emission costs of measurements | GPS 观测噪声的标准差（正态分布参数），用于加权 emission cost。 |
| `meili.default.gps_accuracy` | `5.0` | TODO: | 【原文是 TODO，按源码补】GPS 测量的默认精度（米），用于决定候选搜索的最大半径（`config.h` 的 `gps_accuracy_meters`）。 |
| `meili.default.beta` | `3` | A non-negative emprical value to weight the transition cost of two successive candidates | 经验值，加权两个相邻候选点之间的 transition cost。 |
| `meili.default.max_route_distance_factor` | `5` | A non-negative value used to limit the routing search range which is the distance to next measurement multiplied by this factor | 限制搜索范围：到下一个测量点的距离 × 该系数。 |
| `meili.default.max_route_time_factor` | `5` | A non-negative value used to limit the routing search range which is the time to the next measurement multiplied by this factor | 同上，用时间 × 该系数。 |
| `meili.default.max_search_radius` | `100` | A non-negative value specifying the maximum radius in meters about a given point to search for candidate edges for routing | 候选边搜索的最大半径（米），是 `search_radius` 的上界。 |
| `meili.default.breakage_distance` | `2000` | A non-negative value. If two successive measurements are far than this distance, then connectivity in between will not be considered | 相邻两个测量点距离超过它（米）就不考虑它们之间的连通性（认为轨迹断裂）。 |
| `meili.default.interpolation_distance` | `10` | If two successive measurements are closer than this distance, then the later one will be interpolated into the matched route | 相邻测量点距离小于它（米）时，后一个点直接插值进匹配结果，不单独匹配。 |
| `meili.default.search_radius` | `50` | A non-negative value to specify the search radius (in meters) within which to search road candidates for each measurement | 每个测量点搜索候选道路的半径（米）。 |
| `meili.default.geometry` | `false` | TODO: | 【原文是 TODO；**当前代码不读该键**】`src/meili/config.cc` 只读 `default.sigma_z/beta/.../turn_penalty_factor`。是否返回几何由请求参数决定，属历史遗留项。 |
| `meili.default.route` | `true` | TODO: | 【原文是 TODO；**当前代码不读该键**】同上，历史遗留。 |
| `meili.default.turn_penalty_factor` | `0` | A non-negative value to penalize turns from one road segment to next | 惩罚“从一条路段转到下一条”的系数，0 = 不惩罚。 |
| `meili.auto.turn_penalty_factor` | `200` | A non-negative value to penalize turns from one road segment to next | 按交通方式覆盖 `default`：auto 的转向惩罚。 |
| `meili.auto.search_radius` | `50` | A non-negative value to specify the search radius (in meters) within which to search road candidates for each measurement | auto 的候选搜索半径。 |
| `meili.pedestrian.turn_penalty_factor` | `100` | A non-negative value to penalize turns from one road segment to next | pedestrian 的转向惩罚。 |
| `meili.pedestrian.search_radius` | `50` | A non-negative value to specify the search radius (in meters) within which to search road candidates for each measurement | pedestrian 的候选搜索半径。 |
| `meili.bicycle.turn_penalty_factor` | `140` | A non-negative value to penalize turns from one road segment to next | bicycle 的转向惩罚（未列出的参数继承 `default`）。 |
| `meili.multimodal.turn_penalty_factor` | `70` | A non-negative value to penalize turns from one road segment to next | multimodal 的转向惩罚。 |
| `meili.service.proxy` | `"ipc:///tmp/meili"` | IPC linux domain socket file location | Meili worker 的 IPC socket（多进程部署）。 |
| `meili.grid.size` | `500` | TODO: Resolution of the grid used in finding match candidates | 【原文是 TODO，按源码补】候选搜索网格的分辨率（`config.h` 的 `grid_size`，默认 500）。 |
| `meili.grid.cache_size` | `100240` | TODO: number of grids to keep in cache | 【原文是 TODO，按源码补】网格缓存的条目数上限（`config.h` 的 `cache_size`）。 |

---

## 8. `httpd` — 服务进程（6 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `httpd.service.listen` | `"tcp://*:8002"` | The protocol, host location and port your service will bind to | 服务监听的协议/地址/端口（ZeroMQ 端点写法）。 |
| `httpd.service.loopback` | `"ipc:///tmp/loopback"` | IPC linux domain socket file location used to communicate results back to the client | 结果回传给客户端的 IPC socket。 |
| `httpd.service.interrupt` | `"ipc:///tmp/interrupt"` | IPC linux domain socket file location used to cancel work in progress | 取消进行中任务的 IPC socket。 |
| `httpd.service.drain_seconds` | `28` | How long to wait for currently running threads to finish before signaling them to shutdown | 收到关闭信号后，等待在跑线程自然完成的时间（秒）。 |
| `httpd.service.shutdown_seconds` | `1` | How long to wait for currently running threads to quit before exiting the process | 之后强等线程退出的时间（秒），再不走就退出进程。 |
| `httpd.service.timeout_seconds` | `-1` | How long to wait for a single request to finish before timing it out (defaults to infinite) | 单请求超时（秒），`-1` = 不超时。 |

---

## 9. `service_limits` — 请求限额（92 项）

> 这一节是“防滥用/防打爆”的总闸：超限的请求会直接返回错误码，不会进算法。所有 costing 的同名 4 项含义一致，先给通用解释，再给各 costing 的默认值矩阵。

### 9.1 每个 costing 的 4 个通用键（含义相同，共 47 条）

| 键（相对 `service_limits.<costing>.`） | help_text 原文 | 解释 |
|---|---|---|
| `.max_distance` | Maximum b-line distance between all locations in meters | 一次请求里所有输入点之间的**大圆距离**上限（米）；超了不路由。 |
| `.max_locations` | Maximum number of input locations | 单次请求允许的输入点个数上限。 |
| `.max_matrix_distance` | Maximum b-line distance between 2 most distant locations in meters for a matrix | 矩阵请求中相距最远的两个点的大圆距离上限（米）；`0` = 禁止矩阵。 |
| `.max_matrix_location_pairs` | Maximum number of routes computed with the matrix, e.g. 2500 = 50:50 or 1:2500 | 矩阵最多算多少条 source×target；2500 即 50×50 或 1×2500。 |

各 costing 的默认值：

| costing | `.max_distance` | `.max_locations` | `.max_matrix_distance` | `.max_matrix_location_pairs` |
|---|---|---|---|---|
| `auto` | 5000000 | 20 | 400000 | 2500 |
| `bus` | 5000000 | 50 | 400000 | 2500 |
| `taxi` | 5000000 | 20 | 400000 | 2500 |
| `truck` | 5000000 | 20 | 400000 | 2500 |
| `auto_pedestrian` | 5000000 | （配置里没有，**运行时硬编码为 2**） | 400000 | 2500 |
| `pedestrian` | 250000 | 50 | 200000 | 2500 |
| `bicycle` | 500000 | 50 | 200000 | 2500 |
| `motor_scooter` | 500000 | 50 | 200000 | 2500 |
| `motorcycle` | 500000 | 50 | 200000 | 2500 |
| `transit` | 500000 | 50 | 200000 | 2500 |
| `bikeshare` | 500000 | 50 | 200000 | 2500 |
| `multimodal` | 500000 | 50 | **0（矩阵禁用）** | **0（矩阵禁用）** |

> 源码细节：loki 解析这组限额时会跳过 `trace` 与 `auto_pedestrian` 的 `max_locations`，然后把 `auto_pedestrian` 的 `max_locations` **硬写成 2**（多点多式联运没意义）；`centroid` 的 `max_locations > 127` 会直接抛异常。

### 9.2 `pedestrian` 额外两项（多式联运步行距离）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `service_limits.pedestrian.min_multimodal_walking_distance` | `1` | Minimum distance you must walk in a multimodal route that uses pedestrian costing | 多式联运里用 pedestrian costing 时必须步行的最小距离（米）。 |
| `service_limits.pedestrian.max_multimodal_walking_distance` | `10000` | Maximum distance allowed for walking in a multimodal route that uses pedestrian costing | 步行部分的最大距离（米）。 |

> 兼容点：源码里这两个键会**回退读取旧键名** `min_transit_walking_distance` / `max_transit_walking_distance`，老配置仍然生效。

### 9.3 其它 action 专属限额

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `service_limits.status.allow_verbose` | `false` | Allow verbose output for the /status endpoint, which can be computationally expensive | 是否允许 `/status` 输出 verbose 信息（计算代价高）。 |
| `service_limits.skadi.max_shape` | `750000` | Maximum number of input shapes | `/height` 等 skadi 接口允许的最大形状点数。 |
| `service_limits.skadi.min_resample` | `10.0` | Smalled resampling distance to allow in meters | 允许的最小重采样距离（米，原文 “Smalled” 是笔误）。 |
| `service_limits.isochrone.max_contours` | `4` | Maximum number of input contours to allow | 最多几个等时圈。 |
| `service_limits.isochrone.max_time_contour` | `120` | Maximum time value for any one contour in minutes | 单个等时圈的最大时间（**分钟**）。 |
| `service_limits.isochrone.max_distance` | `25000.0` | Maximum b-line distance between all locations in meters | 等时圈请求里各点间的最大大圆距离（米）。 |
| `service_limits.isochrone.max_locations` | `1` | Maximum number of input locations | 等时圈输入点个数上限（默认只允许 1 个）。 |
| `service_limits.isochrone.max_distance_contour` | `200` | Maximum distance value for any one contour in kilometers | 单个等距圈的最大距离（**公里**）。 |
| `service_limits.trace.max_distance` | `200000.0` | Maximum input shape distance in meters | trace 输入轨迹的总长度上限（米）。 |
| `service_limits.trace.max_gps_accuracy` | `100.0` | Maximum input gps accuracy in meters | 输入允许的最大 GPS 精度值（米）。 |
| `service_limits.trace.max_search_radius` | `100.0` | Maximum upper bounds of the search radius in meters | 输入 `search_radius` 的上界（米）。 |
| `service_limits.trace.max_shape` | `16000` | Maximum number of input shape points | 输入轨迹点数量上限。 |
| `service_limits.trace.max_alternates` | `3` | Maximum number of alternate map matching | 允许返回的备选匹配置数。 |
| `service_limits.trace.max_alternates_shape` | `100` | Maximum number of input shape points when requesting multiple paths | 请求多条路径时允许的输入点数（比 `max_shape` 严格得多）。 |
| `service_limits.centroid.max_distance` | `200000.0` | Maximum b-line distance between any pair of locations in meters | centroid 请求中任意两点间的最大大圆距离（米）。 |
| `service_limits.centroid.max_locations` | `5` | Maximum number of input locations, 127 is a hard limit and cannot be increased in config | centroid 输入点上限；**127 是硬上限**，配置改大也没用（源码校验 >127 直接抛错）。 |

### 9.4 全局限额

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `service_limits.max_exclude_locations` | `50` | Maximum number of avoid locations to allow in a request | 请求里最多允许几个避让点（`avoid_locations`）。 |
| `service_limits.max_reachability` | `100` | Maximum reachability (number of nodes reachable) allowed on any one location | 单个 location 允许的最大 `minimum_reachability`。 |
| `service_limits.max_radius` | `200` | Maximum radius in meters allowed on any one location | 单个 location 允许的最大 `radius`（米）。 |
| `service_limits.max_timedep_distance` | `500000` | Maximum b-line distance between locations to allow a time-dependent route | 允许走时间依赖路由的最大大圆距离（米，默认 500 km；超了退回静态路由）。 |
| `service_limits.max_timedep_distance_matrix` | `0` | Maximum b-line distance between 2 most distant locations in meters to allow a time-dependent matrix | 允许走时间依赖矩阵的最大距离（米）；`0` = 禁止时间依赖矩阵。 |
| `service_limits.max_alternates` | `2` | Maximum number of alternate routes to allow in a request | 路由请求里最多允许几条备选路线。 |
| `service_limits.max_exclude_polygons_length` | `10000` | Maximum total perimeter of all exclude_polygons in meters | 所有 `exclude_polygons` 周长之和的上限（米）。 |
| `service_limits.min_linear_cost_factor` | `1` | Minimum allowed factor admissible for linear feature cost factors. Beware: low values approaching zero will render the A* heuristic unusable | 线性要素代价系数（`linear_cost_factors`）允许的最小值。**警告**：接近 0 会让 A* 启发式失效（退化成近乎穷举）。 |
| `service_limits.max_linear_cost_edges` | `50000` | Maximum total number of linear cost edges | 一次请求里线性代价边（带 `linear_cost_factors`）的总数上限。 |
| `service_limits.max_distance_disable_hierarchy_culling` | `0` | Maximum search distance allowed with hierarchy culling disabled | 允许关闭层级裁剪的最大搜索距离（米）；`0` = 不允许关。 |
| `service_limits.allow_hard_exclusions` | `false` | Whether hard exclusions, such as exclude_bridges, exclude_tunnels, exclude_tolls, exclude_highways or exclude_ferries are allowed on this server | 是否允许“硬排除”（`exclude_bridges` / `exclude_tunnels` / `exclude_tolls` / `exclude_highways` / `exclude_ferries`）。 |

### 9.5 `service_limits.hierarchy_limits` — 层级限制（16 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `hierarchy_limits.allow_modification` | `false` | Whether hierarchy limits can be modified via the request | 是否允许请求参数修改层级限制。**为 false 时，下面所有 request 覆盖都不生效**（源码读的就是这个开关）。 |
| `hierarchy_limits.costmatrix.max_allowed_up_transitions.1` / `.2` | `400` / `100` | The maximum up transitions for level 1 / 2. Values set via request parameters that exceed this value are clamped. Ignored if "allow_modifications" is set to false. | 各层“向上跳级”次数的**上限**；请求给的值超过就被 clamp 到该值。 |
| `hierarchy_limits.costmatrix.max_expand_within_distance.0` / `.1` / `.2` | `1e8` / `100000` / `5000` | The maximum distance in meters from which the origin/destination will be expanded on level 0 / 1 / 2. Values set via request parameters that exceed this value are clamped. Ignored if "allow_modifications" is set to false. | 起点/终点在各层扩展的最大距离（米），同样只做 clamp 上界。 |
| `hierarchy_limits.bidirectional_astar.max_allowed_up_transitions.1` / `.2` | `400` / `100` | （同上文案） | 作用于双向 A*。 |
| `hierarchy_limits.bidirectional_astar.max_expand_within_distance.0` / `.1` / `.2` | `1e8` / `20000` / `5000` | （同上文案） | 作用于双向 A*。 |
| `hierarchy_limits.unidirectional_astar.max_allowed_up_transitions.1` / `.2` | `400` / `100` | （同上文案） | 作用于单向 A*。 |
| `hierarchy_limits.unidirectional_astar.max_expand_within_distance.0` / `.1` / `.2` | `1e8` / `100000` / `5000` | （同上文案） | 作用于单向 A*。 |

> 注意这一节（`max_*`）与 `thor.<algo>.hierarchy_limits`（default 值）是**两套不同用途的配置**：`thor` 里的是算法默认值，`service_limits` 里的是允许请求覆盖时的上界。model 名必须与算法名严格一致（`costmatrix` / `bidirectional_astar` / `unidirectional_astar`），写错会静默回落到内置默认值。

---

## 10. `statsd` — 指标上报（5 项）

| 键 | 默认值 | help_text 原文 | 解释 |
|---|---|---|---|
| `statsd.host` | `<optional:str>` | The statsd host address | statsd 服务地址；不写 = 不上报指标。 |
| `statsd.port` | `8125` | The statsd port | statsd 端口（默认 8125）。 |
| `statsd.prefix` | `"valhalla"` | The statsd prefix to use for each metric | 每个指标名的前缀。 |
| `statsd.batch_size` | `500` | Approximate maximum size in bytes of each batch of stats to send to statsd | 每批上报的字节数上限（近似值）。 |
| `statsd.tags` | `<optional:list>` | List of tags to include with each metric | 随每个指标一起发送的 tag 列表。 |

---

## 附录 A：不属于 help_text 的 4 个命令行参数

`valhalla_build_config` 在遍历配置树之外，还单独注册了 4 个参数（它们的说明不在 `help_text` 里，列在这里以免遗漏）：

| 参数 | 说明 |
|---|---|
| `-m` / `--merge-config` | 与已有配置文件合并：**已有值保留**，只把新键加进去。 |
| `-o` / `--output` | 输出文件路径（不写则打到 stdout）。 |
| `-r` / `--remove-old [KEY ...]` | 合并时删除旧键：不带参数 = 删除所有新配置里没有的键；带参数（JSON 点号路径，如 `mjolnir.logging`）= 只删这些路径及其子树。 |
| `-p` / `--report` | 合并时打印变更报告（Added / Removed）。 |

```bash
# 升级配置时的典型用法：保留用户改动，同时补上新版本的键
python3 scripts/valhalla_build_config -m valhalla.json -o valhalla_new.json -p
```

## 附录 B：自查与同步

文章覆盖了 236 个叶子键，可用下面的脚本核对“文档是否漏项 / 脚本是否新增了键”：

```python
# 列出 scripts/valhalla_build_config 全部叶子键 + 默认值 + help_text
import importlib.machinery, importlib.util, json, sys
loader = importlib.machinery.SourceFileLoader("vbc", "scripts/valhalla_build_config")
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("vbc", loader))
sys.argv = ["valhalla_build_config"]; loader.exec_module(m)

def walk(tree, help_, path):
    if isinstance(tree, dict):
        for k, v in tree.items():
            walk(v, help_.get(k, {}), path + [k])
    else:
        d = "<optional:%s>" % tree.type.__name__ if isinstance(tree, m.Optional) else json.dumps(tree)
        print("%s\t%s\t%s" % (".".join(path), d, help_ if isinstance(help_, str) else "<MISSING>"))

walk(m.config, m.help_text, [])
```

> `MISSING` 表示该键在 `help_text` 里没有说明（本节写作时 0 个）；新增配置项时记得同步在 `help_text` 里补一句话。

## 附录 C：本节涉及的源码位置

| 内容 | 位置 |
|---|---|
| 配置树 / help_text / 命令行参数 | `scripts/valhalla_build_config` |
| meili 参数实际读取 | `valhalla/meili/config.h`、`src/meili/config.cc`、`src/meili/map_matcher_factory.cc` |
| 运行期瓦片缓存策略 | `src/baldr/graphreader.cc`（`TileCacheFactory::createTileCache`） |
| service_limits 解析与 clamp | `src/loki/worker.cc`、`src/thor/worker.cc`、`src/worker.cc` |
| 矩阵算法选择 | `src/thor/matrix_action.cc`（`get_matrix_algorithm`） |
| 图过滤/聚合（`include_*` 的影响） | `src/mjolnir/graphfilter.cc` |


====================================================

# ch03. thor.extended_search 详解（Valhalla Bidirectional A*）
> 配置项：`thor.extended_search: true`
> 核心逻辑：**双向A*其中一侧搜索耗尽，但该侧起点落在 `not_thru` / closed 边上 → 允许另一侧继续扩展，不直接判定无路**，用来修复“假无路”误判。

## 背景：双向A*默认行为（extended_search=false）
Valhalla Thor 默认双向A*：
- 正向树（起点向外搜）、反向树（终点向外搜）交替扩展
- 只要**其中一侧优先搜空（没有可扩展节点）**，算法直接停止，返回 `no path`

### 坑场景（你描述的case）
起点被snap到一条 **not_thru 边**（死胡同/内部小区路，只有进没有出，Mjolnir打标记）或者临时closed封闭边：
1. 正向搜索从这条not_thru起点往外扩展，很快就没有后继边，**正向队列直接耗尽**
2. 默认逻辑：一侧耗尽 → 直接判定没有路线
3. 但真实情况：只是**起点贴在了死胡同边**，人/车可以先从not_thru边退回到主路，再去往终点；反向树其实还有很大搜索空间
→ 产生**假的无路（false no path）**

> `not_thru edge`：Mjolnir图增强阶段标记的“非贯通道路”，典型：小区内部路、死胡同，图算法默认会做剪枝，防止路由穿入死胡同绕路。

## thor.extended_search = true 做了什么
开启后修改双向A*终止条件：
> 如果耗尽的这一侧**起点本身位于 not_thru / closed 边上**，不触发全局终止；**保留另一侧（还活着的搜索树）继续单独单向搜索**，直到代价/距离上限。

简单一句话：
> 起点落在死胡同上导致正向搜死，不要直接返回无路；改用**单向A*继续从终点那一侧向外搜索**，看能不能连通。

### 边界区分（很关键）
- ✅ 满足条件：耗尽侧**起点位置**是not_thru / closed → 允许另一侧继续搜
- ❌ 不满足：耗尽侧起点在正常贯通道路，单纯路网断开 → 仍然直接返回no path，不会延长搜索

## 代价与取舍
优点：
- 大幅减少起点/终点落在小区死胡同、封闭路段时的**假无路径报错**，步行/驾车多场景更鲁棒

缺点：
- 开启后最坏情况会退化成**单向A***，搜索空间变大，**耗时、内存开销上升**
- 会绕过not_thru剪枝保护，个别场景可能算出“需要开进死胡同再倒出来”的路线，需要业务层做后处理过滤

## 典型适用场景
- Meili地图匹配后生成route、轨迹起点落在小区内部死路
- 步行路由（大量not_thru的园区/小区小路）
- GTFS公交+步行多模式规划，步行起点卡在断头路

## 相关配套参数
一般和它配合调的：
```json
"thor": {
  "extended_search": true,
  "max_astar_distance": 50000,
  "max_astar_time": 1800
}
```
> 单向继续搜索仍然受 `max_astar_distance` / `max_astar_time` 硬上限保护，防止无限搜索。

## 源码对应位置（快速定位）
`src/thor/bidirectional_astar.cc`
在双向搜索主循环判断：forward exhausted / reverse exhausted，然后判断起点edge属性，决定是否进入extended单向搜索分支。
对应github fix：#2936，就是专门修复“一侧耗尽直接中止导致假无路”的这个问题。

如果你想，我可以给一段极简伪代码，展示BidirectionalA*开启extended_search前后的终止判断差异。
