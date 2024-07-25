#include <cstdio>
#include <cstdlib>
#include <stdbool.h>
#include <stdint.h>
#include <random>

#include "cuPrintf.cu"
#include "cuPrintf.cuh"
extern "C" {
	#include "sha256.h"
	#include "utils.h"
}
#include "sha256_unrolls.h"

#include <chrono>
#include <iomanip>
#include <iostream>
#include <thread>
#include <string>
#include <vector>

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <pybind11/complex.h>

namespace py = pybind11;


// #define VERIFY_HASH		//Execute only 1 thread and verify manually
//#define ITERATE_BLOCKS	//Don't define BDIMX and create a 65535x1 Grid

/*
	Threads = BDIMX*GDIMX*GDIMY
	Thread Max = 2^32
	The most convenient way to form dimensions is to use a square grid of blocks
	GDIMX = sqrt(2^32/BDIMX)
*/
#ifndef VERIFY_HASH
#define BDIMX		256		//MAX = 512
#define GDIMX		32		//MAX = 65535 = 2^16-1
#define GDIMY		GDIMX
#define NLOOPS		8192
#endif

#ifdef VERIFY_HASH
#define BDIMX	1
#define GDIMX	1
#define GDIMY	1
#define NLOOPS	1
#endif

__global__ void kernel_sha256d(unsigned int *nr, void *debug);


__constant__ unsigned char device_data[101];
__constant__ unsigned char device_difficulty[16];
__constant__ unsigned long device_msg_len;

inline void gpuAssert(cudaError_t code, char *file, int line, bool abort)
{
	if (code != cudaSuccess) 
	{
		fprintf(stderr,"CUDA_SAFE_CALL: %s %s %d\n", cudaGetErrorString(code), file, line);
		if (abort) exit(code);
	}
}

#define CUDA_SAFE_CALL(ans) { gpuAssert((ans), __FILE__, __LINE__, true); }

void hash_to_string(unsigned char * buff, unsigned long len) {
	int k, i;
	for (i = 0, k = 0; i < len; i++, k+= 2)
	{
		printf("%02x", buff[i]);
	}
}

//Warning: This mmodifies the nonce value of data so do it last!
void compute_and_print_hash(const unsigned char *data, unsigned int *nonce, unsigned long MSG_SIZE) {
	unsigned char hash[32];
	SHA256_CTX ctx;
	int i;

	printf("MSG_SIZE: %lu\n", MSG_SIZE);
	printf("Original Data: ");

	*((unsigned int *) (data + 4)) = nonce[0];
	*((unsigned int *) (data + 8)) = nonce[1];
	*((unsigned int *) (data + 12)) = nonce[2];
	*((unsigned int *) (data + 16)) = nonce[3];
	hash_to_string((unsigned char *) data, MSG_SIZE);
	printf("\n");

	printf("Nonce: ");
	printf("%.8x ", nonce[0]);
	printf("%.8x ", nonce[1]);
	printf("%.8x ", nonce[2]);
	printf("%.8x ", nonce[3]);
	printf("\n");

	sha256_init(&ctx);
	sha256_update(&ctx, data, MSG_SIZE);
	sha256_final(&ctx, hash);
	sha256_init(&ctx);
	sha256_update(&ctx, hash, 32);
	sha256_final(&ctx, hash);

	printf("Hash is:\n");
	for(i=0; i<8; i++) {
		printf("%.8x ", ENDIAN_SWAP_32(*(((unsigned int *) hash) + i)));
	}
	printf("\n");
}

bool check_file(char * fname) {
	FILE * f = 0;

	f = fopen(fname, "rb");
	if (!f){
		return false;
	} else {
		return true;
	}
}

// Function to convert a hex character to its corresponding integer value
int hexCharToInt(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    } else if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    } else if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1; // Invalid hex character
}

// Function to convert a hex string to a byte array
unsigned char* hexStringToByteArray(unsigned char* hexString, unsigned long strLength) {

    // Check if the input string length is odd (invalid hex string)
    if (strLength % 2 != 0) {
        return NULL;
    }

    size_t arrayLength = strLength / 2;
    unsigned char* byteArray = (unsigned char*)malloc(arrayLength);

    for (size_t i = 0; i < arrayLength; ++i) {
        int highNibble = hexCharToInt(hexString[i * 2]);
        int lowNibble = hexCharToInt(hexString[i * 2 + 1]);

        // Check for invalid characters in the hex string
        if (highNibble == -1 || lowNibble == -1) {
            free(byteArray);
            return NULL;
        }

        byteArray[i] = (unsigned char)((highNibble << 4) | lowNibble);
    }

    return byteArray;
}

