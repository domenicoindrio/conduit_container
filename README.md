# Conduit: Multi-Stage Docker Orchestration
This repository demonstrates the modern containerization of the **Conduit** project, a full-stack blogging platform, based on the RealWorld App Example specifications. 

The objective of this project was to transform a legacy Angular/Django stack into a modern, portable, and orchestrated services architecture using **Docker Compose**.

This repository was created during my training at the ***Developer Akademie***.

## Project Note
While the core stack remains true to the original, minor adjustments were made to the backend requirements and Docker Python images. These updates were necessary to address **End-of-Life** (EOL) dependencies and ensure compatibility with modern container environments.

## Table of Contents
- [Quickstart](#quickstart)
- [Usage](#usage)
    - [Backend - Django Configuration](#backend---django-configuration)
    - [Backend - Admin access](#backend---admin-access)
    - [Environment file and Secret Management](#env-file-and-secret-management)
    - [Startup Behavior](#startup-behavior)
    - [Debugging & Maintenance: Logs](#debugging--maintenance-logs)
    - [Debugging & Maintenance: Cleanup](#debugging--maintenance-cleanup)
- [Architecture](#architecture)
    - [Overview](#overview)
    - [Nginx - Integrated Gateway and Reverse Proxy](#nginx---integrated-gateway-and-reverse-proxy)
    - [Multi-Stage Images](#multi-stage-images)
- [Data Persistency](#data-persistency)
- [Future Hardening - Security Note on Heaalthchecks](#future-hardening---security-note-on-heaalthchecks)

## Quickstart
### Prerequisites
- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/) 
- Optional: SSH access to your remote target environment

---

### Optional Step: Connect to the Remote Machine
If deploying remotely:
```bash
ssh <user>@<remote_ip>
```
--- 

### Clone the Repository
```bash
git clone git@github.com:domenicoindrio/conduit_container.git
cd conduit_container/
```
---

### Configure the `.env` File
Copy the [provided template](./config_template.env) and update the placeholders to your needs: 
```bash
cp config_template.env .env
```
> [!IMPORTANT]  
> **DO NOT** use default passwords or the example `SECRET_KEY` in production. Additionally avoid using common usernames like `admin`, `root`, or `administrator` for the `DJANGO_SUPERUSER_USERNAME`. Using a unique, non-obvious username adds a layer of protection against automated brute-force attacks that target standard admin accounts.   
> Change these values in your `.env` file before running the orchestration.

---

### Start the Conduit Site
```bash
docker compose up -d --build
```
Once the containers start successfully, your Conduit site will be reachable at:
- http://<your_ip>:8282

---

## Usage
This section covers useful information and tips for interacting with this project:

### Backend - Django Configuration
All configurations are handled within the main `settings.py` file, utilizing environment variables for containerized settings. This ensures a single *source of truth* for configuration.

---

### Backend - Admin access
A superuser is automatically created via the `entrypoint.sh` script using the credentials provided in the `.env` file.  

By choice, the Django Admin Panel is **not exposed** to the public. Only the Nginx gateway is reachable, minimizing attack surface.

To manage the backend securely, one of those option could be choosed:
- **SSH Tunneling**: Map the backend to the VM's loopback interface (change the port binding in `docker-compose.yml` to 127.0.0.1:8000:8000) and establish an encrypted bridge from your local machine: `ssh -i <key> -L 9000:127.0.0.1:8000 user@remote_server`. After that the admin panel will be reachable on local machine at http://localhost:9000/admin/
- **IP whitelisting**: Configure the Nginx `/admin/` location block with `allow <your_local_ip>;` and `deny all;` rules to restrict access to authorized IP only.
- **URL Obfuscating**: Modify the Django admin path within the `url.py` to a secret string and update the Nginx proxy pass accordingly.

> [!IMPORTANT]  
> To mantain a secure and isolated environment, this orchestration does't use bind mounts for configuration files. Any changes made to the `nginx.conf`, `docker-compose.yml`, or `.env` files require a full rebuild to take effect.  
> To apply changes run `docker compose up -d --build` to correctly *bake* them into the images.

---

### .env file and Secret Management
Sensitive data in never hardcoded. All credentials are injected via `.env` file.  
To mantain a secure environment:
- Replace defaults password with stronger ones.
- Restrict `.env` permissions after setup:
```bash
chmod 600 .env
```
Alternatively, for more security on a shared host, restrict directly the whole project folder to the current user:
```bash
chmod -R 700 ~/conduit_container
```

---

### Startup Behavior
The stack uses **Docker Healrtchecks** to ensure a clean startup sequence:
- The `backend` waits for the Postgres `db` to be *Healthy* before running migrations.
- The `entrypoint.sh` script automatically handles migrations, static file collection, and **superuser creation**.
- The `frontend` service (the Gateway) waits for the `backend` to be *Healthy* before becoming available and opening the port to external traffic. 

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
The application is orchestrated into three different services:
1. Database: PostgreSQL with persistent volume mapping.
2. Backend: Django REST Framework powered by Gunicorn.
3. Frontend and Gateway: Angular application served by Nginx, which also acts as the primary Reverse Proxy and entrypoint.

---

### Nginx - Integrated Gateway and Reverse Proxy
I have integrated a Reverse Proxy logic directly into the Frontend's Nginx configuration. This streamlines the architecture while maintaining:
- **Traffic Routing (CORS solution)**: Directs `/api` requests to the Django backend and all other traffic to the static Angular files. This ensures both share the same origin, eliminating CORS issues.
- **Security Layer**: The Frontend container is the only one exposed to the public internet, shielding the backend and database from direct external access.

---

### Multi-Stage Images
Both the Backend and the Frontend utilize **Multi-stage Builds**. In the first Stage dependencies are installed and assets are built. The final images are then swapped for a lightweight **Alpine or Slim Linux** base containing only the compiled binaries.
This results in two critical advantages:
- **Minimal image**: By removing the build tools (compilers and package managers) from the final image, the image size is drastically reduced.
- **Attack surface reduction**: If an attacker gains unauthotized access, they will find no compilers or package managers to build or download malicious tool, thus reducing and neutralizing privileges escalation and persistence.

---

## Data Persistency 
The database data is stored and managed in a **Docker volume** (`postgre_data`), ensuring that articles, users, and comments persist across restarts, container recreation, or updates.

---

## Future Hardening - Security Note on Healthchecks
In this Project I utilized `curl` for service orchestration and health monitoring. Future iterations may replace curl with a Python-based healtcheck script to further reduce attack vectors and surface to a potential intruder.