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
# THE SOFTWARE IS PROVIDED "AS IS WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

cmake_minimum_required(VERSION 3.10)
cmake_policy(SET CMP0076 OLD)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)
include(HunterGate)
include(dawn_generator)

HunterGate(
    URL "https://github.com/ruslo/hunter/archive/v0.23.214.tar.gz"
    SHA1 "e14bc153a7f16d6a5eeec845fb0283c8fad8c358"
)

project(dawn)


set(OpenGL_GL_PREFERENCE GLVND)

find_package(D3D12 QUIET)
find_package(METAL QUIET)
find_package(OpenGL QUIET)
find_package(X11 QUIET)
find_package(Vulkan QUIET)
find_package(Python3 QUIET REQUIRED)
find_package(Git QUIET REQUIRED)

# https://docs.hunter.sh/en/latest/packages/pkg/glfw.html
hunter_add_package(glfw)
find_package(glfw3 CONFIG REQUIRED)

if( CMAKE_BUILD_TYPE STREQUAL "Debug" )
    option(DAWN_ENABLE_ASSERTS "Enable assert" ON)
else()
    option(DAWN_ENABLE_ASSERTS "Enable assert" OFF)
endif()

option(DAWN_ENABLE_BACKEND_D3D12 "Enable D3D12 Backend" ${D3D12_FOUND})
option(DAWN_ENABLE_BACKEND_METAL "Enable Metal Backend" ${METAL_FOUND})
option(DAWN_ENABLE_BACKEND_NULL "Enable Null Backend" ON)
option(DAWN_ENABLE_BACKEND_OPENGL "Enable OpenGL Backend" ${OPENGL_FOUND})
option(DAWN_ENABLE_BACKEND_VULKAN "Enable Vulkan Backend" ${Vulkan_FOUND})
option(DAWN_BUILD_SAMPLES "Builds Samples" ON)

set(dawn_root ${PROJECT_SOURCE_DIR}/dawn)

execute_process(
    COMMAND Git::Git submodule update --init --recursive
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

execute_process(
    COMMAND ${Python3_EXECUTABLE} utils/git-sync-deps
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}/third_party/shaderc
)

################################################################################
# Compiler flags
################################################################################

string(TOUPPER "${CMAKE_BUILD_TYPE}" _BUILD_TYPE)