void store_nonce(char * fname, unsigned int * nonce) {

	FILE * f = 0;

	f = fopen(fname, "w");
	
	fprintf(f, "%.8x", ENDIAN_SWAP_32(nonce[0]));
	fprintf(f, "%.8x", ENDIAN_SWAP_32(nonce[1]));
	fprintf(f, "%.8x", ENDIAN_SWAP_32(nonce[2]));
	fprintf(f, "%.8x", ENDIAN_SWAP_32(nonce[3]));
	fclose(f);
}

unsigned char * get_file_data(char * fname, unsigned long * MSG_SIZE) {

	FILE * f = 0;
	unsigned char * buffer = 0;
	unsigned long fsize = 0;

	f = fopen(fname, "rb");
	while (!check_file(fname)){
		printf("Waiting for new datum...\n");
		std::this_thread::sleep_for(std::chrono::milliseconds(100));
		f = fopen(fname, "rb");
	}
	fflush(f);

	if (fseek(f, 0, SEEK_END)){
		fprintf(stderr, "Unable to fseek %s\n", fname);
		return 0;
	}
	fflush(f);
	fsize = ftell(f);
	rewind(f);
	*MSG_SIZE = fsize / 2;

	buffer = (unsigned char *)malloc((fsize+1)*sizeof(unsigned char));
	// checkCudaErrors(cudaMallocManaged(&buffer, (fsize+1)*sizeof(char)));
	fread(buffer, fsize, 1, f);
	fclose(f);

	return hexStringToByteArray(buffer, fsize);
	// return buffer;
}



unsigned char * set_tuna_difficulty(unsigned short difficulty_number, unsigned char leading_zeros) {
	int i;
	unsigned char * difficulty = (unsigned char *) malloc(sizeof(unsigned char) * 16);
	for(i=0; i<16; i++) {
		difficulty[i] = 0;
	}

	int byte_location = leading_zeros / 2;
    if (leading_zeros % 2 == 0) {
        difficulty[byte_location] = (difficulty_number / 256);
        difficulty[byte_location + 1] = (difficulty_number % 256);
    } else {
        difficulty[byte_location] = (difficulty_number / 4096);
        difficulty[byte_location + 1] = ((difficulty_number / 16) % 4096);
        difficulty[byte_location + 2] = (difficulty_number % 16);
    }

	return difficulty;
}

