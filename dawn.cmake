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
target_link_libraries(dawn_headers INTERFACE dawn_public_include_dirs dawn_headers_gen)
target_sources(dawn_headers INTERFACE
    $<BUILD_INTERFACE:
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn/EnumClassBitmasks.h
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn/dawn_export.h
        ${PROJECT_SOURCE_DIR}/dawn/src/include/dawn/dawn_wsi.h
    >
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
target_link_libraries(dawn
    PUBLIC dawn_headers
    PRIVATE dawn_gen
)
if (BUILD_SHARED_LIBS)
    target_compile_definitions(dawn PUBLIC
        DAWN_SHARED_LIBRARY
        DAWN_IMPLEMENTATION
    )
endif()
