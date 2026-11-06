# ch01.Valhalla 里 Boost.Geometry 的几何类型别名定义

```cpp
// 平面坐标系（笛卡尔 XY，投影坐标，不是经纬度）
using linestring_2d_t = boost::geometry::model::linestring<valhalla::midgard::Point2d>;
using multilinestring_2d_t = boost::geometry::model::multi_linestring<linestring_2d_t>;
using ring_2d_t = boost::geometry::model::ring<valhalla::midgard::Point2d>;
using polygon_2d_t = boost::geometry::model::polygon<valhalla::midgard::Point2d>;
using multipolygon_2d_t = boost::geometry::model::multi_polygon<polygon_2d_t>;

// 地理坐标系（经纬度 WGS84，lon/lat，球面）
using linestring_ll_t = boost::geometry::model::linestring<valhalla::midgard::PointLL>;
using multilinestring_ll_t = boost::geometry::model::multi_linestring<linestring_ll_t>;
using ring_ll_t = boost::geometry::model::ring<valhalla::midgard::PointLL>;
using polygon_ll_t = boost::geometry::model::polygon<valhalla::midgard::PointLL>;
using multipolygon_ll_t = boost::geometry::model::multi_polygon<polygon_ll_t>;
```

## 两类点的区别（Midgard 核心）

1. **`PointLL`**：Longitude/Latitude，**WGS84 经纬度**
   - 单位：度（°）
   - 用于原始OSM数据、PBF读取、存入SpatiaLite `admins.geom`（4326）
   - `multipolygon_ll_t`：就是行政边界、国家/城市面，**BuildAdminFromPBF 输出的几何就是这个类型**
2. **`Point2d`**：投影后的平面笛卡尔坐标
   - 单位：米（投影后）
   - 用于距离计算、交点、多边形裁剪、Boost.Geometry 空间运算（平面几何更快）
   - 做空间判断前，Valhalla 会把经纬度几何投影到平面，转成 `multipolygon_2d_t`

## Boost.Geometry 几何模型含义

| 类型 | 含义 | 场景 |
| --- | --- | --- |
| `linestring` | 线串：有序点序列 | 道路、边界线 |
| `multi_linestring` | 多线串：多条独立线 | 断裂的边界 |
| `ring` | 环（闭合线），多边形外环/内环（洞） | 行政面的外轮廓、内部空洞 |
| `polygon` | 单个多边形：1个外环 + 0~N个内环（洞） | 单个行政区（无多块飞地） |
| `multi_polygon` | 多多边形：一组独立多边形 | **行政区最常用！包含飞地、零散岛屿，OSM admin relation基本都解析成 multipolygon** |

> 
> `ring` 有个特性：boost::geometry::ring **自动保证闭合**，首尾点一致。

## 和你 admin.sqlite 的关联

- `multipolygon_ll_t`（C++内存里） → 序列化 → SpatiaLite `MULTIPOLYGON(4326)` 存入 `admins.geom`
- `valhalla_build_admins` 内部：
  1. 读取OSM relation（boundary=administrative）
  2. 组装节点 → 构建 `ring_ll_t`，组装成 `multipolygon_ll_t`
  3. **几何校验**：如果环不闭合、自相交、拓扑破损 → 直接丢弃，不插入admins表（就是你现在admins count=0最常见原因）
  4. 序列化几何写入sqlite

## Boost.Geometry 这里的坑（Valhalla mjolnir大量踩）

1. **经纬度球面运算和平面运算不能混用**
   - `multipolygon_ll_t` 做 `within/intersects` 是球面算法；
   - `multipolygon_2d_t` 是平面笛卡尔算法；
   - 混用会得到完全错误距离/相交结果。
2. `multi_polygon` 拓扑校验严格
OSM relation 经常出现：环方向错误、自相交、重复点、未闭合环。Boost.Geometry `is_valid()` 返回 false，Valhalla 直接跳过这条admin，**不报错静默丢弃**，这就是你现在admins为空头号嫌疑人。
3. 类型转换开销
`multipolygon_ll_t` ↔ `multipolygon_2d_t` 需要投影变换，大量行政区时CPU开销明显。

## 对应 BuildAdminFromPBF 的伪代码示意

```cpp
// 从PBF解析OSM relation，组装多多边形（经纬度）
multipolygon_ll_t admin_geom;
if (!build_multipolygon_from_relation(osm_relation, admin_geom)) {
  // 几何构建失败，直接跳过，不入库
  continue;
}
// 校验几何合法性
if (!boost::geometry::is_valid(admin_geom)) {
  // 非法几何，丢弃
  continue;
}
// 序列化几何写入 admins.geom (MULTIPOLYGON 4326)
insert_admin(admin_geom, admin_level, name, country_code);
```

如果你需要，我可以贴一段 Valhalla mjolnir 里**几何合法性校验、修复破损 ring** 的代码片段。

=======================================

