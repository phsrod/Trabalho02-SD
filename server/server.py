import socket
import struct
import json
from pathlib import Path

from detector import YOLODetector
from image_utils import decode_image, save_image

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
    """Recebe todos os blocos de uma imagem usando o protocolo do cliente."""
    image_parts = []

    while True:
        header_size_bytes = conn.recv(4)
        if not header_size_bytes:
            break
        if len(header_size_bytes) != 4:
            raise ConnectionError("Tamanho do cabecalho incompleto.")

        header_size = struct.unpack("!I", header_size_bytes)[0]
        headers = parse_headers(receive_exactly(conn, header_size))
        chunk_size = struct.unpack("!I", receive_exactly(conn, 4))[0]
        image_parts.append(receive_exactly(conn, chunk_size))

    if not image_parts:
        raise ValueError("Nenhum bloco de imagem foi recebido.")

    return b"".join(image_parts)


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


def main() -> None:
    detector = YOLODetector(str(MODEL_PATH))

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((HOST, PORT))
        server.listen()
        print(f"Servidor aguardando conexoes em {HOST}:{PORT}...")

        while True:
            conn, address = server.accept()
            with conn:
                print(f"Cliente conectado: {address}")
                handle_client(conn, detector)


if __name__ == "__main__":
    main()