from pathlib import Path

import cv2
from ultralytics import YOLO


# Altere estes caminhos para testar outro modelo ou outra imagem.
MODEL_PATH = Path(__file__).resolve().parent / "models" / "modelo_pretreinado.pt"
IMAGE_PATH = r"C:\Users\lucia\Desktop\UFPI\6-periodo\Sistemas Distribuidos\val2017\img20.jpg"


image = cv2.imread(IMAGE_PATH)
if image is None:
	raise FileNotFoundError(f"Não foi possível abrir a imagem: {IMAGE_PATH}")

model = YOLO(str(MODEL_PATH))
results = model.predict(source=image, conf=0.5, verbose=False)

annotated_image = results[0].plot()
cv2.imshow("Predicao YOLO", annotated_image)
cv2.waitKey(0)
cv2.destroyAllWindows()

