## CHANGELOG

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

