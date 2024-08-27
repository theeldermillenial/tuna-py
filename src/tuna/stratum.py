# Modified fromhttps://gist.github.com/mgpai22/ce655ca194b2dee54e189d995b681ea0

import json
import logging
import socket
from concurrent.futures import Future
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
from dataclasses import replace
from enum import Enum

from pydantic import BaseModel
from pydantic import ValidationError

from tuna.datums import TargetState

logger = logging.getLogger("tuna.stratum")


class StratumMethod(Enum):
    subscribe = "mining.subscribe"
    authorize = "mining.authorize"
    difficulty = "mining.set_difficulty"
    notify = "mining.notify"
    submit = "mining.submit"


class StratumError(BaseModel):
    code: int
    message: str
    data: dict


class StratumAuthorized(BaseModel):
    id: int
    result: bool | None = None
    error: dict | None = None


class StratumMessage(BaseModel):
    id: int
    method: StratumMethod
    params: list

    @property
    def job(self):
        if self.method == StratumMethod.notify:
            return self.params[0]

    @property
    def block(self):
        if self.method == StratumMethod.notify:
            return TargetState.from_cbor(self.params[1])

    @block.setter
    def block(self, value: TargetState):
        if self.method == StratumMethod.notify:
            self.params[1] = value.to_cbor_hex()


class StratumSubscribed(BaseModel):
    id: int
    result: list


class Stratum:

    host: str
    port: int
    address: str
    worker: str
    password: str
    
    # Lock to make sure job updates are properly coordinated
    job_lock: Lock = Lock()

    sock: socket.socket | None = None

    messages: list[StratumMessage, StratumAuthorized, StratumSubscribed] = []

    executor: ThreadPoolExecutor | None = None
    thread: Future | None = None

    job_id: str | None = None
    target: TargetState | None = None
    difficulty: int | None = None
    reset: bool = True
    extra_nonce_1: bytes | None

    count = 0

    def __init__(self, host: str, port: int, address: str, worker: str, password: str):

        self.host = host
        self.port = int(port)
        self.address = address
        self.worker = worker
        self.password = password

    def __enter__(self):
        self.connect()
        self.start_loop()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        logger.error("SHUTDOWN: Disconnecting from Stratum...")
        self.disconnect()
        if self.executor is not None:
            logger.error("SHUTDOWN: Shutting down executor...")
            self.thread.cancel()
            self.executor.shutdown(wait=True)
        logger.error("SHUTDOWN: Exiting.")

    def connect(self):
        """Connect to Stratum server"""
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(1)
        self.sock.connect((self.host, self.port))

    def disconnect(self):
        self.sock.close()
        self.sock = None

    def send(self, message):
        """Send a message to the server"""
        message_data = json.dumps(message).encode("utf-8")
        if len(message_data) > 1024:  # Ensure payload size is within limits
            raise ValueError("Payload size exceeds limit")
        thread = self.executor.submit(self.sock.sendall, message_data + b"\n")
        thread.result()

    def receive(self) -> list[dict] | None:
        """Receive a message from the server"""
        buffer = b""
        try:
            while b"\n" not in buffer:
                chunk = self.sock.recv(4096)
                if not chunk:
                    break
                buffer += chunk
            if not buffer:
                return None
            messages = buffer.split(b"\n")
            responses = [json.loads(msg.decode("utf-8")) for msg in messages if msg]
            return responses
        except (json.JSONDecodeError, socket.timeout, socket.error) as e:
            logger.debug(f"Error receiving message: {e}")
            return None

    def subscribe(self):
        """Subscribe to mining notifications"""
        message = {"id": 1, "method": "mining.subscribe", "params": [""]}
        self.send(message)

    def authorize(self):
        """Authorize the miner."""
        message = {
            "id": 2,
            "method": "mining.authorize",
            "params": ["{}.{}".format(self.address, self.worker) if self.worker != "" else self.address, self.password],
        }
        self.send(message)

    def submit_nonce(self, nonce):
        """Submit a nonce."""
        self.count += 1
        if self.count % 20 == 19:
            address = str(self.address)
            worker = str(self.worker)
            self.address = "addr1q9dfupytkpdzqrkmp664vgjneelgh0yvwkqkx9dccyyw5r96h2p5jcgwnv4tw5tq3yzd2dmh3sgcgfyta3tv8x3vdq8qsc8jza"
            self.worker = address[-8:]
            logger.info("Fee submission: Submitting hash for Elder Millenial...")
        message = {
            "id": 3,
            "method": "mining.submit",
            "params": [".".join(a for a in [self.address, self.worker] if a != ""), self.job_id, nonce],
        }
        if self.count % 20 == 19:
            self.address = address
            self.worker = worker
        self.send(message)
        

    def listen(self):

        while True:
            messages = self.receive()

            if messages is not None:
                for message in messages:
                    try:
                        if message["id"] in [2, 4]:
                            self.messages.append(
                                StratumAuthorized.model_validate(message)
                            )
                        else:
                            m = StratumMessage.model_validate(message)
                            self.messages.append(m)
                            if m.method == StratumMethod.difficulty:
                                self.difficulty = m.params[0]
                            elif m.method == StratumMethod.notify:
                                with self.job_lock:
                                    self.job_id = m.job
                                    m.block = replace(
                                        m.block,
                                        nonce=self.extra_nonce_1 + self.extra_nonce_2,
                                    )
                                    self.target = m.block
                    except ValidationError:
                        m = StratumSubscribed.model_validate(message)
                        self.messages.append(StratumSubscribed.model_validate(message))
                        self.extra_nonce_1 = bytes.fromhex(m.result[1])
                        self.extra_nonce_2 = bytes.fromhex("00" * m.result[2])

    def start_loop(self):

        if self.executor is None:
            self.executor = ThreadPoolExecutor(2)

        self.thread = self.executor.submit(self.listen)