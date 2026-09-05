import socket
from pathlib import Path

from .detector import YOLODetector
from .server import handle_client

MODEL_PATH = Path(__file__).resolve().parent / "models" / "modelo_pretreinado.pt"

HOST = "0.0.0.0"
PORT = 5000

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