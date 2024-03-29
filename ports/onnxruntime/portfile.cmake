if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.15.1
    SHA512 c9ad2ab1102bb97bdd88aa8e06432fff2960fb21172891eee9631ff7cbbdf3366cd7cf5c0baa494eb883135eab47273ed3128851ff4d9adfa004a479e941b6b5
    PATCHES
      1.14.1-0004-abseil-no-string-view.patch
      1.15.1-0001-cmake-dependencies.patch
      fix_missing_cuda_definition.patch
)

if("xnnpack" IN_LIST FEATURES)
    # see https://github.com/microsoft/onnxruntime/pull/11798
    set(PROVIDERS_DIR "${SOURCE_PATH}/include/onnxruntime/core/providers")
    file(MAKE_DIRECTORY "${PROVIDERS_DIR}/xnnpack")
    file(WRITE "${PROVIDERS_DIR}/xnnpack/xnnpack_provider_factory.h" "#pragma once")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        training  onnxruntime_ENABLE_TRAINING
        training  onnxruntime_ENABLE_TRAINING_OPS
        cuda      onnxruntime_USE_CUDA
        cuda      onnxruntime_USE_NCCL
        tensorrt  onnxruntime_USE_TENSORRT
        directml  onnxruntime_USE_DML
        winml     onnxruntime_USE_WINML
        coreml    onnxruntime_USE_COREML
        mimalloc  onnxruntime_USE_MIMALLOC
        valgrind  onnxruntime_USE_VALGRIND
        xnnpack   onnxruntime_USE_XNNPACK
        test      onnxruntime_BUILD_UNIT_TESTS
        framework onnxruntime_BUILD_APPLE_FRAMEWORK
    INVERTED_FEATURES
        abseil   onnxruntime_DISABLE_ABSEIL

)

if(VCPKG_TARGET_IS_UWP)
    set(CONFIG_OPTIONS WINDOWS_USE_MSBUILD)
else()
    set(CONFIG_OPTIONS GENERATOR Ninja)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    # target platform should be informed to activate SIMD properly
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="x64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="Win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="ARM64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="ARM")
    else()
        message(WARNING "Unexpected architecture: ${VCPKG_TARGET_ARCHITECTURE}")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="${VCPKG_TARGET_ARCHITECTURE}")
    endif()
endif()

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    ${CONFIG_OPTIONS}
    OPTIONS
        ${GENERATOR_OPTIONS}
        ${FEATURE_OPTIONS}
        -DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS
        -DPython_EXECUTABLE:FILEPATH=${PYTHON3}
        # -DProtobuf_USE_STATIC_LIBS=OFF
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_BUILD_OBJC=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_BUILD_NODEJS=OFF
        -Donnxruntime_BUILD_JAVA=OFF
        -Donnxruntime_BUILD_CSHARP=OFF
        -Donnxruntime_BUILD_WEBASSEMBLY=OFF
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_USE_FULL_PROTOBUF=ON
        -Donnxruntime_USE_PREINSTALLED_EIGEN=ON -Deigen_SOURCE_PATH="${CURRENT_INSTALLED_DIR}/include"
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_MPI=OFF # ${VCPKG_TARGET_IS_LINUX}
        -Donnxruntime_ENABLE_CPUINFO=ON
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=${VCPKG_TARGET_IS_WINDOWS}
        -Donnxruntime_ENABLE_BITCODE=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
        # cutlass dependency is not managed, see https://github.com/iit-danieli-joint-lab/idjl-vision-dependencies-vcpkg/pull/5#issuecomment-1669056801
        # once cutlass is correctly managed, enable or remove this option (that should be the same as the option is ON by default)
        -Donnxruntime_USE_FLASH_ATTENTION:BOOL=OFF
        # This are hardcoded architectures for our specific use case, to compile for
        # all comment this line and uncomment the following one
        -DCMAKE_CUDA_ARCHITECTURES=86
        # -DCMAKE_CUDA_ARCHITECTURES=all)
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

if(VCPKG_TARGET_IS_IOS)
    set(FRAMEWORK_NAME "onnxruntime.framework")
    file(RENAME "${CURRENT_PACKAGES_DIR}/debug/bin/${FRAMEWORK_NAME}"
                "${CURRENT_PACKAGES_DIR}/debug/lib/${FRAMEWORK_NAME}"
    )
    file(RENAME "${CURRENT_PACKAGES_DIR}/bin/${FRAMEWORK_NAME}"
                "${CURRENT_PACKAGES_DIR}/lib/${FRAMEWORK_NAME}"
    )
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE
        "${CURRENT_PACKAGES_DIR}/debug/bin"
        "${CURRENT_PACKAGES_DIR}/bin"
    )
endif()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
