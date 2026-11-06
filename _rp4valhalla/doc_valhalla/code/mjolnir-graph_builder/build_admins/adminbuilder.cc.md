<!-- src/mjolnir/adminbuilder.cc -->

# ch01.`SELECT InitSpatialMetaData(1);`（SpatiaLite）
> 拼写：`InitSpatialMetaData`（也写作 `InitSpatialMetadata`，两者都兼容）

## 参数区别
- `InitSpatialMetaData(1)`：Full，创建全套空间元数据表，并且导入完整 EPSG 投影定义（包含 4326 WGS84，Valhalla 必须用这个）
- `InitSpatialMetaData(0)`：Light，只放少量基础投影，省空间 

## 作用
这条SQL 只负责搭建空间数据库的“骨架”（元数据表、投影）。
执行这条SQL，会在当前sqlite库自动生成：
> 1. `geometry_columns`：记录哪些表有几何字段、类型、SRID
> 2. `spatial_ref_sys`：全部EPSG坐标系定义（WGS84:4326）
> 3. 一堆配套元数据表、视图、触发器（就是你 `.tables` 看到的 `vector_layers`、`views_geometry_columns` 等）

> ⚠️ **只需要新建数据库的时候执行一次！**
> 如果数据库已经初始化过空间元数据，再次运行会报错：`table spatial_ref_sys already exists`，可以忽略这个报错。
 

# ch02. SELECT AddGeometryColumn('admins', 'geom', 4326, 'MULTIPOLYGON', 2);

## 参数解释
```sql
AddGeometryColumn(
  'admins',        -- 表名
  'geom',          -- 几何字段名
  4326,            -- SRID: WGS84 (GPS经纬度，Valhalla固定用这个)
  'MULTIPOLYGON',  -- 几何类型，行政边界是多多边形
  2                -- 维度：2D (XY平面)
)
```
作用：
1. 在 `admins` 表增加 `geom` 几何字段
2. 在 `geometry_columns` 元数据表注册这个几何列
3. 自动创建触发器，用来维护空间索引（后面CreateSpatialIndex依赖）

> ⚠️ 前提条件：
> 1. 已经加载 mod_spatialite
> 2. `admins` 表已经存在
> 3. 还没有 `geom` 字段，重复执行会报错：`column geom already exists`

## 完整操作顺序（新建admin表场景）
```sql
-- 1.加载扩展
SELECT load_extension('mod_spatialite');
-- 2.初始化空间元数据（新建库才需要）
SELECT InitSpatialMetaData(1);
-- 3.建admins普通字段表
CREATE TABLE admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_level INTEGER,
  name TEXT,
  country_code TEXT
);
-- 4.添加几何字段（注册到geometry_columns）
-- AddGeometryColumn(
--   'admins',        -- 表名
--   'geom',          -- 几何字段名
--   4326,            -- SRID: WGS84 (GPS经纬度，Valhalla固定用这个)
--   'MULTIPOLYGON',  -- 几何类型，行政边界是多多边形
--   2                -- 维度：2D (XY平面)
-- )
SELECT AddGeometryColumn('admins', 'geom', 4326, 'MULTIPOLYGON', 2);

-- 5.插入数据后，构建R树空间索引
SELECT CreateSpatialIndex('admins', 'geom');
```


查看admins表结构，确认geom字段是否已经存在：
```sql
PRAGMA table_info(admins);
```