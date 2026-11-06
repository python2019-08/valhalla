# 1.valhalla 源码编译结果
```sh
(base) a@a:~/valhalla$ ls build_vcpkg/valhalla*  -l
-rwxrwxr-x 1 abner abner    826128 Sep  4 17:32 build_vcpkg/valhalla_add_elevation
-rwxrwxr-x 1 abner abner 186017672 Sep  4 17:32 build_vcpkg/valhalla_add_landmarks
-rwxrwxr-x 1 abner abner 184864048 Sep  4 17:32 build_vcpkg/valhalla_add_predicted_traffic
-rwxrwxr-x 1 abner abner 184820688 Sep  4 17:32 build_vcpkg/valhalla_assign_speeds
-rwxrwxr-x 1 abner abner 175706752 Sep  4 17:32 build_vcpkg/valhalla_benchmark_admins
-rwxrwxr-x 1 abner abner 180411760 Sep  4 17:32 build_vcpkg/valhalla_build_admins
-rwxrwxr-x 1 abner abner     50711 Sep  4 17:23 build_vcpkg/valhalla_build_config
-rwxrwxr-x 1 abner abner  23230920 Sep  4 17:32 build_vcpkg/valhalla_build_connectivity
-rwxrwxr-x 1 abner abner     12829 Sep  4 17:23 build_vcpkg/valhalla_build_elevation
-rwxrwxr-x 1 abner abner     19784 Sep  4 17:23 build_vcpkg/valhalla_build_extract
-rwxrwxr-x 1 abner abner 186023952 Sep  4 17:32 build_vcpkg/valhalla_build_landmarks
-rwxrwxr-x 1 abner abner 175966960 Sep  4 17:32 build_vcpkg/valhalla_build_statistics
-rwxrwxr-x 1 abner abner 184801200 Sep  4 17:32 build_vcpkg/valhalla_build_tiles
-rwxrwxr-x 1 abner abner      1647 Sep  4 17:23 build_vcpkg/valhalla_build_timezones
-rwxrwxr-x 1 abner abner 185627384 Sep  4 17:32 build_vcpkg/valhalla_convert_transit
-rwxrwxr-x 1 abner abner  22956176 Sep  4 17:32 build_vcpkg/valhalla_expand_bounding_box
-rwxrwxr-x 1 abner abner  22975520 Sep  4 17:32 build_vcpkg/valhalla_export_edges
-rwxrwxr-x 1 abner abner   5372664 Sep  4 17:32 build_vcpkg/valhalla_ingest_transit
-rwxrwxr-x 1 abner abner  29743528 Sep  4 17:32 build_vcpkg/valhalla_loki_worker
-rwxrwxr-x 1 abner abner  28650056 Sep  4 17:32 build_vcpkg/valhalla_odin_worker
-rwxrwxr-x 1 abner abner   4898184 Sep  4 17:32 build_vcpkg/valhalla_query_transit
-rwxrwxr-x 1 abner abner  53683144 Sep  4 17:32 build_vcpkg/valhalla_service
-rwxrwxr-x 1 abner abner  50182952 Sep  4 17:32 build_vcpkg/valhalla_thor_worker
-rw-rw-r-- 1 abner abner      2940 Sep  4 17:23 build_vcpkg/valhalla_uninstall.cmake//
-rwxrwxr-x 1 abner abner 184929336 Sep  4 17:32 build_vcpkg/valhalla_validate_transit
-rwxrwxr-x 1 abner abner  22966016 Sep  4 17:32 build_vcpkg/valhalla_ways_to_edges
```
🎉 **编译成功！全部工具二进制都生成出来了**。

> 
> 注意：你看到有 `valhalla_service`，说明这次编译 `ENABLE_SERVICES=ON` 生效了；同时也有 `valhalla_build_elevation`，代表 GDAL 也编译进去了。

## 关键工具快速解释（对你机器人项目最重要几个）

| 二进制 | 作用 |
| ------------------------- | ---------------------------- |
| **valhalla_build_config** | 生成valhalla.json配置文件，必用 |
| **valhalla_build_tiles**  | **核心**：把osm.pbf → valhalla_tiles.tar瓦片图库 |
| **valhalla_build_admins** | 构建行政区数据库，处理环岛、转向、国界惩罚，强烈建议跑 |
| **valhalla_build_elevation** | skadi高程瓦片构建工具（Elevation高程） |
| **valhalla_export_edges**    | 导出路网边，调试看osm标签映射结果，排错神器 |
| **valhalla_ways_to_edges**   | 把geojson自定义路网转valhalla边，适合园区自定义路网 |
| **valhalla_service**         | HTTP服务程序（ENABLE_SERVICES=ON才会有） |

> 
> 其余带`transit`是公交相关；`landmarks`是地标加速；`predicted_traffic`是预测交通，机器人场景基本用不到。

## 第一步：生成配置文件 valhalla.json

```sh
./build_vcpkg/valhalla_build_config > valhalla.json
```

打开valhalla.json，重点几个字段：

1. `mjolnir.tile_dir`：后续放 `valhalla_tiles.tar` 的路径
2. `mjolnir.admin`：valhalla_build_admins生成的sqlite数据库路径
3. `elevation.tile_dir`：skadi高程瓦片目录，**暂时不用高程可以注释掉这个块**

## 最简完整工作流（小区域OSM测试）

1. 下载一小块 osm.pbf（geofabrik，比如一个小城市）
2. 生成admin数据库（可选但强烈推荐）

```sh
./build_vcpkg/valhalla_build_admins --out admin.sqlite
```

3. 构建瓦片

```sh
./build_vcpkg/valhalla_build_tiles -c valhalla.json your_area.osm.pbf
```

输出会生成 `valhalla_tiles.tar`。

> 
> 注意：如果你**暂时不用高程**，valhalla.json里面把整个`"elevation": {...}`节点删掉，否则启动Actor会报找不到高程瓦片。

## 两种运行模式

### 模式1：HTTP服务（valhalla_service）

```sh
./build_vcpkg/valhalla_service valhalla.json 8002
```

然后可以请求 `/route` / `/isochrone` 等接口。

### 模式2：C++ Actor库模式（你的机器人核心使用方式，不启动http）

不需要运行valhalla_service可执行文件。
链接 `libvalhalla.a`，代码内直接：

```cpp
#include "valhalla/actor/actor.h"
#include <nlohmann/json.hpp>

int main(){
  valhalla::actor::Actor actor("valhalla.json");
  nlohmann::json req = {
    {"locations", {{{"lat",39.9},{"lon",116.4}}, {{"lat",39.91},{"lon",116.41}}}},
    {"costing","auto"}
  };
  auto res = actor.route(req.dump());
  return 0;
}
```

## 检查库文件位置

静态库一般在：

```sh
ls build_vcpkg/lib/libvalhalla*.a
```

## 踩坑提醒

1. 瓦片版本和二进制版本必须严格匹配，旧的valhalla_tiles.tar不能拿来用。
2. 如果你现在不准备玩高程，**务必删除valhalla.json的elevation配置块**，否则Actor初始化报错。
3. admin.sqlite建议生成，否则环岛、转向限制会有路由bug。

如果你需要，我可以给一份**最小可编译的CMakeLists.txt示例**，演示外部项目如何链接libvalhalla.a，调用Actor做路径规划。