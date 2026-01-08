# STAGE 1: BUILDER - install all dependencies and compile any necessary components

FROM python:3.6 AS builder

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

FROM python:3.6-slim

WORKDIR /app

# 1. COPY BINARIES: Copy executables into a location in the PATH (needed for gunicorn to late strt successfully from the entrypoint)
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# 2. COPY PACKAGES: Copy the installed Python packages (the libraries)
COPY --from=builder /usr/local/lib/python3.6/site-packages/ /usr/local/lib/python3.6/site-packages/

# 3. COPY CODE: Copy the application code
COPY --from=builder /app /app

# Install only necessary runtime dependencies (in this case the PostgreSQL client)
RUN apt-get update && \
    apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]