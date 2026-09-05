import socket
import struct
import json
from pathlib import Path

from .detector import YOLODetector
from .image_utils import decode_image, save_image

HOST = "0.0.0.0"
PORT = 12345
MODEL_PATH = Path(__file__).resolve().parent / "models" / "modelo_pretreinado.pt"

def receive_exactly(conn: socket.socket, size: int) -> bytes:
    """
    Recebe exatamente 'size' bytes através do socket.

    Args:
        conn (socket.socket): O socket de conexão.
        size (int): O número exato de bytes a serem recebidos.
    Returns:
        bytes: Os bytes recebidos.
    """
    data = b""

    while len(data) < size:
        chunk = conn.recv(size - len(data))

        if not chunk:
            raise ConnectionError("Conexão encerrada pelo cliente.")

        data += chunk

    return data


def parse_headers(header_bytes: bytes) -> dict[str, str]:
    """
    Converte o cabecalho textual do protocolo em um dicionario.
    
    Args:
        header_bytes (bytes): Bytes do cabecalho recebido.
    Returns:
        dict[str, str]: Dicionario contendo os cabecalhos.
    """
    headers = {}
    for line in header_bytes.decode("utf-8").splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip()] = value.strip()
    return headers


def receive_image(conn: socket.socket) -> bytes:
    """Recebe uma imagem precedida pelo seu tamanho em bytes."""
    image_size = struct.unpack("!I", receive_exactly(conn, 4))[0]

    if image_size == 0:
        raise ValueError("Nenhuma imagem foi recebida.")

    return receive_exactly(conn, image_size)


def send_response(conn: socket.socket, objects: list[str], error: str | None = None) -> None:
    """Envia uma resposta JSON precedida pelo tamanho em bytes."""
    response = {"objects": objects}
    if error is not None:
        response["error"] = error

    payload = json.dumps(response, ensure_ascii=True).encode("utf-8")
    conn.sendall(struct.pack("!I", len(payload)) + payload)


def handle_client(conn: socket.socket, detector: YOLODetector) -> None:
    """
      Processa a conexão com o cliente, recebendo a imagem, realizando a detecção de objetos e enviando a resposta.
    Args:
        conn (socket.socket): O socket de conexão com o cliente.
        detector (YOLODetector): Instância do detector YOLO para realizar a detecção de objetos.
    Returns:
        None
    """
    try:
        image_bytes = receive_image(conn)
        image = decode_image(image_bytes)
        filename = save_image(image)
        objects = detector.detect(image)
        print(f"Imagem {filename}: {objects}")
        send_response(conn, objects)
    except (ConnectionError, ValueError, OSError) as error:
        print(f"Falha ao processar cliente: {error}")
        try:
            send_response(conn, [], str(error))
        except OSError:
            pass