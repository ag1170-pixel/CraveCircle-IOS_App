# faster-whisper large-v3 on GPU (CTranslate2 needs CUDA + cuDNN).
# Base carries CUDA 12 + cuDNN 9 runtime for float16 inference.
FROM nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/models \
    WHISPER_MODEL=small \
    WHISPER_DEVICE=auto \
    WHISPER_COMPUTE_TYPE=float16

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip ffmpeg tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY app ./app

# large-v3 (~3GB) downloads on first boot into HF_HOME (mount a volume so it persists).
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
