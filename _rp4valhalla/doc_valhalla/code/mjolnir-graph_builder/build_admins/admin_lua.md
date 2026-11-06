# ch01.lua代码解释
<!-- 
src/mjolnir/pbfadminparser.cc
lua/admin.lua
-->
```lua
allow_intersection_names = {
["Japan"] = "true",
["North Korea"] = "true",
["South Korea"] = "true",
["Nicaragua"] = "true"
}
```
## 基础语法
1. `allow_intersection_names`：定义一个**全局 Lua table（字典/映射表）**。
2. `{ ... }`：Lua table，这里是 `key -> value` 的键值对结构。
3. `["Japan"] = "true"`
   - key：字符串 `"Japan"`（国家英文名）
   - value：字符串 `"true"`（不是布尔值 `true`，是带引号的字符串）

> ⚠️ 注意：`"true"`（字符串）≠ `true`（Lua布尔真）。
> 如果写成 `["Japan"] = true` 才是布尔类型。这里存的是字符串。

## 在 Valhalla 的场景含义（结合你前面的 `LuaTagTransform`）
这个表是**白名单配置**：
> 只有列表里这几个国家，**允许路口（intersection）保留名称**。
> 不在这个表里的国家，路口名称会被过滤掉，不参与路网构建。

Valhalla 在处理 OSM 的 node/way 标签时，`nodes_proc` / `ways_proc` Lua 函数会读取这个全局 table：
伪逻辑示意：
```lua
-- 在valhalla的lua处理函数内部
local country_name = 从osm标签拿到国家名称
if allow_intersection_names[country_name] == "true" then
    -- 这个国家，保留路口名字
    keep_intersection_name = true
else
    -- 其他国家，丢弃路口名称
    keep_intersection_name = false
end
```

### 为什么要做这个白名单？
OSM 里很多国家的路口点 `node` 会带有 `name` 标签，但很多其实**不是路口正式名称**，只是道路名复制过来的，会造成：
- 大量冗余路口名称
- 导航提示词错乱
- 增大valhalla路网数据体积

所以 valhalla 默认**不提取路口名称**，只对少数几个国家开启这个特性。

## 补充细节
1. 键名严格大小写敏感：`["japan"]` 和 `["Japan"]` 是两个不同key；OSM提取出来的国家名称大小写必须匹配才能命中。
2. 这个是全局变量，C++代码（你前面那段 `LuaTagTransform`）执行lua脚本后，这个table就存在lua虚拟机全局环境里，供 `nodes_proc` 等函数访问。
3. 如果需要新增国家，只需要在这个table追加一行：
```lua
["China"] = "true",
```

## 小疑问点
源码这里为什么用字符串 `"true"`，而不是布尔 `true`？
大概率是历史遗留写法，只是统一判断字符串相等，功能上完全等价，只是类型不一样。

=====================================

# ch02. Lua 的table语法规则

为何不能写 成
```lua
allow_intersection_names = { "Japan" = "true", "North Korea" = "true", "South Korea" = "true", "Nicaragua" = "true" }
```
???

## 核心原因：Lua 语法规则
```lua
-- ❌ 你写的这种，语法报错
allow_intersection_names = { "Japan" = "true" }
```
`"Japan"` 是字符串字面量，**不能直接当 key 放在 `=` 左边**。
> Lua table 有两种写法：
> 1. 数组形式（不带 `=`）：`{ "A", "B" }` → key 是 1,2,3…
> 2. 键值形式：`[key] = value`

当 key 是**字符串常量**时，分两种情况：
- (1)✅ 如果字符串是**合法标识符**（只能字母、数字、下划线，不能以数字开头，**不能有空格**）：可以简写 `key = val`
```lua
    t = { hello = "true" } --等价于 ["hello"] = "true"
```
- (2)❌ 如果字符串**包含空格、横线、特殊字符**，或者本身不是合法标识符：**不能简写，必须用 `["key"]`**
```lua
    ["North Korea"] = "true" --中间有空格！必须加方括号+引号
```

`North Korea` 中间有空格，不是合法变量名，所以不能直接写 `North Korea = "true"`，更不能写成 `"North Korea" = "true"`。
Lua 的语法里，`=` 左边如果不加 `[]`，**只能是标识符，不能是字符串字面量**。

---
## 两种正确写法对比
```lua
-- ✅ 写法1：用 ["字符串"] ，支持带空格字符串（你原来的正确版本）
allow_intersection_names = {
  ["Japan"] = "true",
  ["North Korea"] = "true",
  ["South Korea"] = "true",
  ["Nicaragua"] = "true"
}

-- ✅ 写法2：只有无空格合法名字，才能简写
t = { Japan = "true" } --等价 ["Japan"]="true"，Japan没有空格，可以简写
```
> `Japan` 虽然可以简写为 `Japan = "true"`，但为了整个表风格统一，源码全部统一写成 `["xxx"]`，可读性更好，避免有人修改时踩空格的坑。

