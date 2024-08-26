OBJECTS=gpu_miner

# Debug build flags
ifeq ($(dbg),1)
      NVCCFLAGS += -g -G
endif

ifeq ($(prf),1)
      NVCCFLAGS += -lineinfo
endif

all: $(OBJECTS)

clean:
	rm $(OBJECTS) sha256.o utils.o

gpu_miner: main.cu utils.o sha256.o
	nvcc $(NVCCFLAGS) -O3 -v -lrt -lm -o $@ $^

verify_gpu: main.cu utils.o sha256.o
	nvcc -O3 -v -lrt -lm -D VERIFY_HASH -o $@ $^

# cpu_miner: serial_baseline.c sha256.o utils.o
# 	gcc -O2 -v -o $@ $^ -lrt

sha256.o: sha256.c
	gcc -O3 -v -c -o $@ $^

utils.o: utils.c
	gcc -O3 -v -c -o $@ $^ -lrt

test: test.cu
	nvcc $(NVCCFLAGS) -O3 -v -lrt -lm -o $@ $^