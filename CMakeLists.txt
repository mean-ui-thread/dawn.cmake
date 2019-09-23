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
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)
include(dawn_generator)

project(dawn)

find_package(D3D12 QUIET)
find_package(METAL QUIET)
find_package(OpenGL QUIET)
find_package(X11 QUIET)
find_package(Vulkan QUIET)
find_package(Python3 QUIET REQUIRED)

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
set(target_gen_dir ${PROJECT_BINARY_DIR})

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
# including targets, deps, configs, etc
###############################################################################

include(third_party.cmake)
include(common.cmake)
include(dawn.cmake)
include(dawn_wire.cmake)

###############################################################################
# dawn_platform
###############################################################################

add_library(dawn_platform INTERFACE)
target_link_libraries(dawn_platform INTERFACE dawn_internal dawn_common)
target_sources(dawn_platform INTERFACE
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn_platform/DawnPlatform.h
        ${PROJECT_SOURCE_DIR}/dawn/src/dawn_platform/tracing/EventTracer.cpp
        ${PROJECT_SOURCE_DIR}/dawn/src/dawn_platform/tracing/EventTracer.h
        ${PROJECT_SOURCE_DIR}/dawn/src/dawn_platform/tracing/TraceEvent.h
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
        ${PROJECT_BINARY_DIR}/dawn_native/ProcTable.cpp
        ${PROJECT_BINARY_DIR}/dawn_native/dawn_structs_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_native/dawn_structs_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_native/ValidationUtils_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_native/ValidationUtils_autogen.cpp
)

if(DAWN_ENABLE_BACKEND_OPENGL)
    dawn_generator(dawn_native_opengl_loader_gen
        script
            ${PROJECT_SOURCE_DIR}/dawn/generator/opengl_loader_generator.py
        args
            --gl-xml ${PROJECT_SOURCE_DIR}/dawn/third_party/khronos/gl.xml
            --supported-extensions ${PROJECT_SOURCE_DIR}/dawn/src/dawn_native/opengl/supported_extensions.json
        outputs
            ${PROJECT_BINARY_DIR}/dawn_native/opengl/OpenGLFunctionsBase_autogen.cpp
            ${PROJECT_BINARY_DIR}/dawn_native/opengl/OpenGLFunctionsBase_autogen.h
            ${PROJECT_BINARY_DIR}/dawn_native/opengl/opengl_platform_autogen.h
    )
endif()

# Public dawn_native headers so they can be publically visible for
# dependencies of dawn_native
add_library(dawn_native_headers INTERFACE)
target_link_libraries(dawn_native_headers INTERFACE dawn_headers dawn_public_include_dirs)
target_sources(dawn_native_headers INTERFACE
    ${dawn_root}/src/include/dawn_native/DawnNative.h
    ${dawn_root}/src/include/dawn_native/dawn_native_export.h

    # Include all backend's public headers so that dependencies can include
    # them even when the backends are disabled.
    ${dawn_root}/src/include/dawn_native/D3D12Backend.h
    ${dawn_root}/src/include/dawn_native/MetalBackend.h
    ${dawn_root}/src/include/dawn_native/NullBackend.h
    ${dawn_root}/src/include/dawn_native/OpenGLBackend.h
    ${dawn_root}/src/include/dawn_native/VulkanBackend.h
)

