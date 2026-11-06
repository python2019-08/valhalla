
```cpp
* Information held for each node within the graph. The graph uses a forward
 * star structure: nodes point to the first outbound directed edge and each
 * directed edge points to the other end node of the edge.
 */
class NodeInfo {
public:

 // Organized into 8-byte words so structure will align to 8 byte boundaries.

  // 26 bits for lat,lon offset allows 7 digits of precision even in 4 degree tiles
  // to stay backwards compatible we have to break 6 digits and the 7th digit into two parts
uint64_t lat_offset_ : 22; // Latitude offset from tile base latitude in int 6 digit precision
uint64_t lat_offset7_ : 4; // Latitude offset 7th digit of precision
uint64_t lon_offset_ : 22; // Longitude offset from tile base longitude in int 6 digit precision
uint64_t lon_offset7_ : 4; // Longitude offset 7th digit of precision
uint64_t access_ : 12;     // Access through the node - bit field
 ...........
 };
 ```

 # 这段 C++ 位域（bit-field）代码解读
```cpp
class NodeInfo {
public:
  // 按8字节字排布，保证结构体8字节对齐
  // 26bit 存经纬度偏移，支持7位精度、4度瓦片；为兼容旧格式，把第6位、第7位拆开存储
  uint64_t lat_offset_ : 22;   // 瓦片基准纬度的偏移，6位整数精度
  uint64_t lat_offset7_ : 4;   // 纬度偏移的【第7位精度数字】
  uint64_t lon_offset_ : 22;   // 瓦片基准经度的偏移，6位整数精度
  uint64_t lon_offset7_ : 4;  // 经度偏移的【第7位精度数字】
  uint64_t access_ : 12;       // 节点通行属性，位掩码（bitfield）
  ...........
};
``` 

## 1. 经纬度精度怎么理解（核心难点）
注释原话：
> 26 bits for lat,lon offset allows 7 digits of precision even in 4 degree tiles
> to stay backwards compatible we have to break 6 digits and the 7th digit into two parts

地理坐标常用定点表示：
- 6位精度：`0.000001°` （百万分之一度）
- 7位精度：`0.0000001°`（千万分之一度）

设计拆分原因：**历史兼容**
老版本只存6位小数，新版本要升级到7位，但不想破坏旧存储布局：
1. `lat_offset_ / lon_offset_` 22 bit：存**前6位定点整数偏移**（`*1e6`）
2. `lat_offset7_ / lon_offset7_` 4 bit：单独存**第7位小数**（0~9，4bit足够放0–15）

👉 为什么26bit刚好够7位？
4°瓦片，最大偏移就是4度，放大到 1e7（7位）：`4 * 10^7 = 40,000,000`
26bit 最大值：$2^{26}-1 = 67,108,863$
4000万 < 6710万，空间足够放下4°范围内7位精度的偏移。
拆成 22+4：22bit 最多存 4,194,303，刚好容纳 4*1e6（6位：4,000,000），剩下4bit放额外的第7位。

## 2. access_ :12 — 通行位掩码
12个独立bit，每一位代表一种通行权限：
比如：机动车、自行车、行人、卡车、是否单向、是否收费、是否封闭等标志，Valhalla 里 `access` 枚举就是定义这12个位含义。
> bit field，不是数字，是一堆开关标志。

## 3. 注意坑（C++位域）
1. **位域的打包顺序是实现定义的！**（大端/小端编译器、平台会影响bit排布）
   Valhalla 这里是**明确自己控制bit布局，只在指定编译器下使用，不跨平台乱序列化**，如果直接memcpy序列化要小心跨平台。
2. 不能取位域成员的地址 `&node.lat_offset_`，位域没有内存地址。
3. 如果你想把坐标读出来，**不能直接拿lat_offset_当完整偏移，必须合并 xxx7_ 那4bit**，不然只有6位精度，丢了最后一位。

## 4. 简化示例伪代码（解码）
```cpp
// 解码纬度
uint32_t lat_full = node.lat_offset_ * 10 + node.lat_offset7_;
double lat = tile_base_lat + lat_full * 1e-7;

// 解码经度
uint32_t lon_full = node.lon_offset_ * 10 + node.lon_offset7_;
double lon = tile_base_lon + lon_full * 1e-7;
```

编码反过来：给定delta lat（相对于瓦片基准）
```cpp
uint64_t total = round(delta_lat * 1e7);
node.lat_offset_ = total / 10;
node.lat_offset7_ = total % 10;
```

## 6. 一句话总结
这是 Valhalla 路由里非常经典的**高密度地理定点压缩方案**：
用一个64bit整数打包瓦片内节点坐标（7位小数经纬度偏移，兼容老的6位格式）+ 12bit通行权限，用位域方便代码读写，省磁盘/内存。
 