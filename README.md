# Tree of Knowledge

```
tok/
└── ai
    └── inference
        └── object_detection
            └── yolo.py
tok
└── ai
    └── inference
        └── object_detection
            ├── yolo_camera_cuda.py		# 4. Similar as 3 but use
            ├── yolo.py					# 1. Onnxruntime inference, preprocessing, postprocessing, visualize the outputs
            ├── yolo_video_cuda.py		# 3. Similar as 2 but use CUDA instead of CPU
            └── yolo_video.py			# 2. Similar as 1 but use input
```
