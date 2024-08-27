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
