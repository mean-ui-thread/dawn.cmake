cmake_minimum_required(VERSION 3.10)
set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(dawn_generator)

project(dawn)

find_package(D3D12 QUIET)
find_package(METAL QUIET)
find_package(OpenGL QUIET)
find_package(X11 QUIET)
find_package(Vulkan QUIET)


if( CMAKE_BUILD_TYPE STREQUAL "Debug" )
    set(DAWN_ENABLE_ASSERTS ON)
else()
    set(DAWN_ENABLE_ASSERTS OFF)
endif()

option(DAWN_ENABLE_ASSERTS "Enable assert" ${DAWN_ENABLE_ASSERTS})
option(DAWN_ENABLE_BACKEND_D3D12 "Enable D3D12 Backend" ${D3D12_FOUND})
option(DAWN_ENABLE_BACKEND_METAL "Enable Metal Backend" ${METAL_FOUND})
option(DAWN_ENABLE_BACKEND_NULL "Enable Null Backend" ON)
option(DAWN_ENABLE_BACKEND_OPENGL "Enable OpenGL Backend" ${OPENGL_FOUND})
option(DAWN_ENABLE_BACKEND_VULKAN "Enable Vulkan Backend" ${Vulkan_FOUND})
option(DAWN_BUILD_SAMPLES "Builds Samples" ON)
option(SHADERC_SKIP_TESTS "Skip building tests" ON) #prevents looking up for gmock
option(SHADERC_ENABLE_SHARED_CRT "Use the shared CRT instead of the static CRT" ON) #prevents mixture of /MD with /MT.
option(GLFW_BUILD_EXAMPLES "Build the GLFW example programs" OFF)
option(GLFW_BUILD_TESTS "Build the GLFW test programs" OFF)
option(GLFW_BUILD_DOCS "Build the GLFW documentation" OFF)
option(GLFW_INSTALL "Generate installation target" OFF)

add_subdirectory(third_party/glslang)
add_subdirectory(third_party/spirv-headers)
add_subdirectory(third_party/SPIRV-Tools)
add_subdirectory(third_party/spirv-cross)
add_subdirectory(third_party/shaderc)
if(DAWN_BUILD_SAMPLES)
    add_subdirectory(third_party/glfw)
endif()

################################################################################
# dawn_headers
################################################################################
set(libdawn_headers_gen
    ${PROJECT_BINARY_DIR}/dawn/dawncpp.h
    ${PROJECT_BINARY_DIR}/dawn/dawn.h
)
dawn_json_generator(libdawn_headers_gen TARGET dawn_headers)

################################################################################
# dawn_native_utils
################################################################################
set(libdawn_native_utils_gen
    ${PROJECT_BINARY_DIR}/dawn_native/ProcTable.cpp
    ${PROJECT_BINARY_DIR}/dawn_native/dawn_structs_autogen.h
    ${PROJECT_BINARY_DIR}/dawn_native/dawn_structs_autogen.cpp
    ${PROJECT_BINARY_DIR}/dawn_native/ValidationUtils_autogen.h
    ${PROJECT_BINARY_DIR}/dawn_native/ValidationUtils_autogen.cpp
)
dawn_json_generator(libdawn_native_utils_gen TARGET dawn_native_utils)

################################################################################
# dawn_native_opengl_loader
################################################################################

if(DAWN_ENABLE_BACKEND_OPENGL)
    set(libdawn_native_opengl_loader_gen
        ${PROJECT_BINARY_DIR}/dawn_native/opengl/OpenGLFunctionsBase_autogen.cpp
        ${PROJECT_BINARY_DIR}/dawn_native/opengl/OpenGLFunctionsBase_autogen.h
        ${PROJECT_BINARY_DIR}/dawn_native/opengl/opengl_platform_autogen.h
    )
    dawn_generator(libdawn_native_opengl_loader_gen
        SCRIPT
            ${PROJECT_SOURCE_DIR}/dawn/generator/opengl_loader_generator.py
        ARGS
            --gl-xml ${PROJECT_SOURCE_DIR}/dawn/third_party/khronos/gl.xml
            --supported-extensions ${PROJECT_SOURCE_DIR}/dawn/src/dawn_native/opengl/supported_extensions.json
    )
