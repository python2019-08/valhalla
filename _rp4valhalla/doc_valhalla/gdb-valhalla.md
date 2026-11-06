# ch01.gdb ./valhalla_build_admins
```sh
a@a~/valhalla$ gdb ./build_vcpkg/valhalla_build_admins
# 在gdb交互界面内执行：
# 
# 1.关闭调试信息，否则gdb会从远程服务器下载ubuntu系统调试信息
(gdb) set debuginfod enabled off
# 2.设置参数
# ./_data/beijing-260712.osm.pbf
(gdb) set args -c  ./_data/valhalla_config.json  ./_data/beijing-260712.osm.pbf
# 3.运行程序
(gdb) run
```