if (MSVC)
    # solves fatal error C1041: cannot open program database '<project>.pdb'; if multiple CL.EXE write to the same .PDB file, please use /FS
    STRING(REGEX REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_${_BUILD_TYPE} "${CMAKE_C_FLAGS_${_BUILD_TYPE}}")
    STRING(REGEX REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_${_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${_BUILD_TYPE}}")
endif()

###############################################################################
# Third-party dependencies needed by dawn_native
###############################################################################

# shaderc (includes glslang, SPIRV-Headers, SPIRV-Cross and SPIRV-Tools)
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
target_include_directories(khronos_headers_public INTERFACE
    $<BUILD_INTERFACE:${dawn_root}/third_party/khronos>
)

add_library(vulkan_headers_config INTERFACE)
target_include_directories(vulkan_headers_config INTERFACE
    $<BUILD_INTERFACE:${dawn_root}/third_party/khronos>
)
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
target_link_libraries(vulkan_headers INTERFACE $<BUILD_INTERFACE:vulkan_headers_config>)

add_library(khronos_platform INTERFACE)
target_sources(khronos_platform INTERFACE
    $<BUILD_INTERFACE:${dawn_root}/third_party/khronos/KHR/khrplatform.h>
)
target_link_libraries(khronos_platform INTERFACE $<BUILD_INTERFACE:khronos_headers_public>)


###############################################################################
# Common dawn configs
###############################################################################

add_library(dawn_public_include_dirs INTERFACE)
target_include_directories(dawn_public_include_dirs INTERFACE
    $<BUILD_INTERFACE:
        ${dawn_root}/src/include
        ${PROJECT_BINARY_DIR}/src
        ${PROJECT_BINARY_DIR}/src/include
    >
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
# Dawn headers
###############################################################################

dawn_json_generator(dawn_headers_gen
    target
        dawn_headers
    outputs
        ${PROJECT_BINARY_DIR}/src/include/dawn/dawncpp.h
        ${PROJECT_BINARY_DIR}/src/include/dawn/dawn.h
)

add_library(dawn_headers INTERFACE)
target_link_libraries(dawn_headers INTERFACE
    $<BUILD_INTERFACE:
        dawn_public_include_dirs
        dawn_headers_gen
    >
)
target_sources(dawn_headers INTERFACE
    $<BUILD_INTERFACE:
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn/EnumClassBitmasks.h
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn/dawn_export.h
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn/dawn_wsi.h
    >
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
target_link_libraries(dawn_common PUBLIC
    dawn_internal
    $<BUILD_INTERFACE:dawn_headers>
    $<$<BOOL:DAWN_ENABLE_BACKEND_VULKAN>:$<BUILD_INTERFACE:vulkan_headers>>
)

################################################################################
# dawn
################################################################################

dawn_json_generator(dawn_gen
    target
        libdawn
    outputs
        ${PROJECT_BINARY_DIR}/src/dawn/dawncpp.cpp
        ${PROJECT_BINARY_DIR}/src/dawn/dawn.c
)

add_library(dawn)
target_link_libraries(dawn PUBLIC
    $<BUILD_INTERFACE:dawn_gen>
    $<BUILD_INTERFACE:dawn_headers>
)
if (BUILD_SHARED_LIBS)
    target_compile_definitions(dawn PUBLIC
        DAWN_SHARED_LIBRARY
        DAWN_IMPLEMENTATION
    )
endif()

###############################################################################
# dawn_wire_headers
###############################################################################

add_library(dawn_wire_headers INTERFACE)
target_link_libraries(dawn_wire_headers INTERFACE
    $<BUILD_INTERFACE:dawn_headers>
)
target_sources(dawn_wire_headers INTERFACE
    $<BUILD_INTERFACE:
        ${dawn_root}/src/include/dawn_wire/Wire.h
        ${dawn_root}/src/include/dawn_wire/WireClient.h
        ${dawn_root}/src/include/dawn_wire/WireServer.h
        ${dawn_root}/src/include/dawn_wire/dawn_wire_export.h
    >
)

###############################################################################
# dawn_platform
###############################################################################

add_library(dawn_platform INTERFACE)
target_link_libraries(dawn_platform INTERFACE dawn_common)
target_sources(dawn_platform INTERFACE
    $<BUILD_INTERFACE:
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn_platform/DawnPlatform.h
        ${PROJECT_SOURCE_DIR}/dawn/src/dawn_platform/tracing/EventTracer.cpp
        ${PROJECT_SOURCE_DIR}/dawn/src/dawn_platform/tracing/EventTracer.h
        ${PROJECT_SOURCE_DIR}/dawn/src/dawn_platform/tracing/TraceEvent.h
    >
)

###############################################################################
# dawn_native
###############################################################################

add_library(dawn_native_internal INTERFACE)
target_link_libraries(dawn_native_internal INTERFACE dawn_internal)
if (CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    target_compile_options(dawn_native_internal INTERFACE -Wno-unguarded-availability)
endif()

dawn_json_generator(dawn_native_utils_gen
    target
        dawn_native_utils
    outputs
        ${PROJECT_BINARY_DIR}/src/dawn_native/ProcTable.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_native/dawn_structs_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_native/dawn_structs_autogen.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_native/ValidationUtils_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_native/ValidationUtils_autogen.cpp
)

if(DAWN_ENABLE_BACKEND_OPENGL)
    dawn_generator(dawn_native_opengl_loader_gen
        script
            ${PROJECT_SOURCE_DIR}/dawn/generator/opengl_loader_generator.py
        args
            --gl-xml ${PROJECT_SOURCE_DIR}/dawn/third_party/khronos/gl.xml
            --supported-extensions ${PROJECT_SOURCE_DIR}/dawn/src/dawn_native/opengl/supported_extensions.json
        outputs
            ${PROJECT_BINARY_DIR}/src/dawn_native/opengl/OpenGLFunctionsBase_autogen.cpp
            ${PROJECT_BINARY_DIR}/src/dawn_native/opengl/OpenGLFunctionsBase_autogen.h
            ${PROJECT_BINARY_DIR}/src/dawn_native/opengl/opengl_platform_autogen.h
    )
endif()

# Public dawn_native headers so they can be publically visible for
# dependencies of dawn_native
add_library(dawn_native_headers INTERFACE)
target_link_libraries(dawn_native_headers INTERFACE
    $<BUILD_INTERFACE:dawn_headers>
)
target_sources(dawn_native_headers INTERFACE
    $<BUILD_INTERFACE:
        ${dawn_root}/src/include/dawn_native/DawnNative.h
        ${dawn_root}/src/include/dawn_native/dawn_native_export.h

        # Include all backend's public headers so that dependencies can include
        # them even when the backends are disabled.
        ${dawn_root}/src/include/dawn_native/D3D12Backend.h
        ${dawn_root}/src/include/dawn_native/MetalBackend.h
        ${dawn_root}/src/include/dawn_native/NullBackend.h
        ${dawn_root}/src/include/dawn_native/OpenGLBackend.h
        ${dawn_root}/src/include/dawn_native/VulkanBackend.h
    >
)

# The meat of the compilation for dawn_native so that we can cheaply have
# shared_library / static_library versions of it. It compiles all the files
# except those that define exported symbols.
add_library(dawn_native_sources INTERFACE)
target_link_libraries(dawn_native_sources INTERFACE
        $<BUILD_INTERFACE:dawn_native_headers>
        $<BUILD_INTERFACE:dawn_native_utils_gen>
        $<BUILD_INTERFACE:dawn_native_internal>
        $<BUILD_INTERFACE:dawn_platform>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:
           $<BUILD_INTERFACE:dawn_native_opengl_loader_gen>
           $<BUILD_INTERFACE:khronos_platform>
        >
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:
            $<BUILD_INTERFACE:vulkan_headers>
        >
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${D3D12_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${METAL_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${OPENGL_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${Vulkan_LIBRARIES}>

)
target_sources(dawn_native_sources INTERFACE
    $<BUILD_INTERFACE:
        ${dawn_root}/src/dawn_native/Adapter.cpp
        ${dawn_root}/src/dawn_native/Adapter.h
        ${dawn_root}/src/dawn_native/AttachmentState.cpp
        ${dawn_root}/src/dawn_native/AttachmentState.h
        ${dawn_root}/src/dawn_native/BackendConnection.cpp
        ${dawn_root}/src/dawn_native/BackendConnection.h
        ${dawn_root}/src/dawn_native/BindGroup.cpp
        ${dawn_root}/src/dawn_native/BindGroup.h
        ${dawn_root}/src/dawn_native/BindGroupLayout.cpp
        ${dawn_root}/src/dawn_native/BindGroupLayout.h
        ${dawn_root}/src/dawn_native/BindGroupTracker.h
        ${dawn_root}/src/dawn_native/BuddyAllocator.cpp
        ${dawn_root}/src/dawn_native/BuddyAllocator.h
        ${dawn_root}/src/dawn_native/Buffer.cpp
        ${dawn_root}/src/dawn_native/Buffer.h
        ${dawn_root}/src/dawn_native/CommandAllocator.cpp
        ${dawn_root}/src/dawn_native/CommandAllocator.h
        ${dawn_root}/src/dawn_native/CommandBuffer.cpp
        ${dawn_root}/src/dawn_native/CommandBuffer.h
        ${dawn_root}/src/dawn_native/CommandBufferStateTracker.cpp
        ${dawn_root}/src/dawn_native/CommandBufferStateTracker.h
        ${dawn_root}/src/dawn_native/CommandEncoder.cpp
        ${dawn_root}/src/dawn_native/CommandEncoder.h
        ${dawn_root}/src/dawn_native/CommandValidation.cpp
        ${dawn_root}/src/dawn_native/CommandValidation.h
        ${dawn_root}/src/dawn_native/Commands.cpp
        ${dawn_root}/src/dawn_native/Commands.h
        ${dawn_root}/src/dawn_native/ComputePassEncoder.cpp
        ${dawn_root}/src/dawn_native/ComputePassEncoder.h
        ${dawn_root}/src/dawn_native/ComputePipeline.cpp
        ${dawn_root}/src/dawn_native/ComputePipeline.h
        ${dawn_root}/src/dawn_native/Device.cpp
        ${dawn_root}/src/dawn_native/Device.h
        ${dawn_root}/src/dawn_native/DynamicUploader.cpp
        ${dawn_root}/src/dawn_native/DynamicUploader.h
        ${dawn_root}/src/dawn_native/EncodingContext.cpp
        ${dawn_root}/src/dawn_native/EncodingContext.h
        ${dawn_root}/src/dawn_native/Error.cpp
        ${dawn_root}/src/dawn_native/Error.h
        ${dawn_root}/src/dawn_native/ErrorData.cpp
        ${dawn_root}/src/dawn_native/ErrorData.h
        ${dawn_root}/src/dawn_native/ErrorScope.cpp
        ${dawn_root}/src/dawn_native/ErrorScope.h
        ${dawn_root}/src/dawn_native/ErrorScopeTracker.cpp
        ${dawn_root}/src/dawn_native/ErrorScopeTracker.h
        ${dawn_root}/src/dawn_native/Extensions.cpp
        ${dawn_root}/src/dawn_native/Extensions.h
        ${dawn_root}/src/dawn_native/Fence.cpp
        ${dawn_root}/src/dawn_native/Fence.h
        ${dawn_root}/src/dawn_native/FenceSignalTracker.cpp
        ${dawn_root}/src/dawn_native/FenceSignalTracker.h
        ${dawn_root}/src/dawn_native/Format.cpp
        ${dawn_root}/src/dawn_native/Format.h
        ${dawn_root}/src/dawn_native/Forward.h
        ${dawn_root}/src/dawn_native/Instance.cpp
        ${dawn_root}/src/dawn_native/Instance.h
        ${dawn_root}/src/dawn_native/ObjectBase.cpp
        ${dawn_root}/src/dawn_native/ObjectBase.h
        ${dawn_root}/src/dawn_native/PassResourceUsage.h
        ${dawn_root}/src/dawn_native/PassResourceUsageTracker.cpp
        ${dawn_root}/src/dawn_native/PassResourceUsageTracker.h
        ${dawn_root}/src/dawn_native/PerStage.cpp
        ${dawn_root}/src/dawn_native/PerStage.h
        ${dawn_root}/src/dawn_native/Pipeline.cpp
        ${dawn_root}/src/dawn_native/Pipeline.h
        ${dawn_root}/src/dawn_native/PipelineLayout.cpp
        ${dawn_root}/src/dawn_native/PipelineLayout.h
        ${dawn_root}/src/dawn_native/ProgrammablePassEncoder.cpp
        ${dawn_root}/src/dawn_native/ProgrammablePassEncoder.h
        ${dawn_root}/src/dawn_native/Queue.cpp
        ${dawn_root}/src/dawn_native/Queue.h
        ${dawn_root}/src/dawn_native/RefCounted.cpp
        ${dawn_root}/src/dawn_native/RefCounted.h
        ${dawn_root}/src/dawn_native/RenderBundle.cpp
        ${dawn_root}/src/dawn_native/RenderBundle.h
        ${dawn_root}/src/dawn_native/RenderBundleEncoder.cpp
        ${dawn_root}/src/dawn_native/RenderBundleEncoder.h
        ${dawn_root}/src/dawn_native/RenderEncoderBase.cpp
        ${dawn_root}/src/dawn_native/RenderEncoderBase.h
        ${dawn_root}/src/dawn_native/RenderPassEncoder.cpp
        ${dawn_root}/src/dawn_native/RenderPassEncoder.h
        ${dawn_root}/src/dawn_native/RenderPipeline.cpp
        ${dawn_root}/src/dawn_native/RenderPipeline.h
        ${dawn_root}/src/dawn_native/ResourceHeap.h
        ${dawn_root}/src/dawn_native/ResourceMemoryAllocation.cpp
        ${dawn_root}/src/dawn_native/ResourceMemoryAllocation.h
        ${dawn_root}/src/dawn_native/RingBufferAllocator.cpp
        ${dawn_root}/src/dawn_native/RingBufferAllocator.h
        ${dawn_root}/src/dawn_native/Sampler.cpp
        ${dawn_root}/src/dawn_native/Sampler.h
        ${dawn_root}/src/dawn_native/ShaderModule.cpp
        ${dawn_root}/src/dawn_native/ShaderModule.h
        ${dawn_root}/src/dawn_native/StagingBuffer.cpp
        ${dawn_root}/src/dawn_native/StagingBuffer.h
        ${dawn_root}/src/dawn_native/SwapChain.cpp
        ${dawn_root}/src/dawn_native/SwapChain.h
        ${dawn_root}/src/dawn_native/Texture.cpp
        ${dawn_root}/src/dawn_native/Texture.h
        ${dawn_root}/src/dawn_native/ToBackend.h
        ${dawn_root}/src/dawn_native/Toggles.cpp
        ${dawn_root}/src/dawn_native/Toggles.h
        ${dawn_root}/src/dawn_native/dawn_platform.h

        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:
            ${dawn_root}/src/dawn_native/d3d12/AdapterD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/AdapterD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/BackendD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/BackendD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/BindGroupD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/BindGroupD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/BindGroupLayoutD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/BindGroupLayoutD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/BufferD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/BufferD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/CommandAllocatorManager.cpp
            ${dawn_root}/src/dawn_native/d3d12/CommandAllocatorManager.h
            ${dawn_root}/src/dawn_native/d3d12/CommandBufferD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/CommandBufferD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/CommittedResourceAllocatorD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/CommittedResourceAllocatorD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/ComputePipelineD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/ComputePipelineD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/D3D12Info.cpp
            ${dawn_root}/src/dawn_native/d3d12/D3D12Info.h
            ${dawn_root}/src/dawn_native/d3d12/DescriptorHeapAllocator.cpp
            ${dawn_root}/src/dawn_native/d3d12/DescriptorHeapAllocator.h
            ${dawn_root}/src/dawn_native/d3d12/DeviceD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/DeviceD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/Forward.h
            ${dawn_root}/src/dawn_native/d3d12/NativeSwapChainImplD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/NativeSwapChainImplD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/PipelineLayoutD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/PipelineLayoutD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/PlatformFunctions.cpp
            ${dawn_root}/src/dawn_native/d3d12/PlatformFunctions.h
            ${dawn_root}/src/dawn_native/d3d12/QueueD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/QueueD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/RenderPipelineD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/RenderPipelineD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/ResourceAllocator.cpp
            ${dawn_root}/src/dawn_native/d3d12/ResourceAllocator.h
            ${dawn_root}/src/dawn_native/d3d12/ResourceHeapD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/ResourceHeapD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/SamplerD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/SamplerD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/ShaderModuleD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/ShaderModuleD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/StagingBufferD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/StagingBufferD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/SwapChainD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/SwapChainD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/TextureCopySplitter.cpp
            ${dawn_root}/src/dawn_native/d3d12/TextureCopySplitter.h
            ${dawn_root}/src/dawn_native/d3d12/TextureD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/TextureD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/UtilsD3D12.cpp
            ${dawn_root}/src/dawn_native/d3d12/UtilsD3D12.h
            ${dawn_root}/src/dawn_native/d3d12/d3d12_platform.h
        >


        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:
            ${dawn_root}/src/dawn_native/metal/BackendMTL.h
            ${dawn_root}/src/dawn_native/metal/BackendMTL.mm
            ${dawn_root}/src/dawn_native/metal/BufferMTL.h
            ${dawn_root}/src/dawn_native/metal/BufferMTL.mm
            ${dawn_root}/src/dawn_native/metal/CommandBufferMTL.h
            ${dawn_root}/src/dawn_native/metal/CommandBufferMTL.mm
            ${dawn_root}/src/dawn_native/metal/ComputePipelineMTL.h
            ${dawn_root}/src/dawn_native/metal/ComputePipelineMTL.mm
            ${dawn_root}/src/dawn_native/metal/DeviceMTL.h
            ${dawn_root}/src/dawn_native/metal/DeviceMTL.mm
            ${dawn_root}/src/dawn_native/metal/Forward.h
            ${dawn_root}/src/dawn_native/metal/PipelineLayoutMTL.h
            ${dawn_root}/src/dawn_native/metal/PipelineLayoutMTL.mm
            ${dawn_root}/src/dawn_native/metal/QueueMTL.h
            ${dawn_root}/src/dawn_native/metal/QueueMTL.mm
            ${dawn_root}/src/dawn_native/metal/RenderPipelineMTL.h
            ${dawn_root}/src/dawn_native/metal/RenderPipelineMTL.mm
            ${dawn_root}/src/dawn_native/metal/SamplerMTL.h
            ${dawn_root}/src/dawn_native/metal/SamplerMTL.mm
            ${dawn_root}/src/dawn_native/metal/ShaderModuleMTL.h
            ${dawn_root}/src/dawn_native/metal/ShaderModuleMTL.mm
            ${dawn_root}/src/dawn_native/metal/StagingBufferMTL.h
            ${dawn_root}/src/dawn_native/metal/StagingBufferMTL.mm
            ${dawn_root}/src/dawn_native/metal/SwapChainMTL.h
            ${dawn_root}/src/dawn_native/metal/SwapChainMTL.mm
            ${dawn_root}/src/dawn_native/metal/TextureMTL.h
            ${dawn_root}/src/dawn_native/metal/TextureMTL.mm
            ${dawn_root}/src/dawn_native/metal/UtilsMetal.h
            ${dawn_root}/src/dawn_native/metal/UtilsMetal.mm
        >

        $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:
            ${dawn_root}/src/dawn_native/null/DeviceNull.cpp
            ${dawn_root}/src/dawn_native/null/DeviceNull.h
        >

        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:
            ${dawn_root}/src/dawn_native/opengl/BackendGL.cpp
            ${dawn_root}/src/dawn_native/opengl/BackendGL.h
            ${dawn_root}/src/dawn_native/opengl/BufferGL.cpp
            ${dawn_root}/src/dawn_native/opengl/BufferGL.h
            ${dawn_root}/src/dawn_native/opengl/CommandBufferGL.cpp
            ${dawn_root}/src/dawn_native/opengl/CommandBufferGL.h
            ${dawn_root}/src/dawn_native/opengl/ComputePipelineGL.cpp
            ${dawn_root}/src/dawn_native/opengl/ComputePipelineGL.h
            ${dawn_root}/src/dawn_native/opengl/DeviceGL.cpp
            ${dawn_root}/src/dawn_native/opengl/DeviceGL.h
            ${dawn_root}/src/dawn_native/opengl/Forward.h
            ${dawn_root}/src/dawn_native/opengl/GLFormat.cpp
            ${dawn_root}/src/dawn_native/opengl/GLFormat.h
            ${dawn_root}/src/dawn_native/opengl/NativeSwapChainImplGL.cpp
            ${dawn_root}/src/dawn_native/opengl/NativeSwapChainImplGL.h
            ${dawn_root}/src/dawn_native/opengl/OpenGLFunctions.cpp
            ${dawn_root}/src/dawn_native/opengl/OpenGLFunctions.h
            ${dawn_root}/src/dawn_native/opengl/PersistentPipelineStateGL.cpp
            ${dawn_root}/src/dawn_native/opengl/PersistentPipelineStateGL.h
            ${dawn_root}/src/dawn_native/opengl/PipelineGL.cpp
            ${dawn_root}/src/dawn_native/opengl/PipelineGL.h
            ${dawn_root}/src/dawn_native/opengl/PipelineLayoutGL.cpp
            ${dawn_root}/src/dawn_native/opengl/PipelineLayoutGL.h
            ${dawn_root}/src/dawn_native/opengl/QueueGL.cpp
            ${dawn_root}/src/dawn_native/opengl/QueueGL.h
            ${dawn_root}/src/dawn_native/opengl/RenderPipelineGL.cpp
            ${dawn_root}/src/dawn_native/opengl/RenderPipelineGL.h
            ${dawn_root}/src/dawn_native/opengl/SamplerGL.cpp
            ${dawn_root}/src/dawn_native/opengl/SamplerGL.h
            ${dawn_root}/src/dawn_native/opengl/ShaderModuleGL.cpp
            ${dawn_root}/src/dawn_native/opengl/ShaderModuleGL.h
            ${dawn_root}/src/dawn_native/opengl/SwapChainGL.cpp
            ${dawn_root}/src/dawn_native/opengl/SwapChainGL.h
            ${dawn_root}/src/dawn_native/opengl/TextureGL.cpp
            ${dawn_root}/src/dawn_native/opengl/TextureGL.h
            ${dawn_root}/src/dawn_native/opengl/UtilsGL.cpp
            ${dawn_root}/src/dawn_native/opengl/UtilsGL.h
            ${dawn_root}/src/dawn_native/opengl/opengl_platform.h
        >

        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:
            ${dawn_root}/src/dawn_native/vulkan/AdapterVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/AdapterVk.h
            ${dawn_root}/src/dawn_native/vulkan/BackendVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/BackendVk.h
            ${dawn_root}/src/dawn_native/vulkan/BindGroupLayoutVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/BindGroupLayoutVk.h
            ${dawn_root}/src/dawn_native/vulkan/BindGroupVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/BindGroupVk.h
            ${dawn_root}/src/dawn_native/vulkan/BufferVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/BufferVk.h
            ${dawn_root}/src/dawn_native/vulkan/CommandBufferVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/CommandBufferVk.h
            ${dawn_root}/src/dawn_native/vulkan/ComputePipelineVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/ComputePipelineVk.h
            ${dawn_root}/src/dawn_native/vulkan/DeviceVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/DeviceVk.h
            ${dawn_root}/src/dawn_native/vulkan/ExternalHandle.h
            ${dawn_root}/src/dawn_native/vulkan/FencedDeleter.cpp
            ${dawn_root}/src/dawn_native/vulkan/FencedDeleter.h
            ${dawn_root}/src/dawn_native/vulkan/Forward.h
            ${dawn_root}/src/dawn_native/vulkan/MemoryAllocator.cpp
            ${dawn_root}/src/dawn_native/vulkan/MemoryAllocator.h
            ${dawn_root}/src/dawn_native/vulkan/MemoryResourceAllocatorVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/MemoryResourceAllocatorVk.h
            ${dawn_root}/src/dawn_native/vulkan/NativeSwapChainImplVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/NativeSwapChainImplVk.h
            ${dawn_root}/src/dawn_native/vulkan/PipelineLayoutVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/PipelineLayoutVk.h
            ${dawn_root}/src/dawn_native/vulkan/QueueVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/QueueVk.h
            ${dawn_root}/src/dawn_native/vulkan/RenderPassCache.cpp
            ${dawn_root}/src/dawn_native/vulkan/RenderPassCache.h
            ${dawn_root}/src/dawn_native/vulkan/RenderPipelineVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/RenderPipelineVk.h
            ${dawn_root}/src/dawn_native/vulkan/ResourceMemoryVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/ResourceMemoryVk.h
            ${dawn_root}/src/dawn_native/vulkan/SamplerVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/SamplerVk.h
            ${dawn_root}/src/dawn_native/vulkan/ShaderModuleVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/ShaderModuleVk.h
            ${dawn_root}/src/dawn_native/vulkan/StagingBufferVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/StagingBufferVk.h
            ${dawn_root}/src/dawn_native/vulkan/SwapChainVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/SwapChainVk.h
            ${dawn_root}/src/dawn_native/vulkan/TextureVk.cpp
            ${dawn_root}/src/dawn_native/vulkan/TextureVk.h
            ${dawn_root}/src/dawn_native/vulkan/UtilsVulkan.cpp
            ${dawn_root}/src/dawn_native/vulkan/UtilsVulkan.h
            ${dawn_root}/src/dawn_native/vulkan/VulkanError.cpp
            ${dawn_root}/src/dawn_native/vulkan/VulkanError.h
            ${dawn_root}/src/dawn_native/vulkan/VulkanFunctions.cpp
            ${dawn_root}/src/dawn_native/vulkan/VulkanFunctions.h
            ${dawn_root}/src/dawn_native/vulkan/VulkanInfo.cpp
            ${dawn_root}/src/dawn_native/vulkan/VulkanInfo.h
            ${dawn_root}/src/dawn_native/vulkan/external_memory/MemoryService.h
            ${dawn_root}/src/dawn_native/vulkan/external_semaphore/SemaphoreService.h
            $<$<PLATFORM_ID:Linux>:
                ${dawn_root}/src/dawn_native/vulkan/external_memory/MemoryServiceOpaqueFD.cpp
                ${dawn_root}/src/dawn_native/vulkan/external_semaphore/SemaphoreServiceOpaqueFD.cpp
            >
            $<$<NOT:$<PLATFORM_ID:Linux>>:
                ${dawn_root}/src/dawn_native/vulkan/external_memory/MemoryServiceNull.cpp
                ${dawn_root}/src/dawn_native/vulkan/external_semaphore/SemaphoreServiceNull.cpp
            >
        >
    >
)

# The static and shared libraries for dawn_native. Most of the files are
# already compiled in dawn_native_sources, but we still need to compile
# files defining exported symbols.
add_library(dawn_native
    dawn/src/dawn_native/DawnNative.cpp
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/D3D12Backend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/MetalBackend.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/dawn_native/null/NullBackend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/OpenGLBackend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanBackend.cpp>
)

target_link_libraries(dawn_native PUBLIC
    $<BUILD_INTERFACE:dawn_native_headers>
    $<BUILD_INTERFACE:dawn_native_sources>
    $<BUILD_INTERFACE:dawn_native_internal>
    dawn_common
    SPIRV-Tools
    spirv-cross-glsl
    spirv-cross-hlsl
    spirv-cross-msl
)

if (BUILD_SHARED_LIBS)
    target_compile_definitions(dawn_native PUBLIC
        DAWN_NATIVE_SHARED_LIBRARY
        DAWN_NATIVE_IMPLEMENTATION
    )
endif()


###############################################################################
# dawn_wire
###############################################################################

dawn_json_generator(dawn_wire_gen
    target
        dawn_wire
    outputs
        ${PROJECT_BINARY_DIR}/src/dawn_wire/WireCmd_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_wire/WireCmd_autogen.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_wire/client/ApiObjects_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_wire/client/ApiProcs_autogen.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_wire/client/ApiProcs_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_wire/client/ClientBase_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_wire/client/ClientHandlers_autogen.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_wire/client/ClientPrototypes_autogen.inc
        ${PROJECT_BINARY_DIR}/src/dawn_wire/server/ServerBase_autogen.h
        ${PROJECT_BINARY_DIR}/src/dawn_wire/server/ServerDoers_autogen.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_wire/server/ServerHandlers_autogen.cpp
        ${PROJECT_BINARY_DIR}/src/dawn_wire/server/ServerPrototypes_autogen.inc
)

add_library(dawn_wire
    dawn/src/dawn_wire/WireClient.cpp
    dawn/src/dawn_wire/WireDeserializeAllocator.cpp
    dawn/src/dawn_wire/WireDeserializeAllocator.h
    dawn/src/dawn_wire/WireServer.cpp
    dawn/src/dawn_wire/client/ApiObjects.h
    dawn/src/dawn_wire/client/ApiProcs.cpp
    dawn/src/dawn_wire/client/Buffer.cpp
    dawn/src/dawn_wire/client/Buffer.h
    dawn/src/dawn_wire/client/Client.cpp
    dawn/src/dawn_wire/client/Client.h
    dawn/src/dawn_wire/client/ClientDoers.cpp
    dawn/src/dawn_wire/client/ClientInlineMemoryTransferService.cpp
    dawn/src/dawn_wire/client/Device.cpp
    dawn/src/dawn_wire/client/Device.h
    dawn/src/dawn_wire/client/Fence.cpp
    dawn/src/dawn_wire/client/Fence.h
    dawn/src/dawn_wire/client/ObjectAllocator.h
    dawn/src/dawn_wire/server/ObjectStorage.h
    dawn/src/dawn_wire/server/Server.cpp
    dawn/src/dawn_wire/server/Server.h
    dawn/src/dawn_wire/server/ServerBuffer.cpp
    dawn/src/dawn_wire/server/ServerDevice.cpp
    dawn/src/dawn_wire/server/ServerFence.cpp
    dawn/src/dawn_wire/server/ServerInlineMemoryTransferService.cpp
    dawn/src/dawn_wire/server/ServerQueue.cpp
)

target_link_libraries(dawn_wire PUBLIC
    $<BUILD_INTERFACE:dawn_wire_headers>
    $<BUILD_INTERFACE:dawn_wire_gen>
    dawn_common
)

if (BUILD_SHARED_LIBS)
    target_compile_definitions(dawn_wire PUBLIC
        DAWN_WIRE_SHARED_LIBRARY
        DAWN_WIRE_IMPLEMENTATION
    )
endif()

###############################################################################
# Utils for tests and samples
###############################################################################

add_library(dawn_utils STATIC
    dawn/src/utils/ComboRenderBundleEncoderDescriptor.cpp
    dawn/src/utils/ComboRenderBundleEncoderDescriptor.h
    dawn/src/utils/ComboRenderPipelineDescriptor.cpp
    dawn/src/utils/ComboRenderPipelineDescriptor.h
    dawn/src/utils/DawnHelpers.cpp
    dawn/src/utils/DawnHelpers.h
    dawn/src/utils/SystemUtils.cpp
    dawn/src/utils/SystemUtils.h
    dawn/src/utils/TerribleCommandBuffer.cpp
    dawn/src/utils/TerribleCommandBuffer.h
    dawn/src/utils/Timer.h
    $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:dawn/src/utils/WindowsTimer.cpp>
    $<$<PLATFORM_ID:Darwin>:dawn/src/utils/OSXTimer.cpp>
    $<$<PLATFORM_ID:Linux>:dawn/src/utils/PosixTimer.cpp>
)

target_link_libraries(dawn_utils PUBLIC
    dawn_native
    dawn_wire
    dawn_common
    shaderc
)

add_library(dawn_bindings STATIC
    dawn/src/utils/BackendBinding.cpp
    dawn/src/utils/BackendBinding.h
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/utils/D3D12Binding.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/utils/MetalBinding.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/utils/NullBinding.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/utils/OpenGLBinding.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/utils/VulkanBinding.cpp>
)

target_link_libraries(dawn_bindings PUBLIC
    glfw
    dawn_native
    dawn_common
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${METAL_LIBRARIES}>
)

###############################################################################
# Dawn samples
###############################################################################

if(DAWN_BUILD_SAMPLES)

    # https://docs.hunter.sh/en/latest/packages/pkg/glm.html
    hunter_add_package(glm)
    find_package(glm CONFIG REQUIRED)

    # Static library to contain code and dependencies common to all samples
    add_library(dawn_sample_utils STATIC
        dawn/examples/SampleUtils.cpp
        dawn/examples/SampleUtils.h
    )
    target_link_libraries(dawn_sample_utils
        PUBLIC
            dawn_bindings
            dawn_utils
            dawn
    )

    unset(dawn_samples)

    macro(dawn_sample target_name)
        add_executable(${target_name} dawn/examples/${target_name})
        target_link_libraries(${target_name} PRIVATE dawn_sample_utils glm)
        list(APPEND dawn_samples ${target_name})
    endmacro()

    dawn_sample(CppHelloTriangle)
    dawn_sample(CHelloTriangle)
    dawn_sample(ComputeBoids)
    dawn_sample(Animometer)
    dawn_sample(CubeReflection)

endif()


###############################################################################
# Installation
###############################################################################
set(config_install_dir ${CMAKE_INSTALL_LIBDIR}/cmake/dawn)
set(generated_dir ${CMAKE_CURRENT_BINARY_DIR}/generated)
set(version_config ${generated_dir}/dawnConfigVersion.cmake)
set(project_config ${generated_dir}/dawnConfig.cmake)
set(TARGETS_EXPORT_NAME dawnTargets)
set(namespace dawn::)

write_basic_package_version_file(
    ${version_config}
    VERSION 1.0.0
    COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    cmake/config.cmake.in
    ${project_config}
    INSTALL_DESTINATION ${config_install_dir}
)

##
# Some targets from shaderc and dependents have absolute build paths in their
# INTERFACE_INCLUDE_DIRECTORIES. So let's fix that by hiding them from the
# install package by marking them as BUILD_INTERFACE. This will need to be fixed
# upstream in :
#    https://github.com/google/shaderc
#    https://github.com/KhronosGroup/glslang
##
get_property(shaderc_include_directory TARGET shaderc PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET shaderc PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${shaderc_include_directory}>)
get_property(glslang_include_directory TARGET glslang PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET glslang PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${glslang_include_directory}>)
get_property(shaderc_util_include_directory TARGET shaderc_util PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET shaderc_util PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${shaderc_util_include_directory}>)
get_property(spirv_include_directory TARGET SPIRV PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET SPIRV PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${spirv_include_directory}>)

##
# Another mistake found in SPIRV-Tools, where their
# INTERFACE_INCLUDE_DIRECTORIES points to nonexistant
# ${_IMPORT_PREFIX}/include/include. Because we're not using SPIRV-Tools headers
# directly (dawn uses it, but users of dawn most likely won't). This will need
# to be fixed upstream in :
#     https://github.com/KhronosGroup/SPIRV-Tools
##
get_property(SPIRV-Tools_include_directory TARGET SPIRV-Tools PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET SPIRV-Tools PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${SPIRV-Tools_include_directory}>)
get_property(SPIRV-Tools-opt_include_directory TARGET SPIRV-Tools-opt PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET SPIRV-Tools-opt PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${SPIRV-Tools-opt_include_directory}>)

##
# Similar thing in SPIRV-Cross... INTERFACE_INCLUDE_DIRECTORIES points to
# nonexistant ${_IMPORT_PREFIX}/include/spirv-cross, most likely happening
# because we are enabling SPIRV_CROSS_SKIP_INSTALL because it seems to be
# broken right now. Either way, this will need to be fixed upstream in :
#     https://github.com/KhronosGroup/SPIRV-Cross
##
get_property(spirv-cross-hlsl_include_directory TARGET spirv-cross-hlsl PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET spirv-cross-hlsl PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${spirv-cross-hlsl_include_directory}>)
get_property(spirv-cross-msl_include_directory TARGET spirv-cross-msl PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET spirv-cross-msl PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${spirv-cross-msl_include_directory}>)
get_property(spirv-cross-glsl_include_directory TARGET spirv-cross-glsl PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET spirv-cross-glsl PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${spirv-cross-glsl_include_directory}>)
get_property(spirv-cross-core_include_directory TARGET spirv-cross-core PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
set_property(TARGET spirv-cross-core PROPERTY INTERFACE_INCLUDE_DIRECTORIES $<BUILD_INTERFACE:${spirv-cross-core_include_directory}>)

install(
    TARGETS
        dawn
        dawn_utils
        dawn_bindings
        dawn_internal
        dawn_native
        dawn_wire
        dawn_common
        shaderc
        glslang
        OSDependent
        OGLCompiler
        shaderc_util
        SPIRV
        SPIRV-Tools
        SPIRV-Tools-opt
        HLSL
        spirv-cross-hlsl
        spirv-cross-msl
        spirv-cross-glsl
        spirv-cross-core
        ${dawn_samples}
    EXPORT ${TARGETS_EXPORT_NAME}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(
    DIRECTORY
        dawn/src/include/
        ${PROJECT_BINARY_DIR}/src/include/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(
    FILES
        dawn/src/utils/BackendBinding.h
        dawn/src/utils/ComboRenderBundleEncoderDescriptor.h
        dawn/src/utils/ComboRenderPipelineDescriptor.h
        dawn/src/utils/DawnHelpers.h
        dawn/src/utils/SystemUtils.h
        dawn/src/utils/TerribleCommandBuffer.h
        dawn/src/utils/Timer.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/utils
)

install(
    FILES
        dawn/src/common/Assert.h
        dawn/src/common/Compiler.h
        dawn/src/common/Constants.h
        dawn/src/common/Platform.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/common
)

install(
    FILES
        cmake/FindD3D12.cmake
        cmake/FindMetal.cmake
        ${project_config}
        ${version_config}
    DESTINATION ${config_install_dir}
)

install(
    EXPORT ${TARGETS_EXPORT_NAME}
    NAMESPACE ${namespace}
    DESTINATION ${config_install_dir}
)
