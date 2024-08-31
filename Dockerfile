FROM nvidia/cuda:12.6.0-devel-ubuntu24.04

ENV STRATUM_WORKER=HOME
ENV STRATUM_HOST=66.228.34.31
ENV STRATUM_PORT=3643
ENV STRATUM_PASSWORD=ElderMillenial
ENV ADDRESS=addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza

RUN apt-get update && apt-get install \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    cmake \
    -y

# RUN git clone https://github.com/theeldermillenial/tuna-py
COPY . /tuna-py

WORKDIR /tuna-py 
RUN python3 -m venv .venv && \
    /tuna-py/.venv/bin/pip install -e . --no-cache-dir
RUN git submodule init && \
    git submodule update && \
    cmake . && \
    make clean && make

ENTRYPOINT ["/tuna-py/.venv/bin/python", "-m", "tuna"]