import json
import socket
from datetime import datetime, timezone
from pathlib import Path

HOST = "0.0.0.0"
PORT = 5000

IMAGES_DIR = Path(__file__).parent / "storage" / "images"


def recv_exactly(connection: socket.socket, length: int) -> bytes:
    """Recebe exatamente a quantidade de bytes solicitada."""
    data = bytearray()

    while len(data) < length:
        chunk = connection.recv(length - len(data))

        if not chunk:
            raise ConnectionError(
                "Conexão encerrada antes do recebimento completo."
            )

        data.extend(chunk)

    return bytes(data)


def send_response(
    connection: socket.socket,
    payload: dict,
) -> None:
    """Envia uma resposta JSON precedida pelo seu tamanho em 4 bytes."""
    response = json.dumps(
        payload,
        ensure_ascii=False,
    ).encode("utf-8")

    response_size = len(response).to_bytes(
        4,
        byteorder="big",
    )

    connection.sendall(response_size)
    connection.sendall(response)


def handle_client(
    connection: socket.socket,
    address: tuple,
) -> None:
    print(f"\nConexão recebida de {address}")

    try:
        # Recebe os 4 bytes que representam o tamanho da imagem.
        size_bytes = recv_exactly(connection, 4)

        image_size = int.from_bytes(
            size_bytes,
            byteorder="big",
        )

        print(
            f"Tamanho da imagem: "
            f"{image_size / 1024:.1f} KB"
        )

        # Recebe exatamente os bytes da imagem.
        image_bytes = recv_exactly(
            connection,
            image_size,
        )

        # Gera um nome único baseado no timestamp.
        timestamp = datetime.now(timezone.utc).strftime(
            "%Y%m%d_%H%M%S_%f"
        )

        image_path = IMAGES_DIR / f"received_{timestamp}.jpg"

        image_path.write_bytes(image_bytes)

        print(f"Imagem salva em: {image_path}")

        # Resposta temporária para testar a comunicação.
        send_response(
            connection,
            {
                "objects": ["teste"],
            },
        )

        print("Resposta enviada.")

    except (ConnectionError, OSError, ValueError) as error:
        print(f"Erro: {error}")

    finally:
        connection.close()
        print("Conexão encerrada.")


def main() -> None:
    IMAGES_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    with socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM,
    ) as server:

        server.setsockopt(
            socket.SOL_SOCKET,
            socket.SO_REUSEADDR,
            1,
        )

        server.bind(
            (HOST, PORT)
        )

        server.listen()

        print(
            f"Servidor iniciado em "
            f"{HOST}:{PORT}"
        )
        print("Aguardando imagem...")

        while True:
            connection, address = server.accept()

            handle_client(
                connection,
                address,
            )


if __name__ == "__main__":
    main()