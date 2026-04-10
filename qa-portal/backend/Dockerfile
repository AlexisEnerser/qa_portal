FROM python:3.12-slim

WORKDIR /app

# Dependencias del sistema para psycopg2, Selenium y Playwright
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    curl \
    chromium \
    chromium-driver \
    libjpeg-dev \
    zlib1g-dev \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Usar Chromium del sistema en vez de descargar otro con Playwright
ENV PLAYWRIGHT_BROWSERS_PATH=/usr/lib/chromium
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY . .

RUN chmod +x entrypoint.sh
RUN mkdir -p /app/storage/screenshots

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
