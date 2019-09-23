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

###############################################################################
# Common dawn configs
###############################################################################

add_library(dawn_public_include_dirs INTERFACE)
target_include_directories(dawn_public_include_dirs INTERFACE
    $<BUILD_INTERFACE:${dawn_root}/src/include>
    $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/src>
    $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/src/include>
)

add_library(dawn_internal INTERFACE)
target_include_directories(dawn_internal INTERFACE
    $<BUILD_INTERFACE:${dawn_root}/src>
)
target_compile_definitions(dawn_internal INTERFACE
        $<$<BOOL:${DAWN_ENABLE_ASSERTS}>:DAWN_ENABLE_ASSERTS=1>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:DAWN_ENABLE_BACKEND_D3D12>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:DAWN_ENABLE_BACKEND_METAL>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:DAWN_ENABLE_BACKEND_NULL>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:DAWN_ENABLE_BACKEND_OPENGL>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:DAWN_ENABLE_BACKEND_VULKAN>
        $<$<BOOL:${X11_FOUND}>:DAWN_USE_X11>
        $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:NOMINMAX>
        $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:_CRT_SECURE_NO_WARNINGS>
)

###############################################################################
# Common dawn library
###############################################################################

add_library(dawn_common STATIC
    dawn/src/common/Assert.cpp
    dawn/src/common/Assert.h
    dawn/src/common/BitSetIterator.h
    dawn/src/common/Compiler.h
    dawn/src/common/Constants.h
    dawn/src/common/DynamicLib.cpp
    dawn/src/common/DynamicLib.h
    dawn/src/common/HashUtils.h
    dawn/src/common/Math.cpp
    dawn/src/common/Math.h
    dawn/src/common/Platform.h
    dawn/src/common/Result.cpp
    dawn/src/common/Result.h
    dawn/src/common/Serial.h
    dawn/src/common/SerialMap.h
    dawn/src/common/SerialQueue.h
    dawn/src/common/SerialStorage.h
    dawn/src/common/SwapChainUtils.h
    dawn/src/common/vulkan_platform.h
    dawn/src/common/windows_with_undefs.h
)
target_link_libraries(dawn_common
    PUBLIC
        dawn_internal
        $<$<BOOL:DAWN_ENABLE_BACKEND_VULKAN>:vulkan_headers>
    PRIVATE dawn_headers
)
