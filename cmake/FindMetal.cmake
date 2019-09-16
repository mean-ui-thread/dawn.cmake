if(APPLE)
    find_path( METAL_INCLUDE_DIR
        Metal/Metal.h
    )

    find_library( METAL_FRAMEWORKS Metal )

    if(METAL_FRAMEWORKS)
        set( METAL_LIBRARIES "-framework Metal -framework QuartzCore -framework Foundation" )
    endif()
endif()


include(FindPackageHandleStandardArgs)
# handle the QUIETLY and REQUIRED arguments and set METAL_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args(METAL  DEFAULT_MSG
                                  METAL_INCLUDE_DIR METAL_LIBRARIES)

mark_as_advanced(METAL_INCLUDE_DIR METAL_LIBRARIES)
