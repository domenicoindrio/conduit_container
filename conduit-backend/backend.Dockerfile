# STAGE 1: BUILDER - install all dependencies and compile any necessary components

FROM python:3.7-slim AS builder

WORKDIR /app

COPY requirements.txt .

# Install system dependencies and other dependencies needed to install Python packages
RUN apt-get update && \
    apt-get install -y build-essential libpq-dev curl && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# STAGE 2: RUNTIME - Start with a fresh clean image and run the application with only the necessary components

FROM python:3.7-slim

WORKDIR /app

# 1. COPY BINARIES and PACKAGES: Copy executables and the installed Python packages (libraries)
COPY --from=builder /usr/local/ /usr/local/

# 2. COPY CODE: Copy the application code
COPY --from=builder /app /app

# Install only necessary runtime dependencies (in this case the PostgreSQL client and curl)
RUN apt-get update && \
    apt-get install -y postgresql-client curl && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]