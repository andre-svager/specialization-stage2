# ---- Base Image ----
FROM python:3.11-slim

# ---- Environment ----
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# ---- Workdir ----
WORKDIR /app

# ---- System Dependencies (optional but useful for many python libs) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ---- Install Python Dependencies ----
COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ---- Copy Application ----
COPY . .

# ---- Expose Health Port ----
EXPOSE 8005

# ---- Healthcheck (optional but useful in K8s / Docker) ----
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8005/health || exit 1

# ---- Run Service ----
CMD ["gunicorn", "--bind", "0.0.0.0:8005", "app:app"]