# ch02.# 一句话核心结论

**Valhalla 在 `BuildAdminFromPBF` 阶段，完全不用 earcut 做三角剖分！**
`multipolygon_ll_t`（带洞、非凸、多多边形）**原样保留环结构（外环+内环洞）**，交给 **Boost.Geometry** 原生直接做点-in-polygon、相交判断；earcut 是**等值面(isochrone)模块**才会用到，**行政边界处理不走 earcut**。

> 
> earcut 的用途：把多边形拆成一堆三角形，多用于渲染/等值面生成。
> 但是 Valhalla 判断“路网节点落在哪个行政区”，不需要拆三角，直接用完整的 `multi_polygon<PointLL>` 拓扑结构。

## 1. Boost.Geometry 对带洞多边形的原生模型（正好对应你前面的类型别名）

```
polygon_ll_t
{
  ring_type outer;       // 外环（逆时针）
  std::vector<ring_type> inners; // 多个内环，就是洞（顺时针）
};
multipolygon_ll_t = std::vector<polygon_ll_t>; // 多个独立面（飞地）
```

Boost.Geometry 原生就支持：

- 非凸外环
- 任意数量内环（洞）
- `within(point, multipolygon)`：点是否落在行政区内（自动忽略洞内部）
- `intersects(linestring, multipolygon)`：道路边是否穿过行政区边界

**不需要拆三角！** BG 的算法直接基于环的缠绕顺序、射线法完成点面判断。

## 2. valhalla_build_admins 对 OSM admin relation 的处理流程

1. 解析 OSM relation，组装 `ring_ll_t`：外环、所有内环（洞）
2. **标准化环方向**（Boost.Geometry 强制要求：外环逆时针，洞顺时针），OSM relation 的环方向经常乱，这里会做 `reverse`
3. 调用 `boost::geometry::is_valid()` 校验几何合法性
   - ❌ 自相交、环方向错误、重复点、环不闭合 → **直接丢弃这条admin（就是你admins表0行的头号原因）**
4. 合法的 `multipolygon_ll_t` 直接序列化为 SpatiaLite `MULTIPOLYGON(4326)` 存入 `admins.geom`，**不做三角剖分**

> 
> 存入 sqlite 的仍然是原始多多边形（带洞），不是三角形集合。

## 3. 后续 mjolnir build_tiles 阶段怎么用这个 admin.sqlite？

当构建瓦片图时：

- 取出路网节点（PointLL）
- 用 SpatiaLite R树索引快速粗筛候选行政区（`ST_Intersects`）
- 取出候选行政区的 `multipolygon_ll_t`，调用 Boost.Geometry `within(point, admin_poly)` 精确判断归属
- 给路网edge打上 country / admin_level / driving side（左/右行）标记

> 
> 空间索引（R树）只是**包围盒加速过滤**，精确判断仍然是Boost.Geometry的完整多边形环运算，**没有三角化**。

## 4. Valhalla 里 earcut.cpp 在哪里被使用？

earcut **不在 mjolnir admin 流程**，而是在 **isochrone（等时圈）**：
等时圈输出的是复杂非凸多边形，为了简化、做可视化面输出，才用 earcut 对生成的等时面三角剖分。行政边界完全不走这个分支。

## 5. 对比：两种方案取舍

| 方案 | 适用场景 | Valhalla admin |
| --- | --- | --- |
| 保留完整 `multipolygon`（外环+洞），Boost.Geometry射线法点面判断 | 行政区、边界查询，需要保留拓扑含义 | ✅ 采用 |
| earcut三角剖分拆成一堆三角形 | 渲染、等值面、GPU、大量并行点采样 | ❌ admin不用；isochrone才用 |

## 6. Boost.Geometry 这里的坑（和你当前空admins直接相关）

Boost.Geometry 的 `is_valid()` 对多边形拓扑要求非常严格：

1. 环必须闭合
2. 外环/内环缠绕方向必须正确
3. 内环必须完全落在外环内部，不能和外环相交、不能跨洞
4. 环不能自相交，不能重叠

OSM administrative relation 大量几何不满足上面，**BuildAdminFromPBF 直接 silent skip，不写日志报错，admins表就0行**。

> 
> 很多人误以为 earcut 可以修复破损多边形；不行，earcut 对自相交几何一样会出错。Valhalla 策略是：**几何不合法直接丢弃，不尝试自动修复**。

## 7. 补充：那什么时候才需要把带洞多边形拆凸多边形？

如果不用 Boost.Geometry，自己手写点-in-polygon，没有现成支持内环洞的库，才会 earcut / polygon triangulation，拆成简单三角形，用点在三角形内判断。Valhalla 不需要，因为 BG 原生支持带洞 multi_polygon。

如果你想，我可以贴一段简化代码：**BuildAdminFromPBF 里面组装 multipolygon_ll_t + 环方向修正 + is_valid 校验** 的伪代码。