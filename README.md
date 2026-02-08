# Conduit: Multi-Stage Docker Orchestration
This repository demonstrates the modern containerization of the **Conduit** project, a full-stack blogging platform, based on the RealWorld App Example specifications. 

The objective of this project was to transform a legacy Angular/Django stack into a modern, portable, and orchestrated services architecture using **Docker Compose**.

This repository was created during my training at the ***Developer Akademie***.

## Project Note
While the core stack remains true to the original, minor adjustments were made to the backend requirements and Docker Python images. These updates were necessary to address **End-of-Life** (EOL) dependencies and ensure compatibility with modern container environments.

## Table of Contents
- [Quickstart](#quickstart)
- [Usage](#usage)
    - [Backend - Custom Django Settings Module](#backend---custom-django-settings-module)
    - [Backend - Admin access](#backend---admin-access)
    - [Environment file and Secret Management](#env-file-and-secret-management)
    - [Startup Behavior](#startup-behavior)
    - [Debugging & Maintenance: Logs](#debugging--maintenance-logs)
    - [Debugging & Maintenance: Cleanup](#debugging--maintenance-cleanup)
- [Architecture](#architecture)
    - [Overview](#overview)
    - [Nginx - Gateway and reverse proxy](#nginx---gateway-and-reverse-proxy)
    - [Multi-Stage Images](#multi-stage-images)
- [Data Persistency](#data-persistency)
- [Future Hardening - Security Note on Heaalthchecks](#future-hardening---security-note-on-heaalthchecks)

## Quickstart
### Prerequisites
- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/) 
- SSH access to your target environment

---

### Connect to the Remote Machine
```bash
ssh <user>@<remote_ip>
```
--- 

### Clone the Repository
```bash
git clone git@github.com: # here comese the repo link
cd conduit/
```
---

### Configure the `.env` File
Copy the [provided template](./config_template.env) and update the placeholders to your needs (especially passwords and `SECRET_KEY`):
```bash
cp config_template.env .env
```
---

### Start the Conduit Site
```bash
docker compose up -d --build
```
Once the containers start successfully, your Conduit site will be reachable at:
- http://<remote_address>:8282


## Usage
This section covers useful information and tips for interacting with this project:

### Backend - Custom Django Settings Module
To leave the original settings unscathed, a custom Django settings module was created: `test_docker.py`.
This module imports all configurations from the default settings file and overwrites specific options (such as database connections and security allowed hosts) required for the Docker environment.

---

### Backend - Admin access
A superuser is automatically created via the `entrypoint.sh` script using the credentials provided in the `.env` file.  
The admin panel can be reached at:  
http://<remote_address>:8282/admin

---

### .env file and Secret Management
Sensitive data in never hardcoded. All credentials are injected via `.env` file.  
To mantain a secure environment:
- Replace defaults password with stronger ones.
- Restrict `.env` permissions after setup:
```bash
chmod 600 .env
```

---

### Startup Behavior
The stack uses **Docker Healrtchecks** to ensure a clean startup sequence:
- The `backend` waits for the Postgres `db` to be *Healthy* before running migrations.
- The `entrypoint.sh` script automatically handles migrations, static file collection, and **superuser creation**.
- The `frontend` service waits for the `backend` to be *Healthy* before becoming available. 
- The `nginx` **Gateway** finalizes the sequence by orchestrating traffic between the ready services.

---

### Debugging & Maintenance: Logs
Gunicorn and Python are configured to run **unbuffered** to ensure real time log visibility (`PYTHONUNBUFFERED=1` in `.env` file and `--access-logfile - --error-logfile -` in entrypoint script).
You can monitor the stack with the following commands:

- Follow logs in real time:
```bash
docker compose logs -f
``` 

- Check a specific service (e.g., Database):
```bash
docker compose logs db
``` 

- Export logs to a file:
```bash
docker compose logs frontend > conduit_frontend_log.txt
``` 

---

### Debugging & Maintenance: Cleanup
- Stop the services and remove containers/networks:
```bash
docker compose down
```

- Total Reset (Wipe Database Volumes):
```bash
docker compose down -v
```
---

## Architecture 
### Overview
The application is orchestrated into four different services:
1. Database: PostgreSQL with persistent volume mapping.
2. Backend: Django REST Framework powered by Gunicorn.
3. Frontend: Angular application served by Nginx.
4. Gateway: A dedicated Nginx Reverse Proxy serving as the single entry point.

---

### Nginx - Gateway and Reverse Proxy
I implemented a centralized Nginx gateway for two critical reasons:
- **Traffic routing (CORS issues solution)**: directs `/api` requests to the Django backend and all other traffic to the frontend. This allows both services to share the same origin, eliminating CORS issues.
- **Security layer**: Nginx acts as the only container exposed to the host/public internet, shielding the application and database from direct external access.

---

### Multi-Stage Images
Both the Backend and the Frontend utilize **Multi-stage Builds**. In the first Stage dependencies are installed and assets are built. The final images are then swapped for a lightweight **Alpine or Slim Linux** base containing only the compiled binaries.
This results in two critical advantages:
- **Minimal image**: By removing the build tools (compilers and package managers) from the final image, the image size is drastically reduced.
- **Attack surface reduction**: If an attacker gains unauthotized access, they will find no compilers or package managers to build or download malicious tool, thus reducing and neutralizing privileges escalation and persistence.

---

## Data Persistency 
The database data is stored and managed in a **Docker volume** (`postgre_data`), ensuring that articles, users, and comments persist across restarts, container recreation, or updates.

## Future Hardening - Security Note on Heaalthchecks
In this Project I utilized `curl` for service orchestration and health monitoring. Future iterations may replace curl with a Python-based healtcheck script to further reduce attack vectors and surface to a potential intruder.