from ultralytics import YOLO
import numpy as np


class YOLODetector:
    """Realiza deteccoes de objetos usando um modelo YOLO."""

    def __init__(self, model_path: str) -> None:
        self.model = YOLO(model_path)

    def detect(self, image: np.ndarray) -> list[str]:
        results = self.model.predict(
            source=image,
            conf=0.5,
            verbose=False, # Desativa a exibição de informações detalhadas durante a predição.
        )

        detections = []
        for result in results:
            class_ids = result.boxes.cls.cpu().numpy()

            for class_id in class_ids:
                detections.append(result.names[int(class_id)])

        return detections