import os
import cv2
import numpy as np
import onnxruntime as ort
import onnx
import ast
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Model initialization
model_path = os.getenv("MODEL_PATH")
session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])

# Preprocess input image
img = cv2.imread(os.getenv("IMG_PATH"))
input_data = cv2.resize(img, (640, 640)).transpose(2, 0, 1)
input_data = input_data[np.newaxis, :, :, :].astype(np.float32) / 255.0

# Feed the input data to the model and do the inference
outputs = session.run(None, {session.get_inputs()[0].name: input_data})

# Postprocess the output and visualize the results
predictions = np.squeeze(outputs[0])
onnx_model = onnx.load(model_path)
props = {p.key: p.value for p in onnx_model.metadata_props}
names = ast.literal_eval(props['names']) if 'names' in props else {}
h, w = img.shape[:2]
for obj in predictions:
    x1, y1, x2, y2, conf, cls_id = obj
    if conf > 0.4:
        x1, x2 = int(x1 * w / 640), int(x2 * w / 640)
        y1, y2 = int(y1 * h / 640), int(y2 * h / 640)
        label = names.get(int(cls_id), f"ID:{int(cls_id)}")
        cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(img, f"{label} {conf:.2f}", (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
cv2.imshow("YOLO26", img)
cv2.waitKey(0)
