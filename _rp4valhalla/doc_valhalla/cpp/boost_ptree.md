# ch01.boost::property_tree::ptree

`ptree` 是 Boost.PropertyTree 库的核心类型，是**多层级树状配置容器**，本质是：

```cpp
typedef basic_ptree<std::string, std::string> ptree;
```

每个节点包含：自身字符串值 + 有序子节点列表（`key -> ptree`），专门用来加载/保存配置：JSON、XML、INI、INFO，**Valhalla 大量用它读取 json 配置**（你前面看到的 `BuildAdminFromPBF` 参数就是它）。

## ✅ 头文件

```cpp
#include <boost/property_tree/ptree.hpp>
// 读写json额外需要
#include <boost/property_tree/json_parser.hpp>
using namespace boost::property_tree;
```

## ✅ 核心常用API（Valhalla代码里高频出现）

1. **get(path)**：读取，找不到key抛异常 `ptree_bad_path`

```cpp
int threads = pt.get<int>("thor.extended_search");
```

2. **get(path, default_val)**：找不到key返回默认值，不抛异常

```cpp
bool extended = pt.get<bool>("thor.extended_search", false);
```

3. **get_child(path)**：取出子树（函数入参经常是这个）

```cpp
ptree child_pt = pt.get_child("mjolnir");
```

4. **put(path, value)**：写入配置节点

```
pt.put("thor.extended_search", true);
```

5. **get_child_optional**：安全判断节点是否存在，返回`optional`

路径分隔符默认是`.`，例如 `mjolnir.admin.db`

## ✅ Valhalla 场景对应

```cpp
valhalla::mjolnir::BuildAdminFromPBF(
    const ptree& config,
    const std::vector<std::string>& input_files
);
```

- `const ptree& config`：传入整个valhalla配置树（valhalla.json加载进来）
- 在函数内部，用 `config.get<T>("xxx")` 读取各个配置项，比如数据库路径、过滤参数等。

## ⚠️ ptree 的坑（踩坑重点）

1. **所有值底层存的都是字符串**，get是运行时类型转换，类型写错会抛 `ptree_bad_data`
2. **JSON数组支持弱**：数组本质是多个同名key，不是标准json数组模型，这是boost property_tree最被吐槽的点
3. 不支持注释：读JSON时，文件里注释会直接解析失败
4. key查找**区分大小写**

## ✅ 简单完整示例

```cpp
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <iostream>

using namespace boost::property_tree;

int main() {
  ptree cfg;
  read_json("valhalla.json", cfg);

  bool es = cfg.get<bool>("thor.extended_search", true);
  std::cout << es << std::endl;
  return 0;
}
```

## ✅ 和现代库对比

- ptree：老工具，API简单，JSON数组支持差，Valhalla历史原因一直用它
- nlohmann/json：现代C++ json库，原生完整JSON支持，现在新项目优先选

如果你想，我可以给一段 GDB 调试代码，直接在断点里打印 ptree 里面 thor / mjolnir 的配置。

============================================

# ch02.nlohmann/json（JSON for Modern C++）

C++ 最流行的**单头文件 JSON 库**，头文件 `nlohmann/json.hpp`，头文件库、零依赖，C++11 起支持，也是大家会拿来替代 Valhalla 现在 `boost::property_tree::ptree` 的首选方案。

```cpp
#include <nlohmann/json.hpp>
using json = nlohmann::json;
```

## ✅ 核心优势（对比 ptree）

1. **原生完整 JSON 标准支持**：数组、对象、null、bool、数字全部原生；ptree 的数组是 hack 出来的，坑极多。
2. **类型保真**：存数字就是数字，bool 就是 bool；ptree 底层全部存字符串，get 才做字符串转换。
3. **API 像 JS/Python，上手简单**
4. **vcpkg 直接能装**：`vcpkg install nlohmann-json`
5. 支持序列化自定义结构体，有宏一键生成 `to_json/from_json`

## ✅ 常用API（对应 valhalla.json 配置场景）

```cpp
// 1. 从文件加载json
std::ifstream f("valhalla.json");
json cfg = json::parse(f);

// 2. 读取 thor.extended_search，找不到返回默认值 true
bool extended = cfg.value("thor", json::object()).value("extended_search", true);

// 3. at() 访问，key不存在抛异常（严格模式）
int threads = cfg.at("mjolnir").at("threads").get<int>();

// 4. 写入
cfg["thor"]["extended_search"] = true;

// 5. 序列化输出字符串
std::string text = cfg.dump(4); // 4=带缩进美化
```

> 
> 对比 ptree：ptree 用 `.` 分隔字符串路径 `cfg.get<bool>("thor.extended_search")`；nlohmann/json 是嵌套对象 `cfg["thor"]["extended_search"]`，没有路径字符串。

## ✅ 和 boost::property_tree::ptree 对比表

| 项目 | nlohmann/json | boost ptree |
| --- | --- | --- |
| 依赖 | 头文件库，无依赖 | 需要Boost整套库 |
| JSON数组 | ✅ 原生支持 | ❌ 伪数组，同名key堆叠，坑多 |
| 类型保存 | bool/int/double 独立类型 | 全部底层存 string |
| 注释 | 解析时默认不支持JSON注释 | 同样不支持注释 |
| 异常 | `at()` 找不到抛异常；`value()` 给默认 | get()抛异常；get(path,def)默认 |
| 适用 | JSON配置、接口报文 | 多格式（ini/xml/json）通用树 |

## ✅ 移植思路（Valhalla场景：把ptree换成nlohmann json）

原来代码：