endif()

################################################################################
# dawn_wire_headers
################################################################################
set(libdawn_wire_gen
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
dawn_json_generator(libdawn_wire_gen TARGET dawn_wire)

################################################################################
# libdawn
################################################################################

set(libdawn_gen
    ${PROJECT_BINARY_DIR}/dawn/dawncpp.cpp
    ${PROJECT_BINARY_DIR}/dawn/dawn.c
)
dawn_json_generator(libdawn_gen TARGET libdawn)

add_library(${PROJECT_NAME}
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

    dawn/src/dawn_native/Adapter.cpp
    dawn/src/dawn_native/Adapter.h
    dawn/src/dawn_native/AttachmentState.cpp
    dawn/src/dawn_native/AttachmentState.h
    dawn/src/dawn_native/BackendConnection.cpp
    dawn/src/dawn_native/BackendConnection.h
    dawn/src/dawn_native/BindGroup.cpp
    dawn/src/dawn_native/BindGroup.h
    dawn/src/dawn_native/BindGroupLayout.cpp
    dawn/src/dawn_native/BindGroupLayout.h
    dawn/src/dawn_native/BuddyAllocator.cpp
    dawn/src/dawn_native/BuddyAllocator.h
    dawn/src/dawn_native/Buffer.cpp
    dawn/src/dawn_native/Buffer.h
    dawn/src/dawn_native/CommandAllocator.cpp
    dawn/src/dawn_native/CommandAllocator.h
    dawn/src/dawn_native/CommandBuffer.cpp
    dawn/src/dawn_native/CommandBuffer.h
    dawn/src/dawn_native/CommandBufferStateTracker.cpp
    dawn/src/dawn_native/CommandBufferStateTracker.h
    dawn/src/dawn_native/CommandEncoder.cpp
    dawn/src/dawn_native/CommandEncoder.h
    dawn/src/dawn_native/CommandValidation.cpp
    dawn/src/dawn_native/CommandValidation.h
    dawn/src/dawn_native/Commands.cpp
    dawn/src/dawn_native/Commands.h
    dawn/src/dawn_native/ComputePassEncoder.cpp
    dawn/src/dawn_native/ComputePassEncoder.h
    dawn/src/dawn_native/ComputePipeline.cpp
    dawn/src/dawn_native/ComputePipeline.h
    dawn/src/dawn_native/Device.cpp
    dawn/src/dawn_native/Device.h
    dawn/src/dawn_native/DynamicUploader.cpp
    dawn/src/dawn_native/DynamicUploader.h
    dawn/src/dawn_native/EncodingContext.cpp
    dawn/src/dawn_native/EncodingContext.h
    dawn/src/dawn_native/Error.cpp
    dawn/src/dawn_native/Error.h
    dawn/src/dawn_native/ErrorData.cpp
    dawn/src/dawn_native/ErrorData.h
    dawn/src/dawn_native/ErrorScope.cpp
    dawn/src/dawn_native/ErrorScope.h
    dawn/src/dawn_native/Extensions.cpp
    dawn/src/dawn_native/Extensions.h
    dawn/src/dawn_native/Fence.cpp
    dawn/src/dawn_native/Fence.h
    dawn/src/dawn_native/FenceSignalTracker.cpp
    dawn/src/dawn_native/FenceSignalTracker.h
    dawn/src/dawn_native/Format.cpp
    dawn/src/dawn_native/Format.h
    dawn/src/dawn_native/Forward.h
    dawn/src/dawn_native/Instance.cpp
    dawn/src/dawn_native/Instance.h
    dawn/src/dawn_native/ObjectBase.cpp
    dawn/src/dawn_native/ObjectBase.h
    dawn/src/dawn_native/PassResourceUsage.h
    dawn/src/dawn_native/PassResourceUsageTracker.cpp
    dawn/src/dawn_native/PassResourceUsageTracker.h
    dawn/src/dawn_native/PerStage.cpp
    dawn/src/dawn_native/PerStage.h
    dawn/src/dawn_native/Pipeline.cpp
    dawn/src/dawn_native/Pipeline.h
    dawn/src/dawn_native/PipelineLayout.cpp
    dawn/src/dawn_native/PipelineLayout.h
    dawn/src/dawn_native/ProgrammablePassEncoder.cpp
    dawn/src/dawn_native/ProgrammablePassEncoder.h
    dawn/src/dawn_native/Queue.cpp
    dawn/src/dawn_native/Queue.h
    dawn/src/dawn_native/RefCounted.cpp
    dawn/src/dawn_native/RefCounted.h
    dawn/src/dawn_native/RenderBundle.cpp
    dawn/src/dawn_native/RenderBundle.h
    dawn/src/dawn_native/RenderBundleEncoder.cpp
    dawn/src/dawn_native/RenderBundleEncoder.h
    dawn/src/dawn_native/RenderEncoderBase.cpp
    dawn/src/dawn_native/RenderEncoderBase.h
    dawn/src/dawn_native/RenderPassEncoder.cpp
    dawn/src/dawn_native/RenderPassEncoder.h
    dawn/src/dawn_native/RenderPipeline.cpp
    dawn/src/dawn_native/RenderPipeline.h
    dawn/src/dawn_native/ResourceHeap.h
    dawn/src/dawn_native/ResourceMemoryAllocation.cpp
    dawn/src/dawn_native/ResourceMemoryAllocation.h
    dawn/src/dawn_native/RingBuffer.cpp
    dawn/src/dawn_native/RingBuffer.h
    dawn/src/dawn_native/Sampler.cpp
    dawn/src/dawn_native/Sampler.h
    dawn/src/dawn_native/ShaderModule.cpp
    dawn/src/dawn_native/ShaderModule.h
    dawn/src/dawn_native/StagingBuffer.cpp
    dawn/src/dawn_native/StagingBuffer.h
    dawn/src/dawn_native/SwapChain.cpp
    dawn/src/dawn_native/SwapChain.h
    dawn/src/dawn_native/Texture.cpp
    dawn/src/dawn_native/Texture.h
    dawn/src/dawn_native/ToBackend.h
    dawn/src/dawn_native/Toggles.cpp
    dawn/src/dawn_native/Toggles.h
    dawn/src/dawn_native/dawn_platform.h
    dawn/src/dawn_native/DawnNative.cpp
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/AdapterD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/AdapterD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BackendD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BackendD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BindGroupD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BindGroupD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BindGroupLayoutD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BindGroupLayoutD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BufferD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/BufferD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/CommandAllocatorManager.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/CommandAllocatorManager.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/CommandBufferD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/CommandBufferD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/CommittedResourceAllocatorD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/CommittedResourceAllocatorD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ComputePipelineD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ComputePipelineD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/D3D12Info.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/D3D12Info.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/DescriptorHeapAllocator.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/DescriptorHeapAllocator.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/DeviceD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/DeviceD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/NativeSwapChainImplD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/NativeSwapChainImplD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/PipelineLayoutD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/PipelineLayoutD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/PlatformFunctions.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/PlatformFunctions.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/QueueD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/QueueD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/RenderPipelineD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/RenderPipelineD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ResourceAllocator.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ResourceAllocator.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ResourceHeapD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ResourceHeapD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/SamplerD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/SamplerD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ShaderModuleD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/ShaderModuleD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/StagingBufferD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/StagingBufferD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/SwapChainD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/SwapChainD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/TextureCopySplitter.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/TextureCopySplitter.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/TextureD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/TextureD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/UtilsD3D12.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/UtilsD3D12.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/d3d12_platform.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/dawn_native/d3d12/D3D12Backend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/BackendMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/BackendMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/BufferMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/BufferMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/CommandBufferMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/CommandBufferMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/ComputePipelineMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/ComputePipelineMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/DeviceMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/DeviceMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/PipelineLayoutMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/PipelineLayoutMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/QueueMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/QueueMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/RenderPipelineMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/RenderPipelineMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/SamplerMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/SamplerMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/ShaderModuleMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/ShaderModuleMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/StagingBufferMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/StagingBufferMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/SwapChainMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/SwapChainMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/TextureMTL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/TextureMTL.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/UtilsMetal.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/UtilsMetal.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/dawn_native/metal/MetalBackend.mm>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/dawn_native/null/DeviceNull.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/dawn_native/null/DeviceNull.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/dawn_native/null/NullBackend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/BackendGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/BackendGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/BufferGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/BufferGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/CommandBufferGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/CommandBufferGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/ComputePipelineGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/ComputePipelineGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/DeviceGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/DeviceGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/GLFormat.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/GLFormat.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/NativeSwapChainImplGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/NativeSwapChainImplGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/OpenGLFunctions.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/OpenGLFunctions.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/PersistentPipelineStateGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/PersistentPipelineStateGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/PipelineGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/PipelineGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/PipelineLayoutGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/PipelineLayoutGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/QueueGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/QueueGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/RenderPipelineGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/RenderPipelineGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/SamplerGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/SamplerGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/ShaderModuleGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/ShaderModuleGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/SwapChainGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/SwapChainGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/TextureGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/TextureGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/UtilsGL.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/UtilsGL.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/opengl_platform.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/dawn_native/opengl/OpenGLBackend.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/AdapterVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/AdapterVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BackendVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BackendVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BindGroupLayoutVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BindGroupLayoutVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BindGroupVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BindGroupVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BufferVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/BufferVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/CommandBufferVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/CommandBufferVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ComputePipelineVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ComputePipelineVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/DeviceVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/DeviceVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ExternalHandle.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/FencedDeleter.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/FencedDeleter.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/Forward.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/MemoryAllocator.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/MemoryAllocator.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/MemoryResourceAllocatorVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/MemoryResourceAllocatorVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/NativeSwapChainImplVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/NativeSwapChainImplVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/PipelineLayoutVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/PipelineLayoutVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/QueueVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/QueueVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/RenderPassCache.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/RenderPassCache.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/RenderPipelineVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/RenderPipelineVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ResourceMemoryVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ResourceMemoryVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/SamplerVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/SamplerVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ShaderModuleVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/ShaderModuleVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/StagingBufferVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/StagingBufferVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/SwapChainVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/SwapChainVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/TextureVk.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/TextureVk.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/UtilsVulkan.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/UtilsVulkan.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanError.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanError.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanFunctions.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanFunctions.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanInfo.cpp>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanInfo.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/external_memory/MemoryService.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/external_semaphore/SemaphoreService.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/dawn_native/vulkan/VulkanBackend.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<PLATFORM_ID:Linux>>:dawn/src/dawn_native/vulkan/external_memory/MemoryServiceOpaqueFD.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<PLATFORM_ID:Linux>>:dawn/src/dawn_native/vulkan/external_semaphore/SemaphoreServiceOpaqueFD.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<NOT:$<PLATFORM_ID:Linux>>>:dawn/src/dawn_native/vulkan/external_memory/MemoryServiceNull.cpp>
    $<$<AND:$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>,$<NOT:$<PLATFORM_ID:Linux>>>:dawn/src/dawn_native/vulkan/external_semaphore/SemaphoreServiceNull.cpp>

    dawn/src/dawn_platform/tracing/EventTracer.cpp
    dawn/src/dawn_platform/tracing/EventTracer.h
    dawn/src/dawn_platform/tracing/TraceEvent.h

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

    dawn/src/include/dawn_platform/DawnPlatform.h
    dawn/src/include/dawn/EnumClassBitmasks.h
    dawn/src/include/dawn/dawn_export.h
    dawn/src/include/dawn/dawn_wsi.h
    dawn/src/include/dawn_native/DawnNative.h
    dawn/src/include/dawn_native/dawn_native_export.h
    $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/include/dawn_native/D3D12Backend.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/include/dawn_native/MetalBackend.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/include/dawn_native/NullBackend.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/include/dawn_native/OpenGLBackend.h>
    $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/include/dawn_native/VulkanBackend.h>
    dawn/src/include/dawn_wire/Wire.h
    dawn/src/include/dawn_wire/WireClient.h
    dawn/src/include/dawn_wire/WireServer.h
    dawn/src/include/dawn_wire/dawn_wire_export.h

    ${libdawn_headers_gen}
    ${libdawn_gen}
    ${libdawn_native_utils_gen}
    ${libdawn_native_opengl_loader_gen}
    ${libdawn_wire_gen}
)

target_compile_definitions(${PROJECT_NAME}
    PUBLIC
        $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:NOMINMAX>
        $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:_CRT_SECURE_NO_WARNINGS>
        $<$<BOOL:${DAWN_ENABLE_ASSERTS}>:DAWN_ENABLE_ASSERTS=1>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:DAWN_ENABLE_BACKEND_D3D12>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:DAWN_ENABLE_BACKEND_METAL>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:DAWN_ENABLE_BACKEND_NULL>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:DAWN_ENABLE_BACKEND_OPENGL>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:DAWN_ENABLE_BACKEND_VULKAN>
        $<$<BOOL:${X11_FOUND}>:DAWN_USE_X11>
)

target_include_directories(${PROJECT_NAME}
    PUBLIC
        $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/dawn/src/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${PROJECT_BINARY_DIR}
        ${PROJECT_SOURCE_DIR}/dawn/src/
        ${PROJECT_SOURCE_DIR}/dawn/third_party/khronos
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${D3D12_INCLUDE_DIRS}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${METAL_INCLUDE_DIR}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${OPENGL_INCLUDE_DIR}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${Vulkan_INCLUDE_DIRS}>
        $<$<BOOL:${X11_FOUND}>:${X11_INCLUDE_DIR}>
)

target_link_libraries(${PROJECT_NAME}
    PUBLIC
        spirv-cross-glsl
        spirv-cross-hlsl
        spirv-cross-msl
        SPIRV-Tools
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:${D3D12_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:${METAL_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:${OPENGL_LIBRARIES}>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:${Vulkan_LIBRARIES}>
        $<$<BOOL:${X11_FOUND}>:${X11_LIBRARIES}>
)

if(DAWN_BUILD_SAMPLES)

    add_library(${PROJECT_NAME}_sample_utils STATIC
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
        dawn/src/utils/BackendBinding.cpp
        dawn/src/utils/BackendBinding.h
        $<$<PLATFORM_ID:Cygwin,MinGW,Windows>:dawn/src/utils/WindowsTimer.cpp>
        $<$<PLATFORM_ID:Darwin>:dawn/src/utils/OSXTimer.cpp>
        $<$<PLATFORM_ID:Linux>:dawn/src/utils/PosixTimer.cpp>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_D3D12}>:dawn/src/utils/D3D12Binding.cpp>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_METAL}>:dawn/src/utils/MetalBinding.mm>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_NULL}>:dawn/src/utils/NullBinding.cpp>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_OPENGL}>:dawn/src/utils/OpenGLBinding.cpp>
        $<$<BOOL:${DAWN_ENABLE_BACKEND_VULKAN}>:dawn/src/utils/VulkanBinding.cpp>
        dawn/examples/SampleUtils.cpp
        dawn/examples/SampleUtils.h
    )

    target_include_directories(${PROJECT_NAME}_sample_utils
        PUBLIC
            ${PROJECT_SOURCE_DIR}/third_party/glm
            ${PROJECT_SOURCE_DIR}/dawn/src/
            ${PROJECT_BINARY_DIR}
    )

    target_link_libraries(${PROJECT_NAME}_sample_utils
        PUBLIC
            ${PROJECT_NAME}
            shaderc_shared
            glfw
    )

    macro(dawn_sample target_name)
        add_executable(${target_name} dawn/examples/${target_name})
        target_link_libraries(${target_name} PUBLIC ${PROJECT_NAME}_sample_utils)
    endmacro()

    dawn_sample(CppHelloTriangle)
    dawn_sample(CHelloTriangle)
    dawn_sample(ComputeBoids)
    dawn_sample(Animometer)
    dawn_sample(CubeReflection)


endif()
