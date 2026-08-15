# Conduit: CI/CD Pipeline
This feature branch expands the [original Docker setup](link to main branch) with an automated CI/CD pipeline. 

The purpose of this branch is to demonstrate the shift from manual containerization and deployment to a fully automated workflow. This is achieved using GitHub Actions to build backend and frontend Docker images concurrently, pushe them to GitHub Container Registry (GHCR), and deploy them safely to a remote production VM over SSH.

This repository was created during my training at the ***Developer Akademie***.

## Table of Contents
- [Quickstart](#quickstart)
- [Usage](#usage)
    - [Pipeline Overview, Execution and Verification](#pipeline-overview-execution-and-verification)
    - [Backend - Admin access](#backend---admin-access)
    - [Environment file and Secret Management](#env-file-and-secret-management)
    - [Error handling](#error-handling)
    - [Debugging & Maintenance: Logs](#debugging--maintenance-logs)
- [Data Persistency](#data-persistency)
- [Future Implementation - Automated Rollback](#future-implementation---automated-rollback)

## Quickstart
### Prerequisites
- Github account
- Remote target environment (VM/VPS) accessible via SSH
- [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/) installed on the remote target

---

### Clone the Repository
Clone the project to your local machine and switch to `feature/ci-cd` branch:
```bash
git clone git@github.com:dintherio/conduit_container.git
cd conduit_container/
git checkout feature/ci-cd
```

---

### Configure the `.env` File
Copy the [provided template](./config_template.env) and update the placeholders to your needs: 
```bash
cp config_template.env .env
```
> [!NOTE]  
> The variable `ALLOWED_HOSTS` is omitted from the template by design. It is dynamically injected during workflow execution alongside the production server address defined in GitHub Secrets (see next section).

> [!IMPORTANT]  
> **DO NOT** use default passwords or the example `SECRET_KEY` in production. Additionally avoid using common usernames like `admin`, `root`, or `administrator` for the `DJANGO_SUPERUSER_USERNAME`. Using a unique, non-obvious username adds a layer of protection against automated brute-force attacks that target standard admin accounts.   
> Change these values in your `.env` file before running the orchestration.

---

### Configure GitHub Secrets (One-Time Setup)
In your GitHub repository, navigate to **Settings --> Secrets and variables --> Actions** and add following Repository secrets:

- `VM_HOST`: Target VM IP address
- `VM_USER`: SSH username on the VM
- `VM_SSH_KEY`: Private SSH Key matching the `~/.ssh/authorized_keys` entry on the VM
- `ENV_FILE`: Content of the production `.env` 

---

### Trigger the Deployment
You can trigger the pipeline using both following methods:

### Option A: Automatic Trigger (Git Push)  
Commit and push changes directly to the feature branch:
```bash
git add .
git commit -m "feat: update pipeline config"
git push origin feature/ci-cd
```

### Option B: Manual Trigger (GitHub UI)  
1. Navigate to your repository on GitHub
2. Click the **Actions** tab
3. Select **CI-CD Pipeline** from the left sidebar
4. Click **Run workflow**

---

### Verify Production Status
Once the workflow completes successfully, reach your live Conduit application at:  
- http://<your_ip>:8282

---

## Usage
This section expands to the original by adding useful information and tips for interacting with this project:

### .env file and Secret Management
Sensitive data in never hardcoded and/or committed to source control.  
During deployment, the pipeline constructs the `.env` file dynamically:
- Secret credentials (SECRET_KEY, database passwords) are supplied through GitHub Secrets.
- Dynamic runtime parameters (ALLOWED_HOSTS, GITHUB_REPOSITORY_OWNER) are injected based on the deployment target context.
- Strict file permission management prevents unauthorized local access on the runner.

---

### Error Handling
Execution control is enforced at three distinct levels:
1. **Step Level** (Default behaviour): If any individual step fails, the execution of that job stops immediately.
2. **Matrix Level** (`fail-fast: true`): Due explicit `fail-fast` rule, if either the backend or frontend build fails, GitHub Actions immediately cancels the parallel runner to prevent wasteful resource usage.
3. **Job Level** (`needs: build`): Job 2 explicitly dependends on Job 1. If any build task fails, deployment is aborted entirely, preventing a broken build from being deployed to your remote VM.

---

### Debugging & Maintenance: Logs
After logging into the remote machine, you can monitor the stack with the following commands:

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
If needed, use periodically the appropriate cleanup command based on your target:  
- **Standard Runner Maintenance**: Deletes stopped containers, dangling images, unused networks, and build cache. Preserves tagged images. 
```bash
docker system prune -f
```

- **Deep Image Cleanup**: Deletes **all** images not actively referenced by a container (including tagged images), plus dangling layers. Leaves containers and networks untouched. 
```bash
docker image prune -a -f
```

---

## Architecture
### Pipeline Overview
```text
[ Push / Dispatch ]
       │
       ├──► [ Job 1: Build & Push (Parallel Matrix) ]
       │        ├── Conduit Frontend (node:alpine -> ghcr.io)
       │        └── Conduit Backend  (Django -> ghcr.io)
       │
       └──► [ Job 2: Remote VM Deployment (SSH) ]
                ├── SCP docker-compose.yml to VM
                ├── Inject .env + ALLOWED_HOSTS + GITHUB_REPOSITORY_OWNER
                ├── Authenticate Docker with GHCR
                └── Pull latest images & restart containers (`docker compose up -d`)
```
### Jobs Breakdown
#### Job 1: Build and Push (Parallel Matrix)
To reduce overall process time, and since both steps are indipendent, **Job 1** makes use of `strategy.matrix` to dispatch two separates runners and execute the job concurrently. Both build their respective Docker images and push them to GitHub Container Registry (GHCR).

#### Job 2: Remote VM Deployment (SSH)
To keep deployment secure and automated, **Job 2** executes remotely via SSH:
- Copies `docker-compose.yml` to the VM workspace via SCP.
- Generates the runtime `.env` file using the `ENV_FILE` secret.
- Dynamically appends computed environment variables (`ALLOWED_HOSTS`, lowercased `GITHUB_REPOSITORY_OWNER`).
- Logs into GHCR on the target machine and pulls the newly published image tags.
- Recreates and restarts services cleanly using `docker compose up -d --remove-orphans`.

---

## Data Persistency 
The database data is stored and managed in a **Docker volume** (`postgre_data`), ensuring that articles, users, and comments persist across restarts, container recreation, or updates.

---