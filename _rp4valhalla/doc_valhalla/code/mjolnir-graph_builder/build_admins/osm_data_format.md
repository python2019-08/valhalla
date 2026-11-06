# ch01.OSM PBF（Protocolbuffer Binary Format，后缀 `.osm.pbf`）
OSM 的二进制存储格式，基于 Google Protobuf，**Valhalla 的 `valhalla_build_admins` / mjolnir 就是读取这种文件**，替代原始臃肿的 OSM XML。

> 核心：PBF 不是直接存经纬度浮点数，不是文本XML；是**分块二进制+zlib压缩+delta差分编码**，体积远小于XML，解析速度更快。

## 一、文件整体结构（块链式）
整个 PBF 文件是**连续重复的 FileBlock**：
```
FileBlock = [4字节大端长度] + BlobHeader(protobuf) + Blob(protobuf)
```
1. **BlobHeader**
    - `type`: `OSMHeader`（全局头部，文件开头仅1个） / `OSMData`（数据块，多个）
    - `datasize`: 后面Blob的字节大小
2. **Blob**：存放压缩后的原始数据（默认 zlib）
    - `zlib_data`: 压缩后的二进制（主流）
    - `raw`: 未压缩（极少）
    解压后得到 `HeaderBlock` / `PrimitiveBlock`

> 设计亮点：**块独立**，可以流式解析、不需要一次性加载整个pbf，大planet文件友好。

### 两种块类型
1. **OSMHeader（HeaderBlock）**：全局元信息
    - 支持的OSM版本、边界范围、可选的过滤标记
2. **OSMData（PrimitiveBlock）**：真正存放OSM实体，Valhalla重点读这个
    - `StringTable stringtable`：**字符串池，所有tag的key/value全部放这里，用下标索引，大幅省空间**
    - `repeated PrimitiveGroup primitivegroup`：一组OSM对象
    - `granularity=100`（默认）：坐标单位 `100 纳度`
      - 转换公式：`lon/lat = integer_value * granularity / 1e9`
      - 整数存储，不用double浮点数，压缩友好
    - `lat_offset / lon_offset`：坐标偏移量，进一步压缩
    - `date_granularity`：时间戳精度（毫秒）

#### PrimitiveGroup（一个组只能放一类对象）
```protobuf
message PrimitiveGroup {
  repeated Node nodes = 1;
  optional DenseNodes dense = 2; // 大规模节点，delta编码，PBF默认启用（最重要！）
  repeated Way ways = 3;
  repeated Relation relations = 4;
}
```

## 二、OSM三大实体（Node / Way / Relation，和你 valhalla_build_admins 强相关）
### 1. Node（点）
- id + 整数编码 lat/lon
- tags：标签；大量连续无标签节点会放进 `DenseNodes`（delta ID + delta坐标，压缩极强）
> DenseNodes 是PBF性能关键：连续node ID是差分存储，`id[i] = id[i-1] + delta`，坐标同理，整数很小。

### 2. Way（线/闭合面）
```protobuf
message Way {
  required int64 id = 1;
  repeated uint32 keys = 2 [packed=true]; // stringtable下标
  repeated uint32 vals = 3 [packed=true];
  repeated sint64 refs = 8 [packed=true]; // node id数组，delta编码！
}
```
- `refs`：节点ID列表，**delta差分编码**，只存差值，不是完整node id
- 闭合Way：首尾node id相同，可以表示简单多边形（不带洞）
- tags：`building=yes`、`natural=water` 这类

