# 1.Valhalla（OSM路由引擎）官方Github

## 下载代码库
### **主仓库**
```
https://github.com/valhalla/valhalla
```

git clone 必须带子模块参数：
```bash
git clone --recurse-submodules https://github.com/valhalla/valhalla.git
```

不带`--recurse‑submodules`会缺失第三方依赖子模块
```sh
# > 不带`--recurse‑submodules`会缺失第三方依赖子模块，编译报错。
# 补充下载主仓库后第三方依赖子模块
cd valhalla
git submodule update --init --recursive
```
文档站点：https://valhalla.github.io/valhalla/


### 命令行同步 Tags 步骤
GitHub上 fork了 项目后，tags 没有fork过来.
```bash
# 0. 删掉刚刚配错的那个错误的 upstream 路径
# git remote remove upstream

# 1. 确保你本地已经添加了 valhalla 官方的原作仓库作为上游（upstream）
# 如果之前加过可以跳过这一步
git remote add upstream https://github.com/valhalla/valhalla.git

# 2. 从官方原作者仓库（upstream）中拉取所有的标签到你本地
git fetch upstream --tags

# 3. 切换到你本地要推送的分支（比如 main 或 master）
git checkout main

# 4. 把本地刚刚获取的所有 Tags，强行推送到你自己的 GitHub 远程仓库（origin）
git push origin --tags
```
执行完第 4 步后，刷新你自己的 GitHub 网页，点击 Tags 标签页，你就会发现官方的所有版本标签都已经成功同步过来了。



## 和OSRM关键差异（针对你的工业园区场景）
1. **瓦片式存储**：把路网切成分辨率可变的地理瓦片（mbtiles风格）。
> 园区新增/修改道路：只重新build受影响的**少数瓦片**，不需要重建整个城市全图，这是对你最有价值的特性。
2. API是JSON POST，不是OSRM那种URL‑GET接口；输出格式可以兼容OSRM格式。
3. 原生支持：路径、isochrone、矩阵、地图匹配、TSP旅行商。
4. 没有类似OSRM‑customize的csv外部覆写；但**拓扑变更只重算局部瓦片**。

## 简单对比OSRM vs Valhalla（园区修路场景）
|项目|OSRM(CH/MLD)|Valhalla|
|---|---|---|
|存储|整张内存图，二进制大文件|地理瓦片集合，目录形式|
|拓扑变更（新修道路）|必须全量extract，大图很慢|仅重生成变更的瓦片，速度快|
|动态改边速度（不改动拓扑）|MLD+osrm‑customize，csv配置|运行时costing json参数，可动态调代价|
|编译依赖|boost,tbb等|boost,protobuf,czmq等，依赖更多|
|API|REST GET|默认POST JSON，也可兼容OSRM输出|

> 注意：Valhalla**不是银弹**：
- 瓦片粒度是地理网格，如果你修改的园区跨多个瓦片，则多个瓦片都要重建；
- 它没有真正的“热加载”，修改瓦片后需要重启valhalla_service；
- 学习成本比OSRM高，文档体量更大。

## 快速启动参考
```bash
# 编译
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
sudo make install

# 构建瓦片（输入pbf输出瓦片目录）
valhalla_build_tiles -c valhalla.json region.osm.pbf ./valhalla_tiles

# 启动http服务
valhalla_service valhalla.json 1
```

如果你需要，我可以简单对比一份：OSRM迁移Valhalla需要做哪些适配，以及工业园区场景下的build_tiles局部更新的命令示例。

=================================================
# 2.OSRM vs Valhalla：算法原理 + 算路效率对比
## OSRM 两套算法
### 1. CH（Contraction Hierarchies，收缩层次）
- **核心原理**：离线预处理阶段，迭代删除图节点，**预生成大量shortcut快捷边**；查询阶段双向Dijkstra，大量走预计算shortcut，极少遍历原始路网边。
- 预处理：`osrm‑extract` → `osrm‑contract`
- 查询：双向Dijkstra，只在层级图上搜索。
- 特点：
  - 查询极快：普通城市内路线 **1‑3ms**；大规模矩阵table接口性能碾压其他引擎。
  - 代价：**权重一旦改变，必须完整重contract**，大图耗时很长。
  - 缺点：一套CH产物只对应一套lua profile代价；不能运行时动态改cost。