```
// boost ptree
bool extended = config.get<bool>("thor.extended_search", false);
```

改成 nlohmann/json：

```
bool extended = config.value("thor", json::object()).value("extended_search", false);
```

多层子节点提取（对应 `BuildAdminFromPBF` 的入参）：

```
// 原来 const ptree& config
// 改成 const nlohmann::json& config
auto mjolnir_cfg = config.value("mjolnir", json::object());
```

## ⚠️ 缺点

1. **性能不是顶级**：DOM 式一次性加载整个json进内存；超大GB级JSON文件，优先用 simdjson / RapidJSON。
2. 单头文件，编译会慢一点（大量模板代码）。
3. 标准JSON不支持注释，带注释的valhalla.json解析失败（可以用 `json::parse(f, nullptr, true, true)` 开启注释扩展）。

## ✅ vcpkg 安装命令（你当前环境直接可用）

```
vcpkg install nlohmann-json:x64-linux
```

CMake 里：

```
find_package(nlohmann_json CONFIG REQUIRED)
target_link_libraries(valhalla PRIVATE nlohmann_json::nlohmann_json)
```

如果你想，我可以写一段**完整替换 BuildAdminFromPBF 函数，把ptree改成nlohmann json**的示例代码。

====================================================

# ch03. nlohmann/json vs RapidJSON

一句话总结：
**nlohmann：开发爽、语法简单，牺牲一点性能；RapidJSON：性能强、内存省，API繁琐，支持SAX流式解析**。
刚好贴合你 Valhalla 的场景：读 `valhalla.json` 这种配置文件，**优先 nlohmann**；如果是超大JSON、高频解析热点代码，才上 RapidJSON。

## 对比总表

| 项目 | nlohmann/json | RapidJSON |
| --- | --- | --- |
| 定位 | 现代易用DOM库 | 高性能DOM+SAX双模式库 |
| 头文件 | 单头文件 `json.hpp` | 一堆头文件，无单头合并版本 |
| API风格 | STL风格，像Python/JS，极易上手 | 偏C风格，模板多，代码冗长 |
| 解析模型 | **仅DOM**：一次性加载全部JSON到内存 | DOM（完整树）+ **SAX流式**（不用加载全量，O(1)内存） |
| 性能 | 中等，大文件比RapidJSON慢不少 | 很快，支持SIMD、原地解析in-place |
| 内存占用 | 较高，完整DOM树 | 低；SAX模式几乎不占额外内存 |
| 异常 | 默认抛异常；可关闭 | **无异常**，靠返回码判断错误 |
| 自定义结构体序列化 | 一键宏 `NLOHMANN_DEFINE_TYPE_INTRUSIVE` | 全部手写，样板代码多 |
| 拷贝语义 | 正常值拷贝，符合直觉 | Value是移动语义，直接`=`会转移所有权，极易踩坑 |
| 版本维护 | 活跃更新 | 2016年后主版本停滞，社区分支维护 |
| vcpkg安装 | `vcpkg install nlohmann-json` | `vcpkg install rapidjson` |

## 代码示例对比（读取 valhalla.json thor.extended_search）

### nlohmann/json

```cpp
#include <nlohmann/json.hpp>
using json = nlohmann::json;

std::ifstream f("valhalla.json");
json cfg = json::parse(f);
bool es = cfg["thor"].value("extended_search", false);
```

### RapidJSON

```cpp
#include "rapidjson/document.h"
#include "rapidjson/filereadstream.h"
using namespace rapidjson;

FILE* fp = fopen("valhalla.json", "r");
char buf[65536];
FileReadStream is(fp, buf, sizeof(buf));
Document doc;
doc.ParseStream(is);
fclose(fp);

bool es = false;
if(doc.HasMember("thor") && doc["thor"].IsObject()){
    auto& thor = doc["thor"];
    if(thor.HasMember("extended_search") && thor["extended_search"].IsBool()){
        es = thor["extended_search"].GetBool();
    }
}
```

> 
> RapidJSON 每次访问都要手动判断 key 是否存在、类型是否匹配，代码量大很多。

## 核心概念差异

1. **SAX 模式（RapidJSON独有）**
事件驱动，边读边回调，不需要把整个JSON树加载进内存。适合 GB 级大JSON、日志流，**内存占用极低**。nlohmann 不支持SAX，只能一次性加载完整DOM。
2. **原地解析 In-place**
RapidJSON可以直接在原始字符串缓冲区解析，不额外分配字符串内存，进一步省内存。
3. **RapidJSON 大坑**`rapidjson::Value`**没有深拷贝**，赋值 `a = b` 是移动语义，b会变空。新手很容易内存崩溃、野指针。
所有Value的生命周期必须和Document绑定，Document销毁，所有子Value全部失效。

## 你的 Valhalla 场景怎么选？

- 读取 valhalla.json 配置文件（KB级别，程序启动一次性读）：✅ **nlohmann/json**
代码改动量最小，替换原来 boost ptree 最省事，维护成本低。
- 如果后面新增功能：解析超大PBF导出的JSON，或者百万级高频JSON解析：✅ RapidJSON（SAX模式）

## 补充：还有 simdjson

比 RapidJSON 更快，SIMD指令暴力解析，现代服务器首选高性能JSON库，但API学习成本更高。

## 小结

- 配置文件、业务逻辑、快速开发：**nlohmann/json**
- 性能瓶颈、超大文件、流式解析：**RapidJSON**

如果你想，我可以写一份**boost ptree 迁移到 RapidJSON**的 `BuildAdminFromPBF` 入参改造示例。