### 3. Relation（关系！**行政边界靠这个，就是你admins表0行的根源**）
```protobuf
message Relation {
  required int64 id =1;
  repeated uint32 keys=2;
  repeated uint32 vals=3;
  repeated sint64 memids=4 [packed=true]; // member id delta编码
  repeated MemberType types=5; // member类型：node/way/relation
  repeated string roles=6; // role: outer / inner
}
```
- members：成员列表，每个成员有：类型、id、**role角色**
- ✅ `role="outer"`：外环
- ✅ `role="inner"`：内环（洞）
> `boundary=administrative` 的 relation，就是行政边界；Valhalla `BuildAdminFromPBF` 专门遍历这种relation，组装 `multipolygon_ll_t`。
> 坑：OSM relation的成员顺序、环方向经常错乱、成员缺失，Boost.Geometry校验直接判定几何非法，**直接丢弃，不入库 → admins count=0**

## 三、PBF 压缩优化要点（为什么比XML小很多）
1. **StringTable字符串池**：所有tag key/value只存一次，全程用下标引用（比如 `boundary`、`administrative`）
2. **整数Delta编码**：node id、way ref、relation member id，只存和上一个的差值，数值很小，protobuf varint压缩效果极好
3. **坐标量化为整数**：经纬度不存double浮点数，放大成纳度整数
4. **DenseNodes**：批量节点，合并元数据，消除重复字段
5. **块级zlib压缩**：每个PrimitiveBlock单独压缩

## 四、和 Valhalla valhalla_build_admins 的完整链路
```
osm.pbf → libosmium / osm pbf parser →
遍历所有 Relation，筛选 tag: boundary=administrative
解析 relation members：outer/inner role → 组装 ring_ll_t
校验环方向、闭合性、几何合法性 boost::geometry::is_valid()
合法 → multipolygon_ll_t → 序列化存入 admin.sqlite admins.geom
非法 → 静默丢弃（你当前admins为空的核心原因）
```

## 五、常用工具（你环境直接可用）
```bash
# 查看pbf基础信息
osmium fileinfo your.pbf
# 统计relation数量，过滤行政边界
osmium tags-filter your.pbf r/boundary=administrative -o admins.pbf
# 提取区域（裁剪pbf）
osmium extract -b 116,39,117,40 your.pbf -o subset.pbf
```

## 六、PBF vs OSM XML对比
| | OSM PBF | OSM XML (.osm) |
|---|---|---|
| 存储 | 二进制Protobuf + zlib压缩 | 文本XML |
| 体积 | 约为bzip2 xml的50% | 大很多 |
| 解析 | 二进制流式解析，速度快 | 文本解析，慢，内存开销大 |
| 可读性 | 二进制不可读 | 文本可直接打开看 |
| 流行度 | OSM标准分发格式，Valhalla/OSRM全部用PBF | 仅调试、小数据 |

## 七、常见踩坑（对应你现在admins为空）
1. PBF裁剪时使用 `simple` 策略：**relation的部分way成员被裁掉，环不完整 → multipolygon构造失败**，osmium extract 默认simple，提取行政区建议用 `complete_ways`。
2. OSM relation几何本身破损：环自相交、环方向错误、inner环不在outer内部 → boost geometry is_valid=false，直接丢弃。
3. 小区域extract：有些城市extract根本不带 `boundary=administrative` relation，pbf里面就没有行政区数据。

如果你想，我可以继续讲：**libosmium 解析 relation 组装 multipolygon 的流程，以及 valhalla mjolnir 中处理 outer/inner ring 的源码逻辑**。

===============================================

# ch02.# OSM 三大核心实体：Node、Way、Relation
OSM（OpenStreetMap）所有地理信息全部由这三类对象构成，`.osm.pbf` / `.osm.xml` 里面只存这三样。
> 核心思想：**Node 是基础原子点；Way 串联 Node 构成线/面；Relation 把 Node/Way/其他 Relation 打包成复杂对象（多多边形、路线、行政边界）**。
> 结合你 Valhalla 的场景：**行政边界完全依赖 Relation，这也是你 `valhalla_build_admins` 提取数据的重点**。