# The meat of the compilation for dawn_native so that we can cheaply have
# shared_library / static_library versions of it. It compiles all the files
# except those that define exported symbols.
add_library(dawn_native_sources INTERFACE)
target_link_libraries(dawn_native_sources INTERFACE
        dawn_native_headers
        dawn_native_utils_gen
        dawn_common
        SPIRV-Tools
        spirv-cross-glsl
        spirv-cross-hlsl
        spirv-cross-msl
        dawn_native_internal
        dawn_platform
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn_native_opengl_loader_gen>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:khronos_platform>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:vulkan_headers>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${D3D12_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${METAL_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${OPENGL_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${Vulkan_LIBRARIES}>

)
target_sources(dawn_native_sources INTERFACE
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
    ${dawn_root}/src/dawn_native/RingBuffer.cpp
    ${dawn_root}/src/dawn_native/RingBuffer.h
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

    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/AdapterD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/AdapterD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BackendD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BackendD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BindGroupD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BindGroupD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BindGroupLayoutD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BindGroupLayoutD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BufferD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/BufferD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/CommandAllocatorManager.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/CommandAllocatorManager.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/CommandBufferD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/CommandBufferD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/CommittedResourceAllocatorD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/CommittedResourceAllocatorD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ComputePipelineD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ComputePipelineD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/D3D12Info.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/D3D12Info.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/DescriptorHeapAllocator.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/DescriptorHeapAllocator.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/DeviceD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/DeviceD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/NativeSwapChainImplD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/NativeSwapChainImplD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/PipelineLayoutD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/PipelineLayoutD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/PlatformFunctions.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/PlatformFunctions.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/QueueD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/QueueD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/RenderPipelineD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/RenderPipelineD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ResourceAllocator.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ResourceAllocator.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ResourceHeapD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ResourceHeapD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/SamplerD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/SamplerD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ShaderModuleD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/ShaderModuleD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/StagingBufferD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/StagingBufferD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/SwapChainD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/SwapChainD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/TextureCopySplitter.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/TextureCopySplitter.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/TextureD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/TextureD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/UtilsD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/UtilsD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/d3d12_platform.h>

    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/BackendMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/BackendMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/BufferMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/BufferMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/CommandBufferMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/CommandBufferMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/ComputePipelineMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/ComputePipelineMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/DeviceMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/DeviceMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/PipelineLayoutMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/PipelineLayoutMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/QueueMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/QueueMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/RenderPipelineMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/RenderPipelineMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/SamplerMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/SamplerMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/ShaderModuleMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/ShaderModuleMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/StagingBufferMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/StagingBufferMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/SwapChainMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/SwapChainMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/TextureMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/TextureMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/UtilsMetal.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/UtilsMetal.mm>

    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:${dawn_root}/src/dawn_native/null/DeviceNull.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:${dawn_root}/src/dawn_native/null/DeviceNull.h>

    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/BackendGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/BackendGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/BufferGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/BufferGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/CommandBufferGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/CommandBufferGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/ComputePipelineGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/ComputePipelineGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/DeviceGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/DeviceGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/GLFormat.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/GLFormat.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/NativeSwapChainImplGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/NativeSwapChainImplGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/OpenGLFunctions.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/OpenGLFunctions.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/PersistentPipelineStateGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/PersistentPipelineStateGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/PipelineGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/PipelineGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/PipelineLayoutGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/PipelineLayoutGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/QueueGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/QueueGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/RenderPipelineGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/RenderPipelineGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/SamplerGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/SamplerGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/ShaderModuleGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/ShaderModuleGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/SwapChainGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/SwapChainGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/TextureGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/TextureGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/UtilsGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/UtilsGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/opengl_platform.h>

    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/AdapterVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/AdapterVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BackendVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BackendVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BindGroupLayoutVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BindGroupLayoutVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BindGroupVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BindGroupVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BufferVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/BufferVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/CommandBufferVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/CommandBufferVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ComputePipelineVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ComputePipelineVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/DeviceVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/DeviceVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ExternalHandle.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/FencedDeleter.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/FencedDeleter.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/MemoryAllocator.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/MemoryAllocator.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/MemoryResourceAllocatorVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/MemoryResourceAllocatorVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/NativeSwapChainImplVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/NativeSwapChainImplVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/PipelineLayoutVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/PipelineLayoutVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/QueueVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/QueueVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/RenderPassCache.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/RenderPassCache.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/RenderPipelineVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/RenderPipelineVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ResourceMemoryVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ResourceMemoryVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/SamplerVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/SamplerVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ShaderModuleVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/ShaderModuleVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/StagingBufferVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/StagingBufferVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/SwapChainVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/SwapChainVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/TextureVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/TextureVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/UtilsVulkan.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/UtilsVulkan.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanError.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanError.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanFunctions.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanFunctions.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanInfo.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanInfo.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/external_memory/MemoryService.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/external_semaphore/SemaphoreService.h>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<PLATFORM_ID:Linux>>:${dawn_root}/src/dawn_native/vulkan/external_memory/MemoryServiceOpaqueFD.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<PLATFORM_ID:Linux>>:${dawn_root}/src/dawn_native/vulkan/external_semaphore/SemaphoreServiceOpaqueFD.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<NOT:$<PLATFORM_ID:Linux>>>:${dawn_root}/src/dawn_native/vulkan/external_memory/MemoryServiceNull.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<NOT:$<PLATFORM_ID:Linux>>>:${dawn_root}/src/dawn_native/vulkan/external_semaphore/SemaphoreServiceNull.cpp>
)

# The static and shared libraries for dawn_native. Most of the files are
# already compiled in dawn_native_sources, but we still need to compile
# files defining exported symbols.
add_library(dawn_native
    ${dawn_root}/src/dawn_native/DawnNative.cpp
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/dawn_native/d3d12/D3D12Backend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/dawn_native/metal/MetalBackend.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:${dawn_root}/src/dawn_native/null/NullBackend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/dawn_native/opengl/OpenGLBackend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/dawn_native/vulkan/VulkanBackend.cpp>
)

target_link_libraries(dawn_native
    PUBLIC
        dawn_native_headers

    PRIVATE
        dawn_native_sources
        dawn_common
        dawn_native_internal
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
        ${PROJECT_BINARY_DIR}/dawn_wire/WireCmd_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_wire/WireCmd_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_wire/client/ApiObjects_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_wire/client/ApiProcs_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_wire/client/ApiProcs_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_wire/client/ClientBase_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_wire/client/ClientHandlers_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_wire/client/ClientPrototypes_autogen.inc
        ${PROJECT_BINARY_DIR}/dawn_wire/server/ServerBase_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_wire/server/ServerDoers_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_wire/server/ServerHandlers_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_wire/server/ServerPrototypes_autogen.inc
)

add_library(dawn_wire
    ${dawn_root}/src/dawn_wire/WireClient.cpp
    ${dawn_root}/src/dawn_wire/WireDeserializeAllocator.cpp
    ${dawn_root}/src/dawn_wire/WireDeserializeAllocator.h
    ${dawn_root}/src/dawn_wire/WireServer.cpp
    ${dawn_root}/src/dawn_wire/client/ApiObjects.h
    ${dawn_root}/src/dawn_wire/client/ApiProcs.cpp
    ${dawn_root}/src/dawn_wire/client/Buffer.cpp
    ${dawn_root}/src/dawn_wire/client/Buffer.h
    ${dawn_root}/src/dawn_wire/client/Client.cpp
    ${dawn_root}/src/dawn_wire/client/Client.h
    ${dawn_root}/src/dawn_wire/client/ClientDoers.cpp
    ${dawn_root}/src/dawn_wire/client/ClientInlineMemoryTransferService.cpp
    ${dawn_root}/src/dawn_wire/client/Device.cpp
    ${dawn_root}/src/dawn_wire/client/Device.h
    ${dawn_root}/src/dawn_wire/client/Fence.cpp
    ${dawn_root}/src/dawn_wire/client/Fence.h
    ${dawn_root}/src/dawn_wire/client/ObjectAllocator.h
    ${dawn_root}/src/dawn_wire/server/ObjectStorage.h
    ${dawn_root}/src/dawn_wire/server/Server.cpp
    ${dawn_root}/src/dawn_wire/server/Server.h
    ${dawn_root}/src/dawn_wire/server/ServerBuffer.cpp
    ${dawn_root}/src/dawn_wire/server/ServerDevice.cpp
    ${dawn_root}/src/dawn_wire/server/ServerFence.cpp
    ${dawn_root}/src/dawn_wire/server/ServerInlineMemoryTransferService.cpp
    ${dawn_root}/src/dawn_wire/server/ServerQueue.cpp
)

target_link_libraries(dawn_wire
    PUBLIC
        dawn_wire_headers
    PRIVATE
        dawn_wire_gen
        dawn_common
        dawn_internal
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
    ${dawn_root}/src/utils/ComboRenderBundleEncoderDescriptor.cpp
    ${dawn_root}/src/utils/ComboRenderBundleEncoderDescriptor.h
    ${dawn_root}/src/utils/ComboRenderPipelineDescriptor.cpp
    ${dawn_root}/src/utils/ComboRenderPipelineDescriptor.h
    ${dawn_root}/src/utils/DawnHelpers.cpp
    ${dawn_root}/src/utils/DawnHelpers.h
    ${dawn_root}/src/utils/SystemUtils.cpp
    ${dawn_root}/src/utils/SystemUtils.h
    ${dawn_root}/src/utils/TerribleCommandBuffer.cpp
    ${dawn_root}/src/utils/TerribleCommandBuffer.h
    ${dawn_root}/src/utils/Timer.h
    $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:${dawn_root}/src/utils/WindowsTimer.cpp>
    $<$<PLATFORM_ID:Darwin>:${dawn_root}/src/utils/OSXTimer.cpp>
    $<$<PLATFORM_ID:Linux>:${dawn_root}/src/utils/PosixTimer.cpp>
)

target_link_libraries(dawn_utils
    PUBLIC
        dawn_headers
    PRIVATE
        dawn_internal
        dawn_native
        dawn_wire
        dawn_common
        shaderc
)

add_library(dawn_bindings STATIC
    ${dawn_root}/src/utils/BackendBinding.cpp
    ${dawn_root}/src/utils/BackendBinding.h
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${dawn_root}/src/utils/D3D12Binding.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${dawn_root}/src/utils/MetalBinding.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:${dawn_root}/src/utils/NullBinding.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${dawn_root}/src/utils/OpenGLBinding.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${dawn_root}/src/utils/VulkanBinding.cpp>
)

target_link_libraries(dawn_bindings
    PUBLIC
        dawn_headers
    PRIVATE
        dawn_internal
        glfw
        dawn_native
        dawn_common
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${METAL_LIBRARIES}>
)

###############################################################################
# Dawn samples
###############################################################################

if(DAWN_BUILD_SAMPLES)

    # Static library to contain code and dependencies common to all samples
    add_library(dawn_sample_utils STATIC
        ${dawn_root}/examples/SampleUtils.cpp
        ${dawn_root}/examples/SampleUtils.h
    )
    target_link_libraries(dawn_sample_utils
        PUBLIC
            dawn_bindings
            glfw
            dawn_utils
            dawn_native
            dawn_wire
            dawn_common
            dawn
            dawn_internal
    )

    macro(dawn_sample target_name)
        add_executable(${target_name} dawn/examples/${target_name})
        target_link_libraries(${target_name} PUBLIC dawn_sample_utils)
    endmacro()

    dawn_sample(CppHelloTriangle)
    dawn_sample(CHelloTriangle)
    dawn_sample(ComputeBoids)
    dawn_sample(Animometer)
    dawn_sample(CubeReflection)

    target_include_directories(ComputeBoids PUBLIC ${PROJECT_SOURCE_DIR}/third_party/glm)
    target_include_directories(CubeReflection PUBLIC ${PROJECT_SOURCE_DIR}/third_party/glm)

endif()
