from dataclasses import dataclass

from tuna.config import ADDRESS

from pycardano import PlutusData


@dataclass
class TargetState(PlutusData):
    CONSTR_ID = 0

    nonce: bytes
    miner: bytes
    block_number: int
    current_hash: bytes
    leading_zeros: int
    target_number: int
    epoch_time: int


@dataclass
class StateV2(PlutusData):
    CONSTR_ID = 0

    block_number: int
    current_hash: bytes
    leading_zeros: int
    target_number: int
    epoch_time: int
    current_posix_time: int
    merkle_root: bytes

    def target(self):

        return TargetState(
            nonce=bytes.fromhex("00000000"),
            miner=ADDRESS.payment_part.payload,
            epoch_time=self.epoch_time,
            block_number=self.block_number,
            current_hash=self.current_hash,
            leading_zeros=self.leading_zeros,
            target_number=self.target_number,
        )