## 1. Node（节点）—— 最基础单元
Node = **唯一ID + 经纬度坐标 + 可选标签 tags**
```
id: 12345
lat: 39.9042
lon: 116.4074
tags:
  name=天安门
  amenity=monument
```
### 关键点
1. 坐标：WGS84 (EPSG:4326)，经纬度。在PBF里不是直接存double，而是量化成整数做delta压缩。
2. tags（标签）：描述这个点是什么。
    - `amenity=shop` 商店；`traffic_sign=stop` 停车标志；`power=tower` 电塔。
    - **没有tag的Node，绝大多数只是构成道路/多边形的中间顶点，本身不代表任何POI**。
3. 生命周期：Way / Relation 引用 Node ID；**Node可以被多个Way共用**（路口，多条道路交汇点）。

> 重点：单纯 Node 只能表达点要素，**不能单独表达线和面**。线和面必须靠Way引用Node id列表。

---

## 2. Way（路径）—— 由一串Node ID有序串联而成
Way = **唯一ID + 有序Node ID列表 + 可选tags**
```
id: 54321
refs: [1001,1002,1003,1004,1001] # 首尾相同 → 闭合Way
tags:
  building=house
```
### 两种形态
1. **开放Way（首尾node id不一样）：线要素**
    道路、河流、围墙、公交路线。例如 `highway=primary` 主干道。
2. **闭合Way（首尾node id相同）：简单多边形**
    建筑、湖泊、小块绿地。⚠️ **闭合Way只能表示不带洞的单个简单多边形！不能表达带洞的面**。

### Way 的限制（非常重要）
✅ 适合：道路、河流、建筑（无洞）
❌ **Way 无法表达带洞的多边形；也无法表达由多个分离地块组成的多多边形（飞地）**
👉 这种复杂面，必须交给 **Relation**。

> 补充：OSM 规范不保证 Way 的 node 顺序的缠绕方向（顺时针/逆时针），读取时需要代码判断，Boost.Geometry 会要求统一方向，否则判定几何非法。

---

## 3. Relation（关系）—— 把多个对象打包成逻辑集合
Relation = **唯一ID + 成员列表(members) + 可选tags**
每一个成员包含三要素：
- `type`：成员类型：`node` / `way` / `relation`（支持嵌套关系）
- `ref`：成员对象ID
- `role`：**角色字符串，描述这个成员在关系里起什么作用**（可以为空）

```
id: 98765
tags:
  boundary=administrative
  admin_level=4
  name="江苏省"
members:
  type=way ref=10000 role=outer   # 外环
  type=way ref=10001 role=inner   # 内环，代表湖泊洞
  type=way ref=10002 role=outer   # 飞地，另一块独立外环
```

### role 角色含义（行政边界场景）
- `outer`：外环多边形边界
- `inner`：内环，代表多边形内部的空洞（比如行政区内部的大型湖泊不属于本区）
- 空role：普通成员，多用于路线、公交、路由关系，多多边形很少用

### Relation 的常用类型（`type=`标签）
1. `type=multipolygon`：多多边形关系（**行政边界本质就是这类Relation！**）
    - 允许多个独立外环（飞地），并且每个外环可以附带多个内环（洞）
    - 👉 这就是 Valhalla `BuildAdminFromPBF` 的目标对象！
    - 由一组Way组成，way提供环的几何，relation定义哪些是外环、哪些是洞。
2. `type=route`：路线（公交、铁路路线），把多条way拼成一条完整线路。
3. `type=restriction`：交通转向限制（禁止左转等），node+way组合表达路口规则。
4. `type=boundary`：老版本行政边界，现在规范推荐用 `type=multipolygon` + `boundary=administrative`。

### Relation 的巨大坑点（你 `admins` 表为空的核心来源）
1. **成员是引用ID，不是内嵌几何！**
Relation 只存 way id，**不存节点坐标**。解析的时候必须去查找对应的Way，再查找Way引用的Node。
> 如果PBF裁剪的时候，把Relation依赖的某个Way/Node裁掉了 → 环残缺，几何构建失败，直接丢弃。
> osmium extract 默认 `simple` 策略就会出现这个问题。提取行政区必须用 `complete_ways`。