int main(int argc, char **argv) {
	int i, j;
	// unsigned char *data = test_block;
	unsigned long MSG_SIZE;
	#ifndef VERIFY_HASH
	const unsigned char *data = get_file_data("./datum.txt", &MSG_SIZE);
	#else
	unsigned char *data = get_file_data("./datum.txt", &MSG_SIZE);
	#endif


	/*
		Host Side Preprocessing
		The goal here is to prepare and compute everything that will be shared by all threads.
	*/
	
	//Initialize Cuda stuff
	cudaPrintfInit();
	dim3 DimGrid(GDIMX,GDIMY);
	#ifndef ITERATE_BLOCKS
	dim3 DimBlock(BDIMX,1);
	#endif

	//Used to store a nonce if a block is mined
	unsigned int * host_nonce = new unsigned int[40];
	memset(host_nonce, 0, sizeof(unsigned int) * 40);

	std::mt19937 mt{ std::random_device{}() };
		

	while (true) {
		
		//Increment the global nonce
		host_nonce[0] = *((unsigned int *) (data + 4));
		host_nonce[1] = mt();
		host_nonce[2] = mt();
		host_nonce[3] = 0;

		//Decodes and stores the difficulty in a 16-byte array for convenience
		unsigned char * difficulty = set_tuna_difficulty(65535, 8);

		//Data buffer for sending debug information to/from the GPU
		unsigned char debug[32];
		unsigned char *d_debug;
		#ifdef VERIFY_HASH
		printf("Initial Data: ");
		for(i=0; i<MSG_SIZE; i++) {
			printf("%.2x", data[i]);
		}
		printf("\n");
		SHA256_CTX verify;
		sha256_init(&verify);
		printf("1. init state: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(verify.state[i]));
		}
		printf("\n");
		sha256_update(&verify, (unsigned char *) data, MSG_SIZE);
		printf("2. update state: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(verify.state[i]));
		}
		printf("\n");
		sha256_final(&verify, debug);
		printf("3. final state: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(verify.state[i]));
		}
		printf("\n");
		sha256_init(&verify);
		printf("4. init state: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(verify.state[i]));
		}
		printf("\n");
		sha256_update(&verify, (unsigned char *) debug, 32);
		printf("5. update state: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(verify.state[i]));
		}
		printf("\n");
		sha256_final(&verify, debug);
		printf("6. final state: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(verify.state[i]));
		}
		printf("\n");
		printf("Final Hash: ");
		for(i=0; i<8; i++) {
			printf("%.8x ", ENDIAN_SWAP_32(*(((unsigned int *) debug) + i)));
		}
		printf("\n");
		#endif

		// Copy debug data to device
		cudaGetErrorString(cudaMalloc((void **)&d_debug, 32*sizeof(unsigned char)));
		cudaGetErrorString(cudaMemcpy(d_debug, (void *) &debug, 32*sizeof(unsigned char), cudaMemcpyHostToDevice));

		//Allocate space on Global Memory
		// SHA256_CTX *d_ctx;
		unsigned int * device_nonce = new unsigned int[40];
		memset(device_nonce, 0, sizeof(unsigned int) * 40);
		CUDA_SAFE_CALL(cudaMalloc((void **) &device_nonce, 40 * sizeof(unsigned int)));

		/*
			Kernel Execution
			Measure and launch the kernel and start mining
		*/
		//Copy constants to device
		CUDA_SAFE_CALL(cudaMemcpyToSymbol(device_data, &data[0], 101));
		CUDA_SAFE_CALL(cudaMemcpyToSymbol(device_difficulty, &difficulty[0], 16));
		CUDA_SAFE_CALL(cudaMemcpyToSymbol(device_msg_len, &MSG_SIZE, 4));

		// Copy nonce to device
		CUDA_SAFE_CALL(cudaMemcpy(device_nonce, &host_nonce[0], 40 * sizeof(unsigned int), cudaMemcpyHostToDevice));

		
		float elapsed_gpu;
		long long int num_hashes;
		#ifdef ITERATE_BLOCKS
		//Try different block sizes
		for(i=1; i <= 512; i++) {
			dim3 DimBlock(i,1);
		#endif
			//Start timers
			cudaEvent_t start, stop;
			cudaEventCreate(&start);
			cudaEventCreate(&stop);
			cudaEventRecord(start, 0);

			//Launch Kernel
			kernel_sha256d<<<DimGrid, DimBlock>>>(device_nonce, (void *) d_debug);
			
			#ifndef VERIFY_HASH
			if (check_file("./datum.txt")) {
			#else
			if (check_file("./datum.txt")) {
			#endif
				printf("Found new datum!\n");
				data = get_file_data("./datum.txt", &MSG_SIZE);
				#ifndef VERIFY_HASH
				unsigned char *data = get_file_data("./datum.txt", &MSG_SIZE);
				remove("./datum.txt");
				#else
				unsigned char *data = get_file_data("./datum.txt", &MSG_SIZE);
				#endif
			}

			//Stop timers
			cudaEventRecord(stop,0);
			cudaEventSynchronize(stop);
			cudaEventElapsedTime(&elapsed_gpu, start, stop);
			cudaEventDestroy(start);
			cudaEventDestroy(stop);

		#ifdef ITERATE_BLOCKS
			//Calculate results
			num_hashes = GDIMX*i;
			//block size, hashrate, hashes, execution time
			printf("%d, %.2f, %.0f, %.2f\n", i, num_hashes/(elapsed_gpu*1e-3), num_hashes, elapsed_gpu);
		}
		#endif
		//Copy nonce result back to host
		CUDA_SAFE_CALL(cudaMemcpy(host_nonce, &device_nonce[0], 40 * sizeof(unsigned int), cudaMemcpyDeviceToHost));

		/*	
			Post Processing
			Check the results of mining and print out debug information
		*/

		//Cuda Printf output
		cudaDeviceSynchronize();
		cudaPrintfDisplay(stdout, false);
		cudaPrintfEnd();

		//Free memory on device
		CUDA_SAFE_CALL(cudaFree(device_nonce));
		CUDA_SAFE_CALL(cudaFree(d_debug));
		
		//Output the results
		int count = 0;
		for (int i = 0; i < 40; i+=4) {
			if (host_nonce[i+3] %2 == 1) {
				count++;
			} else {
				break;
			}
		}
		printf("%i nonces found\n", count);
		if(host_nonce[3] % 2 == 1) {
			host_nonce[3]--;
			printf("Nonce found! %.8x ", host_nonce[0]);
			printf("%.8x ", host_nonce[1]);
			printf("%.8x ", host_nonce[2]);
			printf("%.8x ", host_nonce[3]);
			printf("\n");
			store_nonce("./submit.txt", &host_nonce[0]);
			printf("Difficulty: " );
			for(int i=0; i<16; i++) {
				printf("%.2x", difficulty[i]);
			}
			printf("\n");
			compute_and_print_hash(data, host_nonce, MSG_SIZE);

			// data = get_file_data("./datum.txt", &MSG_SIZE);
			host_nonce[3] = 0;
		}
		// else {
		// 	printf("Nonce not found :(\n");
		// }

		#ifdef VERIFY_HASH
		break;
		#endif
		
		num_hashes = BDIMX;
		num_hashes *= GDIMX*GDIMY;
		printf("Hashrate: %.2f MH/s\n", NLOOPS*num_hashes/(elapsed_gpu*1e3));
		// break;
	}
}

//Declare SHA-256 constants
__constant__ uint32_t k[64] = {
	0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
	0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
	0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
	0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
	0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
	0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
	0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
	0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

#define NONCE_VAL (gridDim.x*blockDim.x*blockIdx.y + blockDim.x*blockIdx.x + blockDim.x*gridDim.x*threadIdx.y + threadIdx.x)

__device__ void sha256_second_update_cuda(SHA256_RX *ctx)
{
	ctx->datalen = 32;
	ctx->bitlen = 0;
}

#define CUDA_EP0(x) (((x / 4) | (x * 1073741824)) ^ ((x / 8192) | (x * 524288)) ^ ((x / 4194304) | (x * 1024)))
#define CUDA_EP1(x) (((x / 64) | (x * 67108864)) ^ ((x / 2048) | (x * 2097152)) ^ ((x / 33554432) | (x * 128)))

#define TRANSFORM_BODY		\
		t1 = CH(e,f,g);		\
		t1 += h;			\
		h = g;				\
		t1 += CUDA_EP1(e);	\
		g = f;				\
		t1 += k[j];			\
		t2 = MAJ(a,b,c);	\
		f = e;				\
		t1 += m[i];			\
		e = d + t1;			\
		d = c;				\
		t2 += CUDA_EP0(a);	\
		c = b;				\
		b = a;				\
		a = t1 + t2;		\

__device__ void cuda_sha256_transform(SHA256_RX *ctx) {
	WORD a, b, c, d, e, f, g, h, t1, t2, m[16];
	int i, j;

	a = ctx->state[0];
	b = ctx->state[1];
	c = ctx->state[2];
	d = ctx->state[3];
	e = ctx->state[4];
	f = ctx->state[5];
	g = ctx->state[6];
	h = ctx->state[7];
	j = 0;
	for (i = 0; i < 16; ++i) {
		m[i] = ctx->data.word[i];

		TRANSFORM_BODY;
		
		j++;
	}
	for (i = 0; i < 7; ++i) {
		m[i] = SIG1(m[(i + 14) & 0xf]);
		m[i] += m[i + 9];
		m[i] += SIG0(m[i + 1]);
		m[i] += ctx->data.word[i];

		TRANSFORM_BODY;

		j++;
	}
	for (i; i < 15; ++i) {
		m[i] = SIG1(m[(i - 2)]);
		m[i] += m[((i + 9) & 0xf)];
		m[i] += SIG0(m[(i + 1)]);
		m[i] += ctx->data.word[i];

		TRANSFORM_BODY;

		j++;
	}
	for (i; i < 16; ++i) {
		m[i] = SIG1(m[(i - 2)]);
		m[i] += m[((i + 9) & 0xf)];
		m[i] += SIG0(m[(i + 1) & 0xf]);
		m[i] += ctx->data.word[i];

		TRANSFORM_BODY;

		j++;
	}
	for (i = 0; i < 7; ++i) {
		t1 = m[i];
		m[i] = SIG1(m[(i + 14) & 0xf]);
		m[i] += m[((i + 9))];
		m[i] += SIG0(m[(i + 1)]);
		m[i] += t1;

		TRANSFORM_BODY;

		j++;
	}
	for (i; i < 15; ++i) {
		t1 = m[i];
		m[i] = SIG1(m[(i - 2)]);
		m[i] += m[((i + 9) & 0xf)];
		m[i] += SIG0(m[(i + 1)]);
		m[i] += t1;

		TRANSFORM_BODY;

		j++;
	}
	for (i; i < 16; ++i) {
		t1 = m[i];
		m[i] = SIG1(m[(i - 2)]);
		m[i] += m[((i + 9) & 0xf)];
		m[i] += SIG0(m[(i + 1) & 0xf]);
		m[i] += t1;

		TRANSFORM_BODY;

		j++;
	}
	for (i = 0; i < 7; ++i) {
		t1 = m[i];
		m[i] = SIG1(m[(i + 14) & 0xf]);
		m[i] += m[((i + 9))];
		m[i] += SIG0(m[(i + 1)]);
		m[i] += t1;

		TRANSFORM_BODY;

		j++;
	}
	for (i; i < 15; ++i) {
		t1 = m[i];
		m[i] = SIG1(m[(i - 2)]);
		m[i] += m[((i + 9) & 0xf)];
		m[i] += SIG0(m[(i + 1)]);
		m[i] += t1;

		TRANSFORM_BODY;

		j++;
	}
	for (i; i < 16; ++i) {
		t1 = m[i];
		m[i] = SIG1(m[(i - 2)]);
		m[i] += m[((i + 9) & 0xf)];
		m[i] += SIG0(m[(i + 1) & 0xf]);
		m[i] += t1;

		TRANSFORM_BODY;

		j++;
	}
	ctx->state[0] += a;
	ctx->state[1] += b;
	ctx->state[2] += c;
	ctx->state[3] += d;
	ctx->state[4] += e;
	ctx->state[5] += f;
	ctx->state[6] += g;
	ctx->state[7] += h;
}

__device__ void cuda_sha256_init(SHA256_RX *ctx) {
	ctx->datalen = 0;
	ctx->bitlen = 0;
	ctx->state[0] = 0x6a09e667;
	ctx->state[1] = 0xbb67ae85;
	ctx->state[2] = 0x3c6ef372;
	ctx->state[3] = 0xa54ff53a;
	ctx->state[4] = 0x510e527f;
	ctx->state[5] = 0x9b05688c;
	ctx->state[6] = 0x1f83d9ab;
	ctx->state[7] = 0x5be0cd19;
}

__device__ void cuda_sha256_first_update(SHA256_RX *ctx) {
	for (int i = 0; i < 26; ++i) {
		ctx->data.word[i] = ENDIAN_SWAP_32(ctx->data.word[i]);
	}							
	cuda_sha256_transform(ctx);
	ctx->bitlen = 512;
	ctx->datalen = 37;
	for (int i = 16; i < 26; ++i) {
		ctx->data.word[i-16] = ctx->data.word[i];
	}
}

__device__ void cuda_sha256_first_pad(SHA256_RX *ctx) {
	WORD i;

	ctx->data.byte[38] = 0x80;
	ctx->data.byte[37] = 0;
	ctx->data.byte[36] = 0;

	i = 40;

	while (i < 60)
		ctx->data.byte[i++] = 0x00;

	// Store value of l
	ctx->bitlen += ctx->datalen * 8;
	ctx->data.byte[60] = ctx->bitlen;
	ctx->data.byte[61] = ctx->bitlen >> 8;
	ctx->data.byte[62] = 0;
	ctx->data.byte[63] = 0;
}

__device__ void cuda_sha256_second_pad(SHA256_RX *ctx) {
	WORD i;

	i = ctx->datalen;

	ctx->data.byte[i++] = 0x00;
	ctx->data.byte[i++] = 0x00;
	ctx->data.byte[i++] = 0x00;
	ctx->data.byte[i++] = 0x80;
	while (i < 60)
		ctx->data.byte[i++] = 0x00;
	ctx->bitlen += ctx->datalen * 8;
	ctx->data.byte[60] = ctx->bitlen;
	ctx->data.byte[61] = ctx->bitlen >> 8;
	ctx->data.byte[62] = 0;
	ctx->data.byte[63] = 0;
}

__device__ void cuda_sha256_first_final(SHA256_RX *ctx) {
	cuda_sha256_first_pad(ctx);
	cuda_sha256_transform(ctx);
}

__device__ void cuda_sha256_second_final(SHA256_RX *ctx) {
	cuda_sha256_second_pad(ctx);
	cuda_sha256_transform(ctx);
}

__global__ void kernel_sha256d(unsigned int *nonce, void *debug) {
	int i, j;
	
    SHA256_RX ctx;

	// Synchronized load data to shared memory
	__shared__ uint32_t shared_k[64];
	__shared__ DATA shared_data;
	__shared__ DIFFICULTY shared_difficulty;
	__shared__ WORD msglen;
	// __shared__ WORD shared_nonce [GDIMX*GDIMY*3];
	#ifndef VERIFY_HASH
	i = threadIdx.y * GDIMX + threadIdx.x;
	if (i < 64) {
		if (i < 16) {
			if (i == 0) {
				msglen = device_msg_len;
			}
			shared_difficulty.byte[i] = device_difficulty[i];
		}
		shared_k[i] = k[i];
		shared_data.byte[i] = device_data[i];
	} else if (i < 101)
	{
		shared_data.byte[i] = device_data[i];
	}
	__syncthreads();

	// Set the local nonce
	ctx.nonce[0] = nonce[0];
	ctx.nonce[1] = NONCE_VAL;
	ctx.nonce[2] = nonce[2];
	ctx.nonce[3] = nonce[3];
	#else
	for (int t = 0; t < 64; t++) {
		if (t < 16) {
			shared_difficulty.byte[t] = device_difficulty[t];
		}
		shared_k[t] = k[t];
		shared_data.byte[t] = device_data[t];
	} 
	for (int t = 64; t < 101; t++)
	{
		shared_data.byte[t] = device_data[t];
	}
	
	// Set the local nonce
	ctx.nonce[0] = nonce[0];
	ctx.nonce[1] = 0;
	ctx.nonce[2] = 0;
	ctx.nonce[3] = 16777216;
	#endif

	// Copy data to local registers
	for (i = 0; i < 64; ++i) {
		ctx.k[i] = shared_k[i];
	}

	// Initialize bitlen to 0
	ctx.bitlen = 0;

	for (int loop = 0; loop < NLOOPS; loop ++) {

		#ifndef VERIFY_HASH
		ctx.nonce[3] = 2 * loop;
		#endif

		ctx.data.word[0] = shared_data.word[0];
		ctx.data.word[1] = ctx.nonce[0];
		ctx.data.word[2] = ctx.nonce[1];
		ctx.data.word[3] = ctx.nonce[2];
		ctx.data.word[4] = ctx.nonce[3];
		for (i = 5 ; i < 26; ++i) {
			ctx.data.word[i] = shared_data.word[i];
		}
			#ifdef VERIFY_HASH
			// get the message length
			msglen = device_msg_len;
			unsigned int *ref_hash = (unsigned int *) debug;
			cuPrintf("--Cuda--\n");
			cuPrintf("Initial Data: ");
			for(i=0; i<msglen; i++) {
				cuPrintf("%.2x", shared_data.byte[i]);
			}
			cuPrintf("\n");
			cuPrintf("CTX Data: ");
			for(i=0; i<msglen; i++) {
				cuPrintf("%.2x", ctx.data.byte[i]);
			}
			cuPrintf("\n");
			cuPrintf("NONCE: ");
			for(i=0; i<msglen; i++) {
				cuPrintf("%.2x", ctx.data.byte[i]);
			}
			cuPrintf("\n");
			#endif
			
		// // For debugging
		// for (i = 0 ; i < 26; ++i) {
		// 	shared_data.word[i] = ctx.data.word[i];
		// }

		cuda_sha256_init(&ctx);
		ctx.datalen = msglen;
			#ifdef VERIFY_HASH
			cuPrintf("1. init state: ");
			for(int i=0; i<8; i++) {
				cuPrintf("%.8x ", ENDIAN_SWAP_32(ctx.state[i]));
			}
			cuPrintf("\n");
			cuPrintf("Pad: ");
			for(int i=0; i<64; i++) {
				cuPrintf("%.2x ", ctx.data.byte[i]);
			}
			cuPrintf("\n");
			#endif
			
		// First value update
		cuda_sha256_first_update(&ctx);
			#ifdef VERIFY_HASH
			cuPrintf("2. update state: ");
			for(int i=0; i<8; i++) {
				cuPrintf("%.8x ", ENDIAN_SWAP_32(ctx.state[i]));
			}
			cuPrintf("\n");
			cuPrintf("Pad: ");
			for(int i=0; i<64; i++) {
				cuPrintf("%.2x ", ctx.data.byte[i]);
			}
			cuPrintf("\n");
			#endif
		cuda_sha256_first_pad(&ctx);
			#ifdef VERIFY_HASH
			cuPrintf("Pad: ");
			for(int i=0; i<64; i++) {
				cuPrintf("%.2x ", ctx.data.byte[i]);
			}
			cuPrintf("\n");
			#endif
		cuda_sha256_transform(&ctx);
		// cuda_sha256_first_final(&ctx);
		for (int i = 0; i < 8; ++i) {
			ctx.data.word[i] = ctx.state[i];
		}																	
			// FINAL;
			// sha256_final_cuda(&ctx);
			#ifdef VERIFY_HASH
			cuPrintf("3. final state: ");
			for(int i=0; i<8; i++) {
				cuPrintf("%.8x ", ENDIAN_SWAP_32(ctx.state[i]));
			}
			cuPrintf("\n");
			#endif
		cuda_sha256_init(&ctx);
		ctx.datalen = 32;
			#ifdef VERIFY_HASH
			cuPrintf("4. init state: ");
			for(int i=0; i<8; i++) {
				cuPrintf("%.8x ", ENDIAN_SWAP_32(ctx.state[i]));
			}
			cuPrintf("\n");
			#endif
		sha256_second_update_cuda(&ctx);
			#ifdef VERIFY_HASH
			cuPrintf("5. update state: ");
			for(int i=0; i<8; i++) {
				cuPrintf("%.8x ", ENDIAN_SWAP_32(ctx.state[i]));
			}
			cuPrintf("\n");
			cuPrintf("Pad: ");
			for(int i=0; i<64; i++) {
				cuPrintf("%.2x ", ctx.data.byte[i]);
			}
			cuPrintf("\n");
			#endif
		cuda_sha256_second_final(&ctx);
			#ifdef VERIFY_HASH
			cuPrintf("6. final state: ");
			for(int i=0; i<8; i++) {
				cuPrintf("%.8x ", ENDIAN_SWAP_32(ctx.state[i]));
			}
			cuPrintf("\n");
			cuPrintf("Final Hash: ");
			for(i=0; i<8; i++) {
				cuPrintf("%.8x ", ctx.state[i]);
			}
			cuPrintf("\n");
			#endif

			#ifdef VERIFY_HASH
			cuPrintf("Difficulty\n");
			for(i=0; i<16; i++) {
				cuPrintf("%.2x", shared_difficulty.byte[i]);
			}
			#endif

		for (i = 0; i < 8; ++i) {
			ctx.data.word[i] = ENDIAN_SWAP_32(ctx.state[i]);
		}

		i=0;
		while(ctx.data.byte[i] == shared_difficulty.byte[i])
			i++;
		
		
		if(ctx.data.byte[i] < shared_difficulty.byte[i]) {
			//Synchronization Issue
			//Kind of a hack but it really doesn't matter which nonce
			//is written to the output, they're all winners :)
			//Further it's unlikely to even find a nonce let alone 2
			for (i = 0; i < 40; i+=4) {
				if (nonce[i+3] == 0) {
					nonce[i] = ctx.nonce[0];
					nonce[i+1] = ctx.nonce[1];
					nonce[i+2] = ctx.nonce[2];
					nonce[i+3] = ctx.nonce[3] + 1;
					break;
				}
			}
			
			// nonce[0] = ctx.nonce[0];
			// nonce[1] = ctx.nonce[1];
			// nonce[2] = ctx.nonce[2];
			// nonce[3] = ctx.nonce[3] + 1;
			// break;
			// cuPrintf("Final Hash: ");
			// for(i=0; i<8; i++) {
			// 	cuPrintf("%.8x ", ctx.state[i]);
			// }
			// cuPrintf("\n");
			
			// printf("Nonce: ");
			// printf("%.8x ", nonce[0]);
			// printf("%.8x ", nonce[1]);
			// printf("%.8x ", nonce[2]);
			// printf("%.8x ", nonce[3]);
			// printf("\n");

			
			// cuPrintf("CTX Data: ");
			// for(i=0; i<msglen; i++) {
			// 	cuPrintf("%.2x", shared_data.byte[i]);
			// }
			// cuPrintf("\n");
			// break;
		}
	}
}

std::vector<std::string> mine_cuda(py::bytes datum, unsigned int zeros) {
	const std::string data(datum);
	unsigned long MSG_SIZE = data.length();

	dim3 DimGrid(GDIMX,GDIMY);
	dim3 DimBlock(BDIMX,1);

	// For debugger
	unsigned char debug[32];
	unsigned char *d_debug;

	//Setup host nonce
	unsigned int * host_nonce = new unsigned int[40];
	memset(host_nonce, 0, sizeof(unsigned int) * 40);
	unsigned int * device_nonce = new unsigned int[40];
	memset(device_nonce, 0, sizeof(unsigned int) * 40);

	// Initialize host nonce
	std::mt19937 mt{ std::random_device{}() };
	host_nonce[0] = *((unsigned int *) (data.data() + 4)); // unique pool part nonce
	host_nonce[1] = 0; 									   // grid location nonce
	host_nonce[2] = mt();								   // random nonce
	host_nonce[3] = 0;									   // increment nonce

	// Send nonce to device
	CUDA_SAFE_CALL(cudaMalloc((void **) &device_nonce, 40 * sizeof(unsigned int)));
	CUDA_SAFE_CALL(cudaMemcpy(device_nonce, &host_nonce[0], 40 * sizeof(unsigned int), cudaMemcpyHostToDevice));

	//Decodes and stores the difficulty in a 16-byte array for convenience
	unsigned char * difficulty = set_tuna_difficulty(65535, zeros);

	//Send data to device
	CUDA_SAFE_CALL(cudaMemcpyToSymbol(device_data, &data[0], 101));
	CUDA_SAFE_CALL(cudaMemcpyToSymbol(device_difficulty, &difficulty[0], 16));
	CUDA_SAFE_CALL(cudaMemcpyToSymbol(device_msg_len, &MSG_SIZE, 4));

	//Launch Kernel
	kernel_sha256d<<<DimGrid, DimBlock>>>(device_nonce, (void *) d_debug);

	//Copy nonce result back to host
	CUDA_SAFE_CALL(cudaMemcpy(host_nonce, &device_nonce[0], 40 * sizeof(unsigned int), cudaMemcpyDeviceToHost));
	
	//Free memory on device
	CUDA_SAFE_CALL(cudaFree(device_nonce));
	CUDA_SAFE_CALL(cudaFree(d_debug));

	std::vector<std::string> output;

	for (int i = 0; i < 40; i+=4) {
		if (host_nonce[i+3] %2 == 1) {
			std::stringstream stream;
			host_nonce[i+3]--;
			for (int j = i; j < i+4; ++j) {
				stream << std::setfill('0') << std::setw(8) << std::hex << ENDIAN_SWAP_32(host_nonce[j]);
			}
			output.push_back(stream.str());
		} else {
			break;
		}
	}

	return output;
}

PYBIND11_MODULE(gpu_library, m) {
    m.doc() = "Fortuna miner...for cuda."; // optional module docstring

    m.def("mine_cuda", &mine_cuda, R"pbdoc(
        Mine using cuda.
    )pbdoc");
}