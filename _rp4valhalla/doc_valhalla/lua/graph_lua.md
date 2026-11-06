# ch01.Lua代码逐行讲解
## 函数作用
函数名 `restriction_prefix(restriction_str)`
**功能：** 从类似这种格式的字符串 `restriction:conditional=no_left_turn @ (07:00-09:00,15:30-17:30)` 里，提取 `@` **前面非空格的前缀部分**，也就是拿到 `restriction:conditional=no_left_turn`。
> 格式约定：`【前缀内容】 @ 【时间条件】`，`@` 是分隔符。

```lua
function restriction_prefix(restriction_str)
  --not a string
  if restriction_str == nil then
    return nil
  end
```
- 如果传入参数是 `nil`（空、没传值），直接返回nil，终止。

```lua
  --find where the restriction type ends.
  --format looks like
  --restriction:conditional=no_left_turn @ (07:00-09:00,15:30-17:30)
  local index = 0
  local found = false
  -- 逐个遍历字符串的每一个字符
  for c in restriction_str:gmatch"." do
    if c == "@" then
      found = true
      break
    end
    -- 只有字符不是空格，index才+1（空格不计入长度）
    if c ~= " " then
      index = index + 1
    end
  end
```
循环逻辑拆解：
1. 逐个拿字符串里的字符 `c`
2. **一旦碰到字符 `@`**：标记`found=true`，立刻跳出循环
3. 在遇到`@`**之前**：
   - 如果字符不是空格，`index` +1
   - 如果是空格，`index`不变（空格不算入前缀长度）

> 举例子：`abc  @ xxx`
> 遍历 `a → index=1`，`b→2`，`c→3`，然后是空格，index不变，然后遇到`@`退出循环。
> index最终=3。

```lua
  --@ symbol did not exist
  if found == false then
    return nil
  end
```
- 如果遍历完整串都**没有找到`@`**，返回nil，说明格式不合法。

```lua
  --return the type of restriction
  return restriction_str:sub(0, index)
end
```
`string.sub(字符串, start, end)`：截取字符串。
Lua里 `sub(0,index)` 等价于从第1位，截取到第`index`个**非空格字符**。

## ✅ 示例测试
输入：`restriction:conditional=no_left_turn @ (07:00-09:00,15:30-17:30)`
循环在碰到`@`停止，`@`之前所有非空格字符计数，截取结果：
`restriction:conditional=no_left_turn`

> 注意：`@`前面如果有空格，**空格不会被包含在返回结果里**
例：`no_uturn   @ 08:00`
@前面有3个空格，index只算前面文字长度，返回`no_uturn`

## 缺陷 / 坑点（重点，你做ROS/导航相关规则解析大概率会踩）
1. **只识别第一个`@`**，如果字符串有多个`@`，直接在第一个就截断。
2. `@`前面的连续空格会被直接忽略，不会放进返回字符串。
3. 如果`@`前面全是空格，index=0，`sub(0,0)`返回空字符串。
4. 不会校验`@`后面的内容，只判断有没有`@`符号。
5. 只处理`nil`，但如果传入数字、table，会报错（没有判断是不是字符串类型）。

## 简化一句话总结
遍历字符串，找到第一个`@`，统计`@`之前所有**非空格字符**的数量，截取这一段文字返回；找不到`@`或者输入为空，返回nil。

如果你想，我可以给你写一段**测试用例**，直接复制运行，验证各种输入场景。


====================================

# ch02.`gmatch` 是什么（Lua）
```lua
for c in restriction_str:gmatch"." do
```
`string:gmatch(pattern)` 是 Lua **字符串迭代器函数**。
> 作用：**按照你给的正则模式，不断提取匹配到的子串，用于for循环遍历**。

## 这里 `gmatch"."`
- 模式 `"."` 在Lua匹配规则里：**匹配任意单个字符（除换行符`\n`）**
- `restriction_str:gmatch"."` 会生成一个迭代器，**逐个取出字符串里每一个字符**

等价理解：把字符串拆成一个个字符，循环依次拿到每个字符`c`。

示例：
```lua
local s = "abc"
for c in s:gmatch"." do
    print(c)
end
--输出：a，b，c
```

## 和 `string.match` / `string.find` 的区别
1. `string.match(s, pat)`：**只找第一个匹配结果，返回一次**
2. `string.find(s, pat)`：**返回匹配的起始、结束下标**，不返回内容
3. `s:gmatch(pat)`：**迭代器，for循环可以反复拿所有匹配项**

## 放到你这段代码里的逻辑
```lua
for c in restriction_str:gmatch"." do
    if c == "@" then
        found = true
        break
    end
    if c ~= " " then
        index = index + 1
    end
end
```
循环逐个读取字符串里的每一个字符：
- 读到`@` → 标记找到，跳出循环
- 不是空格，index计数+1；是空格就跳过计数

> ⚠️小提醒：
`gmatch"."` 不会跨换行。如果字符串包含换行`\n`，会直接跳过换行字符，不会捕获。

## 替代写法（了解即可）
也可以用下标循环逐个取字符，效果近似：
```lua
for i=1,#restriction_str do
    local c = restriction_str:sub(i,i)
    --同样逻辑
end
```
`gmatch`写法更简洁，适合逐个字符遍历场景。

要不要顺便讲一下Lua的**模式匹配（pattern）**，和正则表达式有哪些不一样？