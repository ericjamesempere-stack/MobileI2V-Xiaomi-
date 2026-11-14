FROM python:3.11-slim
WORKDIR /app
COPY ai_redraw/requirements.txt /app/ai_redraw/requirements.txt
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -r /app/ai_redraw/requirements.txt
COPY ai_redraw /app/ai_redraw
ENV REDRAW_MODEL_ID=stable-diffusion-v1-5/stable-diffusion-v1-5
EXPOSE 8765
CMD ["uvicorn", "ai_redraw.server:app", "--host", "0.0.0.0", "--port", "8765"]