### 举例  
```lua
railway_speeds = { 
    train = 10, 
    railway = 10 
} 
```
等价于
```lua
railway_speeds = {
    ["train"] = 10,
    ["railway"] = 10
} 
```

===========================================

# ch03.# 前置说明
```c
// 解释这些 LuaJIT  API函数:
lua_getglobal() 
lua_newtable() 
lua_pushstring() 
lua_pushinteger() 
lua_rawset() 
lua_pcall() 
lua_next() 
lua_tostring() 
lua_tointeger() 
lua_pop() 
lua_close() 
luaL_newstate() 
luaL_openlibs() 
luaL_dostring()
```
这些是 **Lua 5.1 C API**，LuaJIT 完整兼容这套C接口，所以你用libluajit链接后，C++代码可以直接调用它们。
核心模型：**Lua虚拟机栈（stack）**，所有参数/返回值/变量都在栈上操作；栈下标：正数=从栈底往上数；负数=**从栈顶往下数（最常用）**，`-1`永远是栈顶元素。

> 栈操作口诀：**谁调用，谁负责平衡栈；压入多少，就要弹出多少，否则栈泄漏**。

---
## 逐个API讲解（按你C++代码出现顺序）
### 1. `lua_State* luaL_newstate(void);`
```cpp
state_ = luaL_newstate();
```
- 作用：**创建一个全新Lua虚拟机实例（lua_State）**。
- 返回：lua_State* 句柄，后续所有API都要传这个state；失败返回NULL。
- 注意：
  - 每个state独立全局变量、栈、内存；**非线程安全**，多线程必须每个线程单独一个state。
  - 刚创建是空虚拟机，**没有加载任何标准库（math/table/string等）**，需要手动`luaL_openlibs`。

### 2. `void luaL_openlibs(lua_State *L);`
```cpp
luaL_openlibs(state_);
```
- 作用：给lua虚拟机L，加载所有Lua标准库（string、table、io、math等）。
- 没有返回值。
- 对应你的脚本：`string.find`、`ipairs` 这些内置函数，依赖这个加载。

### 3. `int luaL_dostring(lua_State *L, const char *str);`
```cpp
luaL_dostring(state_, lua.c_str());
```
- 作用：把字符串`str`当成Lua源码编译并执行。
- 本质宏：`(luaL_loadstring(L, str) || lua_pcall(L,0,0,0))`
- 返回值：`0`成功；非0代表出错，错误信息压到栈顶。
- 在Valhalla：加载你那一大段`rels_proc`/`nodes_proc`/全局`allow_intersection_names` lua脚本，执行后全局函数和table就注册进lua虚拟机。

### 4. `void lua_getglobal(lua_State *L, const char *name);`
```cpp
lua_getglobal(state_, lua_func.c_str());
```
- 作用：**查找全局变量name，把找到的值压入栈顶**。
- 例子：`lua_getglobal(L, "rels_proc")` → 在全局表找`rels_proc`函数，压栈。
- 栈变化：栈元素 +1。
> 你的代码这里：压入lua函数对象，后续准备调用。

### 5. `void lua_newtable(lua_State *L);`
```cpp
lua_newtable(state_);
```
- 作用：新建一个空lua table，压入栈顶。
- 栈变化：栈元素 +1。
> valhalla代码：新建`kv`表，用来存放OSM tags（key-value）。此时栈顶`-1`就是这个空table。

### 6. `void lua_pushstring(lua_State *L, const char *s);`
```cpp
lua_pushstring(state_, tag.key());
lua_pushstring(state_, tag.value());
```
- 作用：把C字符串`s`，转为Lua字符串对象，压栈顶。
- 栈变化：栈元素 +1。
> 代码逻辑：先push key，再push value，此时栈顶两个：key(-2), value(-1)；table在-3位置。

### 7. `void lua_rawset(lua_State *L, int idx);`
```cpp
lua_rawset(state_, -3);
```
- 作用：从栈顶取出 **key 和 value**，写入索引`idx`指向的table；弹出key、value两个元素。
> rawset：**raw = 不触发元表(__newindex)，直接写入table**，性能更高。
- 栈变化：弹出2个元素（key+value），栈总元素 -2。
> 你这里`idx=-3`：table在-3。栈顺序：`[table, key, value]`，执行后：table[key]=value；key和value被弹出，栈只剩table。
> 循环：不断push key/value，rawset写入table，组装OSM标签kv表。

### 8. `void lua_pushinteger(lua_State *L, lua_Integer n);`
```cpp
lua_pushinteger(state_, count);
```
- 作用：C整数转为Lua整数，压栈顶。
- 栈变化：栈元素 +1。
> valhalla：把tag总数压栈，作为lua函数第二个入参 `nokeys`。此时栈：`[kv_table, count]`。

