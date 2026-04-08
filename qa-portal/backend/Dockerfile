FROM python:3.12-slim

WORKDIR /app

# Dependencias del sistema necesarias para psycopg2 y Selenium
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    chromium \
    chromium-driver \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Hacer el entrypoint ejecutable
RUN chmod +x entrypoint.sh

# Carpeta de almacenamiento de capturas
RUN mkdir -p /app/storage/screenshots

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
