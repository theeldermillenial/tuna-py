## CHANGELOG

### v0.5.0

* Added Docker (instructions at the bottom of the page)

### v0.4.0

* Added CHANGELOG section
* Added hash rate calculations (reports ~10s)
* Fixed bug that caused new jobs to periodically not register properly
* Added command line arguments for `nloops` and `difficulty` to fine tune miner (see options section)

## Requirements
- Git
- CMake
- Python 3.12
- [Cuda 12.6](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)

## Install instructions
```bash
git clone https://github.com/theeldermillenial/tuna-py 
cd tuna-py 
git submodule init 
git submodule update 
cmake . make 
pip install -e . 
```

## Running the miner
1. Edit `sample.env` file
   - comment out `SEED=` -> `#SEED=`
   - change `ADDRESS` to your own mainnet wallet address
   - change `STRATUM_HOST` to `66.228.34.31`
2. Rename sample.env to .env 
    - `mv sample.env .env`
3. Run tuna miner
   -  `python -m tuna`

## Options

Options to help tune hash rate performance.

### --nloops 4096

This is the number of hash loops the CUDA miner runs. The default is 4096, which will
cause the miner to hash for ~2s on a GTX 1080ti. I recommend tuning this number so that
the card hashes for ~1-2 seconds.

How do you tune the card? In `.env`, set `TUNA_LOG=DEBUG` and run with different values
for `--nloops`. If the default (4096) only causes your card to run for 1 second,
increase to 8192 and try again.

Why 2s? That seems to give roughly the best hash rate given the overhead. The GPU hasher
is designed to find and hold up to 40 nonces, so it will report back up to 40 nonces
after those 2s.

What if your card starts returning more than 40 nonces? Then set the `--difficulty`
higher (see below).

### --difficulty 8

This is the hash difficulty (leading zeros) required to submit to Stratum. This is not
the new block mining difficulty. The difficulty should be 7 or higher, and defaults to
8. Ideally this is set so that every 1-3 hash rounds returns 1 nonce. Submitting higher
difficulty hashes gives you more hash power on Stratum. I wouldn't recommend setting
this higher than the current hash difficulty (at the time of writing, the difficulty is
10).

## Docker

I have built a docker container to make it easier to get started, since there is a lot
to download, install and configure. Make sure you have Docker and the Nvidia cuda
runtime for Docker (if you're on Linux, on Windows it comes packaged with Docker
Desktop).

### Testing

By default the container has my mining address stored in it. You can donate and test if
it works, you can just run it with all defaults:

`docker run --gpus 0 eldermillenial/tuna-py:0.5.0`

NOTE: The `--gpus 0` indicates that the container should run and use the first GPU on
your machine. You can run this container multiple times with different GPUs selected.

This should give you an output like this after a few minutes:

```bash
31-Aug-24 17:31:55 - tuna     - INFO     - tuna-py v0.5.0 by Elder Millenial
31-Aug-24 17:31:55 - tuna     - INFO     - Address: addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza
31-Aug-24 17:31:55 - tuna     - INFO     - Stratum Target: 66.228.34.31:3643
31-Aug-24 17:31:55 - tuna     - INFO     - Stratum Worker: HOME
31-Aug-24 17:31:55 - tuna     - INFO     - Submit Difficulty: 8
31-Aug-24 17:31:55 - tuna     - INFO     - Number of CUDA Loops: 4096
31-Aug-24 17:31:56 - tuna     - INFO     - New job: 00007f2a, (0.000 Mh/s, submissions=0, time=1.000s),
31-Aug-24 17:31:56 - tuna     - INFO     - Difficulty: 7
31-Aug-24 17:32:00 - tuna     - INFO     - Submitting nonce: 20000300f77320e050150000, hash=00000000488ce19bc39962a3b312e2669d3c94102a24017737e10b7ccee36743, address=addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza, worker=HOME
31-Aug-24 17:32:02 - tuna     - INFO     - Submitting nonce: c97700006117ab649a1a0000, hash=00000000477d86da8110ca98eeae62ab98a93146f1f9ea246ab00c2b213ef800, address=addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza, worker=HOME
31-Aug-24 17:32:06 - tuna     - INFO     - 420.913 Mh/s
31-Aug-24 17:32:09 - tuna     - INFO     - Submitting nonce: 54bc030033ec87d0a0030000, hash=00000000748881a3fcf0656d75a8f9871dc9061c00d149c0f8344ee0b88999d6, address=addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza, worker=HOME
31-Aug-24 17:32:11 - tuna     - INFO     - Submitting nonce: cf9f0100891a9008221a0000, hash=00000000da0385fda846010b69aa74f34bf00cabc23f037c2151c3aab0295a32, address=addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza, worker=HOME
```

### Configuration

There are two types of parameters you can configure:

1. Environment Variables
2. Tool parameters

The environment variables allow you to set your mining address and worker name just like
you would with the environment file. To set environment variables, use `-e KEY=VALUE`.
For example, to set the address and worker name, you would do:

`docker run --gpus 0 -e ADDRESS=addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza -e STRATUM_WORKER=HOME eldermillenial/tuna-py:0.5.0`

For tool parameters like `--nloops`, you can just add them to the end of the docker
command:

`docker run --gpus 0 eldermillenial/tuna-py:0.5.0 --nloops 4096 --difficulty 8`