2. 成员Way顺序不保证，outer/inner可以乱序，代码需要分组处理。
3. 单个Way本身可以是断裂、自相交、不闭合。
4. 拓扑错误：inner环不在outer内部、inner和outer相交、环方向错乱 → Boost.Geometry判定`is_valid=false`，valhalla直接跳过该行政区。

---

## 三者协作示例：一个带湖的行政区
1. Node：一堆经纬度点，构成轮廓顶点；
2. Way A：外环轮廓的节点序列（role=outer）；
3. Way B：湖泊边界的节点序列（role=inner）；
4. Relation：type=multipolygon，boundary=administrative，成员包含Way A、Way B；
    - Way A = 行政区外轮廓；Way B = 内部湖泊（洞）。
> 单独的Way无法表达“面里面挖掉一个洞”，必须用Relation。

## 三者对比简表
|实体|几何表达|标签用途|典型例子|
|---|---|---|---|
|Node|单个坐标点|描述点要素|POI、路口顶点、纪念碑|
|Way|有序点连成线/闭合简单面|描述线、无洞面|道路、建筑、河流|
|Relation|组合Node/Way/Relation，靠role定义逻辑关系|复杂几何、逻辑集合|行政边界（带洞/飞地）、公交路线、转向限制|

## 和 valhalla_build_admins 完整链路再串一遍
1. 遍历PBF里所有 `Relation`；
2. 筛选标签：`boundary=administrative`，一般附带 `type=multipolygon`；
3. 取出所有成员way，按role分成 outer 和 inner；
4. 读取每个way的node列表，拿到坐标，组装 `ring_ll_t`；
5. 校正环的缠绕方向，组装成 `multipolygon_ll_t`；
6. `boost::geometry::is_valid()`校验几何；
7. 合法：写入SpatiaLite admins表；非法：静默丢弃。

如果你想，我们可以继续：
1. 讲讲 OSM multipolygon relation 的规范（2.0 版本）；
2. 或者 libosmium 读取 relation、outer/inner 组装几何的源码逻辑。

============================================

# ch03. ✅ KIWI（日本KIWI-W车载导航地图标准，JIS D0810）
是的，KIWI 路网模型里，**一条 Link（道路边）由两类点构成：Node（拓扑结点，你说的 point） + Shape Point（形状点）**。
> 刚好可以拿来和 OSM 的模型做对比，非常适合你现在 Valhalla / OSM 的背景。

## 1. Node（拓扑结点，Topology Point）
- **位置**：Link 的起点 / 终点
- **拓扑意义**：路网的连接点；多条 Link 在这里交汇（路口、道路分叉、道路终点）
- **作用**：**路径规划（路由计算）依赖 Node**，决定图的连通性。路由图的顶点就是 Node。
- 一条 Link 一定有且仅有两个 Node：`start_node`、`end_node`

## 2. Shape Point（形状点）
- **位置**：放在 Link 的两个 Node **中间**，不属于拓扑结点，只用来描述道路的弯曲走向。
- **拓扑意义：无！** Shape Point 不分割 Link，**不会产生新的道路连接**。
- **作用**：**地图渲染、几何形状表达**，只负责把弯曲道路画平滑。路由计算时可以直接忽略形状点。
- 一条 Link 可以有 0、1、多个 Shape Point；直线道路可以没有形状点。

### 一句话总结 KIWI Link
> `Node ---[shape_point1, shape_point2...] --- Node`
> Node 负责**拓扑连通（寻路）**；ShapePoint 负责**几何外形（画图）**。

---

