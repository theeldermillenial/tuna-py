import logging
import os
import time

import typer

from tuna.config import ADDRESS
from tuna.config import STRATUM_HOST
from tuna.config import STRATUM_PASSWORD
from tuna.config import STRATUM_WORKER
from tuna.config import STRATUM_PORT
from tuna.datums import TargetState
from tuna.utils import get_hash
from tuna.stratum import Stratum
from tuna.stratum import StratumMethod

try:
    from tuna.gpu_library import mine_cuda

    HAS_GPU = True
except ModuleNotFoundError:
    HAS_GPU = False

logging.basicConfig(
    format="%(asctime)s - %(name)-8s - %(levelname)-8s - %(message)s",
    datefmt="%d-%b-%y %H:%M:%S",
)
logger = logging.getLogger("tuna")
logger.setLevel(os.environ.get("TUNA_LOG", "INFO"))

connection = Stratum(
    address=ADDRESS.encode(),
    password=STRATUM_PASSWORD,
    host=STRATUM_HOST,
    worker=STRATUM_WORKER,
    port=STRATUM_PORT,
)

MAGIC_HASH_NUMBER = 256 * 32 * 32

def main(nloops: int = 4096, difficulty: int = 8):

    logger.info("tuna-py v0.4.0 by Elder Millenial")
    logger.info(f"Address: {ADDRESS.encode()}")
    logger.info(f"Stratum Target: {STRATUM_HOST}:{STRATUM_PORT}")
    logger.info(f"Stratum Worker: {STRATUM_WORKER}")
    logger.info(f"Submit Difficulty: {difficulty}")
    logger.info(f"Number of CUDA Loops: {nloops}")

    with connection as conn:

        conn.subscribe()
        conn.authorize()

        submit_count = 0
        hash_count = 0
        start = time.time()
        while True:
            
            while len(conn.messages) > 0:
                message = conn.messages.pop(0)
                if hasattr(message, "method"):
                    logger.debug(message)

                    if message.method == StratumMethod.notify:
                        logger.info(
                            f"New job: {conn.job_id}, ({hash_count/(10 ** 6 * (time.time() - start)):0.3f} Mh/s, submissions={submit_count}, time={time.time() - start:0.3f}s),"
                        )
                        logger.info(f"Difficulty: {conn.difficulty}")
                        with conn.job_lock:
                            job_id = conn.job_id
                        submit_count = 0
                        hash_count = 0
                        start = time.time()
                        next_hash_time = start + 10
                    elif message.method == StratumMethod.difficulty:
                        logger.debug(f"New difficulty: {conn.difficulty}")
                elif message.id == 4:
                    if message.result:
                        logger.debug("Successfully submitted nonce!")
                    else:
                        logger.error(f"Error submitting nonce: {message.error}")

            try:
                conn.thread.result(timeout=0)
            except TimeoutError:
                pass

            if conn.target is None:
                time.sleep(1)
                continue
            
            target_bytes = bytearray(conn.target.to_cbor())
            target_view = memoryview(target_bytes)

            window = slice(
                4 + len(conn.extra_nonce_1),
                4 + len(conn.extra_nonce_1) + len(conn.extra_nonce_2),
            )
            nonce_size = len(conn.extra_nonce_2)

            if not HAS_GPU:
                hsh = get_hash(target_bytes)
                while not all(["0" == h for h in hsh.hex()[:7]]):
                    try:
                        target_view[window] = (
                            int.from_bytes(target_view[window]) + 1
                        ).to_bytes(nonce_size)
                    except OverflowError:
                        print(target.nonce)
                        raise
                    hsh = get_hash(target_bytes)
                    hash_count += 1
                nonces = [target_view[window].hex()][:8]
            else:
                logger.debug("Starting GPU hashing...")
                nonces = mine_cuda(conn.target.to_cbor(), difficulty, nloops)
                hash_count += MAGIC_HASH_NUMBER * nloops
                logger.debug("Finished GPU hashing!")

                nonces = [n[8:] for n in nonces]

            with conn.job_lock:
                if job_id != conn.job_id:
                    continue

            if time.time() > next_hash_time:
                next_hash_time += 10
                logger.info(f"{hash_count/(10 ** 6 * (time.time() - start)):0.3f} Mh/s")

            for nonce in nonces:
                target_view[window] = (int.from_bytes(bytes.fromhex(nonce))).to_bytes(
                    nonce_size
                )
                hsh = get_hash(target_bytes)
                logger.info(
                    f"Submitting nonce: {target_view[window].hex()}, hash={hsh.hex()}, address={conn.address}, worker={conn.worker}"
                )
                conn.submit_nonce(nonce)
                submit_count += 1

                target_view[window] = (int.from_bytes(target_view[window]) + 1).to_bytes(
                    nonce_size
                )
                with conn.job_lock:
                    if job_id == conn.job_id:
                        conn.target = TargetState.from_cbor(target_bytes)

typer.run(main)
