cmake_minimum_required(VERSION 3.8)
project(VectorCopy)

# FindCUDA
include(CheckLanguage)
check_language(CUDA QUIET)

# FindHIP
if(NOT DEFINED HIP_PATH)
    if(NOT DEFINED ENV{HIP_PATH})
        set(HIP_PATH "/opt/rocm/hip" CACHE PATH "Path to which HIP has been installed")
    else()
        set(HIP_PATH $ENV{HIP_PATH} CACHE PATH "Path to which HIP has been installed")
    endif()
endif()
set(CMAKE_MODULE_PATH "${HIP_PATH}/cmake" ${CMAKE_MODULE_PATH})
find_package(HIP QUIET)

# FindOpenCL
find_package(OpenCL QUIET)

if(CMAKE_CUDA_COMPILER)
  enable_language(CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -O3")
  add_library(vc.cuda STATIC ${CMAKE_CURRENT_SOURCE_DIR}/vc.cu)
endif()

if(HIP_FOUND)
  if(EXISTS "${HIP_ROOT_DIR}/hip/bin/hipify-perl")
    message(STATUS "Found HIP: " ${HIP_VERSION})
    message(STATUS "Found HIPIFY: " ${HIP_ROOT_DIR}/hip/bin/hipify-perl)
    add_custom_command(
      OUTPUT vc.hip.cc
      COMMAND ${HIP_ROOT_DIR}/hip/bin/hipify-perl ${CMAKE_CURRENT_SOURCE_DIR}/vc.cu > vc.hip.cc
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/vc.cu
      COMMENT "Convering vc.cu to vc.hip.cc"
      )
    set(CMAKE_CXX_COMPILER "${HIP_ROOT_DIR}/hip/bin/hipcc")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -fno-gpu-rdc -fPIC")
    hip_add_library(vc.hip STATIC vc.hip.cc)
  else ()
    message(STATUS "Found HIP, but HIPIFY NOTFOUND")
    set(HIP_FOUND OFF)
  endif()
else()
    message(STATUS "HIP NOTFOUND")
endif()

if(OpenCL_FOUND)
  message(STATUS "Found OpenCL: " ${OpenCL_VERSION_STRING})
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")
  add_library(vc.opencl STATIC ${CMAKE_CURRENT_SOURCE_DIR}/vc.opencl.c)
  target_link_libraries(vc.opencl OpenCL::OpenCL)
else()
  message(STATUS "OpenCL Not Found")
endif()

