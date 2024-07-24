add_library(utils SHARED
  utils.c
)

add_library(sha_256 SHARED
  sha256.c
)

add_library(gpu_library SHARED
  main.cu
)

#target_include_directories(gpu_library PUBLIC ${Python3_INCLUDE_DIRS})
target_include_directories(gpu_library PUBLIC ${CMAKE_SOURCE_DIR}/pybind11/include)
target_link_libraries(gpu_library PUBLIC
  #${PYTHON3_PYTHON}
  utils
  sha_256
  Python3::Python
  cudart
)

# set what comes before the library name, here no "lib"
set_target_properties(gpu_library PROPERTIES PREFIX "")

# configure_file(test_mul.py test_mul.py COPYONLY)