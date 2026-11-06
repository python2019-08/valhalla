# 修正重點 1：將 "ENV" 移到 $ 的括號內部，改為 $ENV{變數名}
# 修正重點 2：若從 CMake 啟動，使用 CMAKE_CURRENT_LIST_DIR 來做雙重保險
if(DEFINED ENV{VCPKG_ROOT})
    include("$ENV{VCPKG_ROOT}/triplets/x64-linux.cmake")
else()
    # 預防 CMake 執行時環境變數尚未完全載入的備用手段
    include("${VCPKG_ROOT_DIR}/triplets/x64-linux.cmake" OPTIONAL)
endif()
# set(VCPKG_TARGET_ARCHITECTURE x64)
# set(VCPKG_CRT_LINKAGE dynamic)
# set(VCPKG_LIBRARY_LINKAGE static)

# set(VCPKG_CMAKE_SYSTEM_NAME Linux)

# 
# set(VCPKG_BUILD_TYPE debug)
