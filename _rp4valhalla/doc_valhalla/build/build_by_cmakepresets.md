# cmakepresets_build_bash.md created by Abner 
```bash
# 禁用registry功能，只用本地端口库
export VCPKG_FEATURE_FLAGS=-registries
rm -rf build vcpkg_installed
# 
cmake --preset ci-linux-debug
cmake --build --preset ci-linux-debug
sudo cmake --install build-debug
```