### 2. MLD（Multi‑Level Dijkstra，多层迪杰斯特拉，CRP架构）
- **核心原理**：把路网图按**节点数量递归二分切分成多层cell**（不是地理面积）；拓扑结构和边权重解耦：
  1. partition：只处理图拓扑，一次性；
  2. customize：灌入边的速度/权重，可反复轻量执行，不需要重算拓扑。
- 预处理：`osrm‑extract` → `osrm‑partition` → `osrm‑customize`
- 查询：双向Dijkstra，跨cell分层搜索。
- 特点：
  - 查询速度略低于CH：**5‑10ms**，生产环境绝大多数业务感知不到差距。
  - 优势：仅修改边速度/阻断，只跑customize，不用重extract/partition。
  - 硬限制：**不能处理拓扑变更（新增/删除道路）**，拓扑变了必须全套重跑extract。

> OSRM两套算法共性：**所有代价模型离线预处理固化**；一个二进制产物只能一套cost；不能在http请求里动态切换卡车/小车/避让规则。

## Valhalla 算法体系（Thor模块）
Valhalla**没有CH/MLD这种大规模预计算shortcut的分层加速**。
- 核心：**双向A* + 道路等级分层剪枝（class hierarchy）**，**查询时实时算路，没有预生成shortcut**。
- 预处理：`valhalla_build_tiles`，输出地理瓦片，只做路网解析、道路等级标记、转向限制编码；**不预计算任何路径shortcut**。
- 查询流程：
  1. 双向A*，欧氏距离做启发函数；
  2. 利用道路等级分层：远距离搜索自动上浮到高等级道路（高速、主干道），减少搜索空间；临近起终点再下沉到本地小路；
  3. 可以在**每一次HTTP请求JSON参数内动态修改costing**：调整限速、避让、卡车限重、避开轮渡等，不需要重建数据。

> 重要区分：Valhalla的hierarchy是**道路属性等级**，不是OSRM‑CH那种预生成shortcut的收缩层次；瓦片是**地理存储格式**，不是算法加速shortcut。

### Valhalla关键能力对你工业园区场景
1. **瓦片存储：拓扑变更只重生成受影响的瓦片**；园区新修道路，只重新build园区覆盖的少量瓦片，不用重建整个城市全图。
2. 代价完全运行时：同一个服务实例，同一份瓦片，请求参数切换小车、货车、避让厂区某些道路。
3. 代价：查询耗时更高；城市内路线典型 **20‑80ms**；长距离会到百ms级别。

## 实测性能参考（现代x86服务器，城市规模数据集）
|引擎|算法|单条路线耗时|大规模矩阵(table)|拓扑变更代价|修改边权重代价|
|---|---|---|---|---|---|
|OSRM|CH|1‑3ms|⭐⭐⭐⭐⭐极快，千对矩阵毫秒级|必须完整extract+contract，大图很慢|必须完整contract|
|OSRM|MLD|5‑10ms|⭐⭐⭐⭐快|必须完整extract+partition+customize|仅customize，轻量|
|Valhalla|双向A*+道路等级剪枝|20‑80ms|⭐⭐一般，矩阵请求压力大|仅重生成受影响瓦片|直接请求参数动态改，无需重建|

> 注意：Valhalla的矩阵接口不适合超大矩阵（几百上千点），QPS上来CPU压力明显高于OSRM。

## 架构层面关键差异（针对你的工业园区项目）
### OSRM
✅优点
1. 查询延迟极低，高并发、大量矩阵任务首选；
2. C++高度优化，内存访问高效。

❌短板
1. **拓扑（修路、删路）没有增量更新**，只要道路变了，全量extract；城市大图耗时久；
2. MLD的customize只能改已有边speed，依赖nodeID，维护csv繁琐；
3. 代价模型编译固化到产物，不能单请求动态切换货车/小车规则。

> 适合：厂区道路很少改扩建；追求高QPS、大量矩阵计算。

### Valhalla
✅优点
1. **地理瓦片增量构建：园区修路，只重算园区瓦片，不用重建全城市**，完美匹配厂区经常改扩建场景；
2. costing完全运行时：同一个服务，API参数动态调整限速、避让、货车限制，不用重建数据；
3. 原生支持卡车宽/高/重限制、isochrone等能力。

❌短板
1. 查询延迟显著高于OSRM；大矩阵性能弱；
2. 依赖库更多，编译部署更复杂；
3. 瓦片修改后，依然要重启服务才能加载新瓦片，**不是真正热加载**。

