include_guard(GLOBAL)
include(CMakeParseArguments)
find_package(Python2 QUIET REQUIRED)

function(dawn_generator sources)
    cmake_parse_arguments(
        IN
        "" # option
        "SCRIPT" #single
        "ARGS" #multi
        ${ARGN}
    )

    if(NOT ${sources})
        message(FATAL_ERROR "dawn_generator: You must provide a name as a first argument")
    endif()

    if(NOT IN_SCRIPT)
        message(FATAL_ERROR "dawn_generator: You must provide a SCRIPT")
    endif()

    set(_json_tarball ${PROJECT_BINARY_DIR}/${sources}.json_tarball)
    set(_json_tarball_depfile ${_json_tarball}.d)

    add_custom_command(
        COMMAND
            ${Python2_EXECUTABLE}
            ${IN_SCRIPT}
            ${IN_ARGS}
            --root-dir ${PROJECT_SOURCE_DIR}/dawn
            --template-dir ${PROJECT_SOURCE_DIR}/dawn/generator/templates
            --jinja2-path ${PROJECT_SOURCE_DIR}/third_party/jinja2
            --output-json-tarball ${_json_tarball}
            --depfile ${_json_tarball_depfile}
        OUTPUT
            ${_json_tarball}
            ${_json_tarball_depfile}
        DEPENDS
            ${IN_SCRIPT}
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
            ${${sources}}
        DEPENDS
            ${_json_tarball}
            ${_json_tarball_depfile}
    )
endfunction()

function(dawn_json_generator sources)

    cmake_parse_arguments(
        IN
        "" # option
        "TARGET" #single
        "" #multi
        ${ARGN}
    )

    if(NOT IN_TARGET)
        message(FATAL_ERROR "dawn_json_generator: You must provide a TARGET")
    endif()

    dawn_generator(${sources}
        SCRIPT ${PROJECT_SOURCE_DIR}/dawn/generator/dawn_json_generator.py
        ARGS
            --dawn-json ${PROJECT_SOURCE_DIR}/dawn/dawn.json
            --wire-json ${PROJECT_SOURCE_DIR}/dawn/dawn_wire.json
            --targets ${IN_TARGET}
    )

endfunction()