## 🆚 KIWI vs OSM（重点对比，承接刚才OSM三大实体）
OSM 的模型没有做这种严格区分：**OSM 的 Node 既是拓扑结点，又是形状顶点**
1. OSM Way：一串 Node ID，**列表里所有 Node 地位一样**
    - 路口点：同时是拓扑连接点
    - 道路中间弯曲点：也叫 Node，只是没有任何 tag
2. OSM 没有独立的“ShapePoint”类型。OSM 所有顶点都统一叫 Node。
> OSM 的缺点：寻路构建路网图的时候，你必须**遍历所有Way，找出真正路口Node（被≥2个Way共用的Node）**；剩下只属于单条Way、仅用于拐弯的Node，才等价于KIWI的ShapePoint。
> OSM 把拓扑点和形状点混在同一个实体里。
> KIWI 在数据模型层面直接分开存储两类点。

### 📌 举例子：一条弯曲的公路
**KIWI：**
- Node A（路口）
- ShapePoint1
- ShapePoint2
- Node B（下一个路口）
Link = A → [sp1, sp2] → B；路由图只保留 A-B，sp1/sp2 仅用于几何。

**OSM：**
Way: `[n1, n2, n3, n4]`
- n1：路口（被多条way共享，等价KIWI Node）
- n2,n3：道路弯曲点（只属于这一条way，等价KIWI ShapePoint）
- n4：路口（被多条way共享，等价KIWI Node）
OSM 全部都叫 Node，靠**是否被多个Way引用**来区分拓扑点/形状点。

### 3. KIWI 模型的优缺点
✅ 优点：
1. **寻路图和几何解耦**：路由计算只需要 Node 和 Link，不用遍历大量形状点，路由图体积小、速度快；
2. 几何单独存储，渲染和路径搜索两套逻辑分离，非常适合嵌入式车载导航。

❌ 缺点：
1. 同一位置要存两套坐标（Node坐标，ShapePoint坐标）；
2. 数据模型复杂，拓扑和几何需要同步维护；

### 4. 延伸：Valhalla 的瓦片模型是怎么做的？
Valhalla 内部瓦片（mjolnir生成的tile），**借鉴了类似KIWI的思想**：
- `Node`：路口结点（拓扑顶点）
- `Edge`：对应KIWI Link，Edge上附带 `shape` 点数组（就是OSM里那些仅用来拐弯的中间点）
> Edge 本身是图的边；shape点只保留几何，**不产生新的图顶点**。
> 也就是：Valhalla 构建路网图的时候，自动把OSM Node分成两类：拓扑结点（图顶点）+ 边上的形状点（仅几何）。等于把OSM混合模型，**转换成类似KIWI分离模型**。

如果你想，我可以继续对比：
KIWI / OSM / Valhalla 三者路网拓扑模型的完整对比表。

=================================

# ch04.libosmium 里如何区分node 和shapepoint的?



核心一句话: **libosmium 本身没有内置“区分拓扑Node / ShapePoint”的能力！**
OSM原生模型里所有点都叫 `osmium::Node`，libosmium只是读取PBF/XML，**不会自动标记哪个是拓扑路口点，哪个只是形状点**。

> 
> 这个区分是**上层业务代码（比如 Valhalla mjolnir）自己统计引用次数做出来的**，不是libosmium自带功能。

## 原理（对应KIWI模型对比）

KIWI是数据层面直接区分：Node（拓扑结点）、ShapePoint（仅几何）。
OSM所有顶点都是 `Node` 对象，存坐标；一条Way的node列表：

```
way.nodes() → [n1, n2, n3, n4, n5]
```

- n1、n5：Way首尾点
- n2,n3,n4：中间点

想要区分，必须**两遍遍历PBF**：

1. **第一遍遍历：统计每个Node ID被多少条highway way引用**
 用一个 `std::unordered_map<osmium::object_id_type, int> node_ref_count;`
 遍历所有 highway=* 的way，遍历way里所有node id，`node_ref_count[id]++`

