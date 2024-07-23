import logging
import time

from tuna.config import ADDRESS
from tuna.config import STRATUM_HOST
from tuna.config import STRATUM_PASSWORD
from tuna.config import STRATUM_PORT
from tuna.datums import StateV2
from tuna.datums import TargetState
from tuna.utils import latest_block
from tuna.utils import get_hash
from tuna.stratum import Stratum
from tuna.stratum import StratumMethod

logging.basicConfig(
    format="%(asctime)s - %(name)-8s - %(levelname)-8s - %(message)s",
    datefmt="%d-%b-%y %H:%M:%S",
)
logger = logging.getLogger("tuna")
logger.setLevel(logging.INFO)

connection = Stratum(
    address=ADDRESS.encode(),
    password=STRATUM_PASSWORD,
    host=STRATUM_HOST,
    port=STRATUM_PORT,
)

with connection as conn:

    conn.subscribe()
    conn.authorize()

    submit_count = 0
    hash_count = 0
    start = time.time()
    while True:
        # logger.info("Checking messages...")
        while len(conn.messages) > 0:
            message = conn.messages.pop(0)
            if hasattr(message, "method"):
                logger.debug(message)

                if message.method == StratumMethod.notify:
                    logger.info(
                        f"New job: {conn.job_id}, ({hash_count/(10 ** 6 * (time.time() - start)):0.3f} Mh/s, submissions={submit_count}, time={time.time() - start:0.3f}s),"
                    )
                    submit_count = 0
                    hash_count = 0
                    start = time.time()
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

        job_id = conn.job_id
        target_bytes = bytearray(conn.target.to_cbor())
        target_view = memoryview(target_bytes)

        hsh = get_hash(target_bytes)

        window = slice(
            4 + len(conn.extra_nonce_1),
            4 + len(conn.extra_nonce_1) + len(conn.extra_nonce_2),
        )
        nonce_size = len(conn.extra_nonce_2)
        while not all(["0" == h for h in hsh.hex()[: conn.difficulty]]):
            try:
                target_view[window] = (
                    int.from_bytes(target_view[window]) + 1
                ).to_bytes(nonce_size)
            except OverflowError:
                print(target.nonce)
                raise
            hsh = get_hash(target_bytes)
            hash_count += 1

        if job_id != conn.job_id:
            continue

        logger.debug(f"Submitting nonce: {target_view[window].hex()}, hash={hsh.hex()}")
        conn.submit_nonce(target_view[window].hex())
        submit_count += 1

        target_view[window] = (int.from_bytes(target_view[window]) + 1).to_bytes(
            nonce_size
        )
        conn.target = TargetState.from_cbor(target_bytes)

# while True:
#     start = time.time()
#     block = latest_block()
#     target = block.target()
#     target_bytes = bytearray(target.to_cbor())
#     target_view = memoryview(target_bytes)

#     hsh = get_hash(target_bytes)

#     start = time.time()
#     zero = int.to_bytes(0)
#     count = 0
#     while not all(["0" == h for h in hsh[:3].hex()]):
#         try:
#             target_view[4:8] = (int.from_bytes(target_view[4:8]) + 1).to_bytes(4)
#         except OverflowError:
#             print(target.nonce)
#             raise
#         hsh = get_hash(target_bytes)
#         count += 1

#     print(hsh.hex())
#     print(int.from_bytes(target_view[4:8]))
#     print(count)
#     print(f"{count/(time.time() - start):.2f}h/s")
#     print(time.time() - start)
#     print(TargetState.from_cbor(bytes(target_bytes)))
#     break
