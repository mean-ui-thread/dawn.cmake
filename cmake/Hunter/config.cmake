hunter_config(glfw
    VERSION 3.3.0-f9923e9-p0
    CMAKE_ARGS OpenGL_GL_PREFERENCE=GLVND
)

hunter_config(glm
    VERSION 0.9.9.2
    CMAKE_ARGS GLM_TEST_ENABLE=OFF BUILD_SHARED_LIBS=OFF BUILD_STATIC_LIBS=OFF
)

hunter_config(SPIRV-Headers
    VERSION 1.5.1
    URL https://github.com/KhronosGroup/SPIRV-Headers/archive/1.5.1.tar.gz
    SHA1 77018bfe6cb1eceaf824e401dbd206660a25bf66
    CMAKE_ARGS SPIRV_HEADERS_SKIP_EXAMPLES=ON
)

hunter_config(SPIRV-Tools
    VERSION v2019.4-p0
    URL https://github.com/mchiasson/SPIRV-Tools/archive/v2019.4-p0.tar.gz
    SHA1 fde8521fd5c99166de934d7d7d65800940dfba93
    CMAKE_ARGS BUILD_TESTING=OFF SPIRV_SKIP_EXECUTABLES=ON SPIRV_SKIP_TESTS=ON
)

hunter_config(mattc_glslang
    VERSION v7.12.3352-p1
    URL https://github.com/mchiasson/glslang/archive/v7.12.3352-p1.tar.gz
    SHA1 d25c10c725f71cc6b7eb5fa2140b9b4d7c06f74c
    CMAKE_ARGS BUILD_TESTING=OFF ENABLE_GLSLANG_BINARIES=OFF ENABLE_HLSL=ON
)

hunter_config(mattc_SPIRV-Cross
    VERSION v2019.09.06-p2
    URL https://github.com/mchiasson/SPIRV-Cross/archive/v2019.09.06-p2.tar.gz
    SHA1 fd82bceef9be48903b604166346984102a4eb1c0
    CMAKE_ARGS BUILD_TESTING=OFF SPIRV_CROSS_CLI=OFF SPIRV_CROSS_ENABLE_TESTS=OFF SPIRV_CROSS_FORCE_PIC=ON
)

hunter_config(shaderc
    VERSION v2019.0-p5
    URL https://github.com/mchiasson/shaderc/archive/v2019.0-p5.tar.gz
    SHA1 e63f63e89bce234767e671f6d14ca94a1ecaa0d9
    CMAKE_ARGS BUILD_TESTING=OFF SHADERC_ENABLE_SPVC=ON SHADERC_SKIP_TESTS=ON
)
