import cv2
import numpy as np
from datetime import datetime
from pathlib import Path


IMAGE_DIR = Path(__file__).resolve().parent / "received_images"
IMAGE_DIR.mkdir(exist_ok=True)


def decode_image(image_bytes: bytes) -> np.ndarray:
    """Decodifica os bytes da imagem recebida em um array NumPy.
    Args:
        image_bytes (bytes): Bytes da imagem recebida.
    Returns:
        np.ndarray: Array NumPy representando a imagem decodificada.
    """
    array = np.frombuffer(image_bytes, dtype=np.uint8)

    image = cv2.imdecode(array, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("Não foi possível decodificar a imagem.")

    return image


def save_image(image: np.ndarray) -> str:
    """Salva a imagem recebida em um arquivo com
    nome único baseado no timestamp.
    Args:
        image (np.ndarray): Array NumPy representando a imagem a ser salva.
    Returns:
        str: Nome do arquivo salvo.
    """
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    filename = f"{timestamp}.jpg"

    path = IMAGE_DIR / filename

    cv2.imwrite(str(path), image)

    return filename