> 适合：园区会频繁新增/废除道路；需要多套代价模型（小车、厂区货车）。

## 选型建议（你的场景：城市+工业园区，会修新路、关旧路）
1. 如果厂区**改扩建频率很低（按月/季度），并发高、大量矩阵计算**：继续OSRM MLD流水线。
    - 临时管控大门、临时封路：osrm‑customize；
    - 真正修路拓扑改动：接受完整重建流水线，蓝绿部署切换。
2. 如果**厂区经常改扩建（几周就有道路变化），矩阵请求不多，能接受几十ms级别延迟**：迁移Valhalla收益更大，瓦片局部重建大幅降低数据更新成本。

### 容易混淆的误区澄清
1. ❌Valhalla瓦片 ≠ MLD的cell
    - MLD cell：**拓扑节点划分，和地理无关**，用于MLD分层Dijkstra查询加速；
    - Valhalla瓦片：**地理网格存储单元**，用于数据分片、局部重建，查询算法本身不依赖瓦片做路径加速。
2. ❌OSRM‑CH/MLD预生成shortcut；Valhalla**没有任何shortcut**，每一次路由都实时A*搜索。
3. ❌Valhalla不能热加载瓦片：更新瓦片文件之后，必须重启valhalla_service。

如果你需要，我可以整理一份OSRM迁移Valhalla的要点清单：包括pbf处理、瓦片构建、API参数对照、polyline输出、map‑matching地图匹配。

================================================
# ch03.valhalla 的源码子目录 都用北欧神话名字命名，不直观

确实是痛点，**北欧神话命名体系很有仪式感，但对新人极不直观**，很多人刚下源码完全记不住谁是干嘛的。我给你一张对照表，把名字、神话角色、实际职责放一起：

| 目录名       | 北欧角色      | 实际模块功能                      | 直白别名参考 |
|-------------|--------------|---------------------------------|---|
| **midgard** | 中庭，人类世界   | 基础几何、地理算法（距离、相交、投影） | geo / geometry |
| **baldr**   | 巴德尔，光明之神 | Tile 图的基础数据结构、缓存、瓦片IO   | tile_storage |
| **sif**     | 西芙，索尔妻子   | 代价函数（costing），路权、限速、通行成本 | costing |
| **skadi**   | 斯卡迪，雪/山女神 | 高程数据读取、海拔相关计算             | elevation |
| **mjolnir** | 雷神之锤        | OSM原始数据 → 路由瓦片（图构建、预处理） | graph_builder |
| **loki**    | 洛基    | 定位/搜点，把经纬度贴到边上（location correlate） | loki = locate |
| **meili**   | 梅里    | 轨迹匹配 map-matching        | mapmatch |
| **thor**    | 索尔雷神 | 核心寻路，分层Dijkstra生成路径 | routing_core |
| **odin**    | 奥丁     | 路径生成转向指令、叙事引导文字（指路文案）     | directions / narrative |
| **tyr**     | 提尔，战神 | HTTP服务层，对外API入口、序列化、路由请求分发 | http_server / api |

### 完整调用链路（记这个最有用）
`Tyr`（接收请求） → `Loki`（把点粘到路网） → `Thor`（算路径） → `Odin`（生成转向说明）；
建数据的时候走：`Mjolnir`（从OSM造瓦片），`Skadi`（灌高程），`Sif`（代价模型）；
底层几何全部依赖 `Midgard`，瓦片读写靠 `Baldr`。

### 为什么他们要这么设计？
1. 主题统一：整个项目叫 Valhalla（英灵殿），所有模块都是殿里诸神/神器，早期团队喜欢这套设定；
2. 缩写彩蛋：**THOR = Tiled Hierarchical Open Routing**，**TYR = Take Your Route**，**ODIN = Open Directions and Improved Narrative**，名字同时是缩写梗，不是随便挑的神名；
3. 缺点就是你说的：**没有领域前置知识完全猜不出职责**，新人上手门槛高，文档又不能替代直觉。

### 你自己可以怎么降低痛苦
- 本地fork里可以做软链接：`ln -s midgard geometry`、`ln -s mjolnir builder`；
- 看代码优先按链路看，而不是按名字猜；
- 调试路由请求时，日志里出现这几个名字，就对应上面流水线。
