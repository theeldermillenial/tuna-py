nvcc -O3 -v -lrt -lm -std=c++11 -I/mnt/f/fortuna/cuda-fortuna/tuna-py/.venv/lib/python3.12/site-packages/pybind11/include -I/usr/include/python3.12 -o src/tuna/cuda$(python3-config --extension-suffix) cuda/main.cu cuda/utils.o cuda/sha256.o