> 
> 只统计路网way，建筑/水系/行政边界way不计入路网拓扑。

 判定规则（Valhalla/mjolnir就是这套逻辑）：
   - `node_ref_count[id] >= 2`：**拓扑结点（路口，等价KIWI Node）**，多条道路交汇
   - `node_ref_count[id] == 1`：**形状点（shape point，等价KIWI ShapePoint）**，只属于单一条道路，只用来描述弯曲，不产生路口
   - 特殊：Way的首尾点，就算引用计数=1（道路断头路终点），也视为拓扑结点（图顶点）
2. **第二遍遍历PBF：读取way，拆分拓扑点和边上的shape点**
 遍历way的node序列，逐个查 `node_ref_count`：
   - 拓扑点 → 作为Edge的起点/终点（图顶点）
   - 中间shape点 → 打包存入Edge的shape坐标数组，只保留几何，不作为图顶点

> 
> 👉 libosmium只负责把OSM objects读出来，**引用计数、拓扑判定全是业务代码实现**，libosmium没有这个API。

## libosmium相关API（你代码里会用到）

```
#include <osmium/handler.hpp>
#include <osmium/osm/way.hpp>
#include <osmium/osm/node.hpp>

// 遍历所有way，统计node引用次数
struct CountNodeRefHandler : public osmium::handler::Handler {
  std::unordered_map<osmium::object_id_type, int> ref_counts;

  void way(const osmium::Way& way) {
    // 只处理道路way，过滤建筑、行政边界等
    if (!way.tags().has_tag("highway")) return;
    for (const auto& nr : way.nodes()) {
      ref_counts[nr.ref()]++;
    }
  }
};
```

> 
> 注意：第一遍只统计ID计数，**不读取Node坐标**；第二遍再用 `osmium::LocationHandler` 加载node的经纬度。

## 边界坑点（Valhalla mjolnir处理时也要考虑）

1. **断头路（dead end）**
一条路只有单个way，首尾node引用计数=1。但首尾依然是图顶点（拓扑Node），中间点才是shape point。

> 
> 所以不能只靠 `ref_count >=2`，必须额外判断：**是否是way的首尾node**。
2. **同一个Node可以同时是路网拓扑点 + POI点**
路口node上面可以有 `traffic_sign` tag，它依然是拓扑结点。标签不影响拓扑判定。
3. **非道路way（building、administrative）**
建筑、湖泊、行政边界的way，里面的node**不参与路网拓扑统计**，这些点只属于几何顶点，不属于路网的拓扑点/shape点这套概念。
4. **OSM的relation里面的way**
比如行政边界multipolygon relation里面的way，解析几何时，**不需要做拓扑点/shape点拆分**，只需要完整组装ring。这就是你前面 `valhalla_build_admins` 的场景。

## 和 Valhalla mjolnir 的对应关系

Valhalla mjolnir 读取PBF的完整流程：

1. 第一遍libosmium handler遍历所有way，统计highway node引用次数
2. 第二遍读取node坐标、way，构建Edge
3. 对每条way的node序列：
   - 找出所有拓扑结点，作为Edge的端点
   - 两个相邻拓扑结点之间所有中间node → 全部变成Edge的shape点数组> 
   > 最终瓦片里的Edge就和KIWI的Link模型几乎一样：两端拓扑Node + 一串shape点。

## 小结

1. libosmium**不会自动区分拓扑Node和ShapePoint**，OSM里所有顶点都是`osmium::Node`。
2. 区分逻辑：**统计路网way对node id的引用次数，并且判断是否是way首尾点**。这是上层代码实现，不是libosmium内置能力。
3. 这个区分**只针对路网high way**；行政边界、建筑多边形的几何解析不需要这套逻辑，直接完整读取所有node坐标组装ring/polygon。

如果你需要，我可以写一段完整可编译的libosmium最小demo，实现：两遍PBF遍历，区分道路拓扑结点和shape点。