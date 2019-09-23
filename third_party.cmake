# Copyright (c) 2019 Mathieu-André Chiasson
# All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

include_guard(GLOBAL)
include(HunterGate)

###############################################################################
# Third-party dependencies needed by dawn_native
###############################################################################

# shaderc (includes glslang, SPIRV-Headers, SPIRV-Cross and SPIRV-Tools)
execute_process(
    COMMAND ${Python3_EXECUTABLE} utils/git-sync-deps
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/third_party/shaderc
)
if (CMAKE_C_FLAGS_${_BUILD_TYPE} MATCHES "/MD")
    set(SHADERC_ENABLE_SHARED_CRT ON CACHE BOOL "Use the shared CRT instead of the static CRT" FORCE)
else()
    set(SHADERC_ENABLE_SHARED_CRT OFF CACHE BOOL "Use the shared CRT instead of the static CRT" FORCE)
endif()
set(SHADERC_ENABLE_SPVC ON CACHE BOOL "Enable libshaderc_spvc" FORCE) # for SPIRV-Cross
option(SHADERC_SKIP_INSTALL "Skip installation" ON)
option(SHADERC_SKIP_TESTS "Skip building tests" ON)
option(SPIRV_CROSS_ENABLE_TESTS "Enable SPIRV-Cross tests." OFF)
option(SPIRV_CROSS_SKIP_INSTALL "Skips installation targets." ON)
option(SPIRV_SKIP_EXECUTABLES "Skip building the executable and tests along with the library" ON)
option(SPIRV_SKIP_TESTS "Skip building SPIRV-Tools tests" ON)
option(ENABLE_GLSLANG_BINARIES "Builds glslangValidator and spirv-remap" OFF)
add_subdirectory(third_party/shaderc)

# Empty targets to add the include dirs and list the sources of Khronos headers for header inclusion check.
add_library(khronos_headers_public INTERFACE)
target_include_directories(khronos_headers_public INTERFACE ${dawn_root}/third_party/khronos)

add_library(vulkan_headers_config INTERFACE)
target_include_directories(vulkan_headers_config INTERFACE ${dawn_root}/third_party/khronos)
target_compile_definitions(vulkan_headers_config INTERFACE
    $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:VK_USE_PLATFORM_WIN32_KHR>
    $<$<PLATFORM_ID:Linux>:VK_USE_PLATFORM_XCB_KHR>
    $<$<PLATFORM_ID:Android>:VK_USE_PLATFORM_ANDROID_KHR>
)

add_library(vulkan_headers INTERFACE)
target_sources(vulkan_headers INTERFACE
    $<BUILD_INTERFACE:
        ${dawn_root}/third_party/khronos/vulkan/vk_icd.h
        ${dawn_root}/third_party/khronos/vulkan/vk_layer.h
        ${dawn_root}/third_party/khronos/vulkan/vk_platform.h
        ${dawn_root}/third_party/khronos/vulkan/vk_sdk_platform.h
        ${dawn_root}/third_party/khronos/vulkan/vulkan.h
        ${dawn_root}/third_party/khronos/vulkan/vulkan_core.h
    >
)
target_link_libraries(vulkan_headers INTERFACE vulkan_headers_config)

add_library(khronos_platform INTERFACE)
target_sources(khronos_platform INTERFACE
    $<BUILD_INTERFACE:${dawn_root}/third_party/khronos/KHR/khrplatform.h>
)
target_link_libraries(khronos_platform INTERFACE khronos_headers_public)