### 9. `int lua_pcall(lua_State *L, int nargs, int nresults, int errfunc);`
```cpp
lua_pcall(state_, 2, type == OSMType::kWay ? 4 : 2, 0)
```
> 【最重要API：调用lua函数】
- 参数：
  1. `L`：虚拟机
  2. `nargs`：**函数入参个数**（从栈顶取nargs个元素作为参数）
  3. `nresults`：期望函数返回值个数
  4. `errfunc`：错误处理函数栈索引；0=不使用
- 工作流程：
  1. 栈结构调用前：`[function, arg1, arg2]`，nargs=2；
  2. 弹出 function + nargs个参数；执行lua函数；
  3. 函数返回值压栈；如果返回值少于nresults，补nil；多于则截断。
- 返回值：`0=执行成功`；非0=出错，错误字符串压栈顶。
> 你的代码：调用`rels_proc(kv, nokeys)`，nargs=2；期望返回2个返回值：filter, kv_table。
- 栈变化：弹出 nargs+1（函数+参数），压入 nresults个返回值。

### 10. `int lua_next(lua_State *L, int idx);`
```cpp
lua_pushnil(state_);
while (lua_next(state_, -2) != 0) {
```
> 遍历table专用API！
- 参数：`idx`：table在栈中的索引。
- 使用范式：
  1. `lua_pushnil(L)`：nil压栈，作为遍历初始key；
  2. `lua_next(L, idx)`：
     - 以栈顶nil为key，去table找下一组key-value；
     - 找到：弹出栈顶旧key，**压入新key，再压入value**；返回非0；
     - 找不到（遍历结束）：弹出栈顶key，返回0；
- ⚠️栈状态：lua_next成功后栈顶是value(-1)，key(-2)
- 你的代码：遍历lua返回的kv table，取出key/value存入C++ Tags。
> 重点坑：不要直接lua_tostring修改栈上key，会破坏迭代器。

### 11. `const char* lua_tostring(lua_State *L, int idx);`
```cpp
const char* key = lua_tostring(state_, -2);
const char* value = lua_tostring(state_, -1);
```
- 作用：**读取栈上idx位置的值，转为C字符串**。
- 返回：C字符串指针；如果不是字符串/数字，返回`NULL`。
> 注意：返回的指针由lua虚拟机管理，不要free；栈修改后指针可能失效。

### 12. `lua_Integer lua_tointeger(lua_State *L, int idx);`
```cpp
int filter = lua_tointeger(state_, -2);
```
- 作用：读取栈上idx位置的值，转为lua整数。
- 返回：整数；无法转数字返回0。
> valhalla：读取返回第一个值filter，判断是否丢弃这条OSM实体。

### 13. `void lua_pop(lua_State *L, int n);`
```cpp
lua_pop(state_, 1);
lua_pop(state_, 2);
```
- 作用：**从栈顶弹出n个元素，直接丢弃**。
- 栈变化：栈元素 -n。
> 用途：清理栈，维持栈平衡。Way分支要丢弃多余2个返回值，所以pop。

### 14. `void lua_close(lua_State *L);`
```cpp
lua_close(state_);
```
- 作用：销毁整个lua虚拟机state，释放所有内存、table、函数。
> 在析构函数调用；调用之后L不能再使用。

---
# 把你代码里调用 rels_proc 的完整栈变化串一遍（方便理解）
1. `lua_getglobal(L, "rels_proc")` → stack: `[rels_proc_func]`
2. `lua_newtable(L)` → stack: `[rels_proc_func, kv_table]`
3. 循环 push key+value + lua_rawset，填充kv_table
4. `lua_pushinteger(L, count)` → stack: `[rels_proc_func, kv_table, count]`
5. `lua_pcall(L, 2, 2, 0)`
   - 弹出 func, kv_table, count；执行 rels_proc(kv_table, count)
   - 返回 filter, kv_table；压栈。stack: `[filter, kv_table]`
6. `lua_pushnil(L)` → stack: `[filter, kv_table, nil]`
7. `lua_next(L, -2)`：遍历 kv_table，每次栈增加 key, value
8. `lua_pop(L, 1)`：每次循环末尾pop value，维持栈给lua_next继续迭代
9. `lua_tointeger(L,-2)`读取filter；`lua_pop(L,2)`把filter和kv_table全部弹出清空栈。

# 高频踩坑点总结
1. lua_rawset：idx是table位置；rawset会自动弹出栈顶key/value；
2. lua_next：栈顶初始是nil；成功后栈顺序 key(-2), value(-1)；循环内必须pop value；
3. lua_pcall：nargs是**栈顶参数数量**，函数本身也要先压栈；
4. 栈下标负数是从栈顶算，`-1`永远栈顶；
5. lua_pushstring 返回字符串由lua托管，C++不要delete/free；
6. lua_State 销毁只能用 lua_close，不要直接free。

如果你想，我可以画这个调用过程的栈变化示意图，或者写一段极简C++ Demo单独跑这组API。


