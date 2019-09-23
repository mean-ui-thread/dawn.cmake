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
include(CMakeParseArguments)
find_package(Python2 QUIET REQUIRED)

function(dawn_generator target_name)
    cmake_parse_arguments(
        IN
        "" # option
        "script" #single
        "outputs;args" #multi
        ${ARGN}
    )

    if(NOT IN_script)
        message(FATAL_ERROR "dawn_generator: You must provide a script")
    endif()

    if(NOT IN_outputs)
        message(FATAL_ERROR "dawn_generator: You must provide one or more outputs")
    endif()

    set(_json_tarball ${PROJECT_BINARY_DIR}/${target_name}.json_tarball)
    set(_json_tarball_depfile ${_json_tarball}.d)

    add_custom_command(
        COMMAND
            ${Python2_EXECUTABLE}
            ${IN_script}
            ${IN_args}
            --root-dir ${PROJECT_SOURCE_DIR}/dawn
            --template-dir ${PROJECT_SOURCE_DIR}/dawn/generator/templates
            --jinja2-path ${PROJECT_SOURCE_DIR}/third_party/jinja2
            --output-json-tarball ${_json_tarball}
            --depfile ${_json_tarball_depfile}
        OUTPUT
            ${_json_tarball}
            ${_json_tarball_depfile}
        DEPENDS
            ${IN_script}
            ${PROJECT_SOURCE_DIR}/dawn/dawn.json
            ${PROJECT_SOURCE_DIR}/dawn/dawn_wire.json
    )

    add_custom_command(
        COMMAND
            ${Python2_EXECUTABLE}
            ${PROJECT_SOURCE_DIR}/dawn/generator/extract_json.py
            ${_json_tarball}
            ${PROJECT_BINARY_DIR}
        OUTPUT
            ${IN_outputs}
        DEPENDS
            ${_json_tarball}
            ${_json_tarball_depfile}
    )

    add_library(${target_name} INTERFACE)
    target_sources(${target_name} INTERFACE $<BUILD_INTERFACE:${IN_outputs}>)
endfunction()

function(dawn_json_generator target_name)

    cmake_parse_arguments(
        IN
        "" # option
        "target" #single
        "outputs" #multi
        ${ARGN}
    )

    if(NOT IN_target)
        message(FATAL_ERROR "dawn_json_generator: You must provide a target")
    endif()

    if(NOT IN_outputs)
        message(FATAL_ERROR "dawn_json_generator: You must provide one or more outputs")
    endif()

    dawn_generator(${target_name}
        outputs ${IN_outputs}
        script ${PROJECT_SOURCE_DIR}/dawn/generator/dawn_json_generator.py
        args
            --dawn-json ${PROJECT_SOURCE_DIR}/dawn/dawn.json
            --wire-json ${PROJECT_SOURCE_DIR}/dawn/dawn_wire.json
            --targets ${IN_target}
    )

endfunction()
