import os
from hashlib import sha256

import blockfrost
from dotenv import load_dotenv
from pycardano import DeserializeException
from tuna.datums import StateV2
from tuna.config import CONFIG

load_dotenv()

client = blockfrost.BlockFrostApi(
    project_id=os.environ["PROJECT_ID"], base_url=blockfrost.ApiUrls.preview.value
)


def latest_block() -> StateV2:

    utxos = client.address_utxos(
        address=CONFIG["preview"]["address"], return_type="json"
    )

    for utxo in utxos:
        if utxo["inline_datum"] is not None:
            try:
                return StateV2.from_cbor(utxo["inline_datum"])
            except DeserializeException:
                continue

    raise ValueError("No utxo found.")


def get_hash(payload: bytes):

    first_hash = sha256(payload).digest()

    second_hash = sha256(first_hash).digest()

    return second_hash


if __name__ == "__main__":
    print(
        get_hash(
            bytes.fromhex(
                "d8799f500c1ba0d2f6d40300ee5b75c4ac0700005820c113b5d664e99fb7cd67bb5f66dab1a0e459196cde00e266757e46c1f274c47d1a12c730a0194ebf582000000004bb09871d46b848df66d8fa3f796e4de95c751b699103eee89cd35d9007199864ff"
            )
        ).hex()
    )
