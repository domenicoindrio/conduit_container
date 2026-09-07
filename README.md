# Conduit: CI/CD Pipeline
This feature branch expands the [original Docker setup](https://github.com/dintherio/conduit_container/tree/main) with an automated CI/CD pipeline. 

The purpose of this branch is to demonstrate the shift from manual containerization and deployment to a fully automated workflow. This is achieved using GitHub Actions.  

Backend and frontend Docker images are built concurrently and dual-tagged, pushed to GitHub Container Registry (GHCR), and deployed safely to a remote production VM over SSH.

This repository was created during my training at the ***Developer Akademie***.

## Table of Contents
- [Quickstart](#quickstart)
- [Usage](#usage)
    - [Environment file and Secret Management](#env-file-and-secret-management)
    - [Error handling](#error-handling)
    - [Debugging & Maintenance: Logs](#debugging--maintenance-logs)
    - [Debugging & Maintenance: Cleanup](#debugging--maintenance-cleanup)
- [Architecture](#architecture)
    - [Pipeline Overview](#pipeline-overview)
    - [Jobs Breakdown](#jobs-breakdown)
- [Data Persistency](#data-persistency)

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

### Configure GitHub Settings (One-Time Setup)
Directly from the GitHub UI perform following steps:

#### A. Set Workflow Permissions
Define explicit write permissions for the workflow to publish images to GitHub Container Registry (GHCR):
1. In your GitHub repository go to **Settings --> Actions --> General**.
2. Scroll down to **Workflow permissions**.
3. Select **Read and write permissions**.
4. Click **Save**.

#### B. Add Repository Secrets
Navigate to **Settings --> Secrets and variables --> Actions** and add following Repository secrets:
- `VM_HOST`: Target VM IP address
- `VM_USER`: SSH username on the VM
- `VM_SSH_KEY`: Private SSH Key matching the `~/.ssh/authorized_keys` entry on the VM
- `ENV_FILE`: Content of the production `.env` 

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

### Trigger the Deployment
You can trigger the pipeline using following options:

### Option A: Automatic Trigger (Git Push)  
Commit and push changes directly to the feature branch:
```bash
git add .
git commit -m "feat: update pipeline config"
git push origin feature/ci-cd
```

### Option B: Manual Trigger (GitHub UI)  
1. Navigate to your repository on GitHub.
2. Click the **Actions** tab.
3. Select **CI-CD Pipeline** from the left sidebar.
4. Click **Run workflow**.

---

### Verify Production Status
Once the workflow completes successfully, reach your live application at:  
- http://<your_ip>:8282

---

## Usage
This section expands the original by adding useful information and tips for interacting with this pipeline branch:

### .env file and Secret Management
Sensitive data in never hardcoded and/or committed to source control.  
During deployment, the pipeline constructs the `.env` file dynamically:
- Secret credentials (`SECRET_KEY`, database passwords) are supplied through GitHub Secrets.
- Dynamic runtime parameters (`ALLOWED_HOSTS`, `GITHUB_REPOSITORY`) are injected based on the deployment target context.
- Strict file permission management prevents unauthorized local access on the runner.

> [!NOTE]  
> The variable `${{ secrets.GITHUB_TOKEN }}` is automatically supplied from GitHub during runtime for GHCR authentication.  
> The variable `ALLOWED_HOSTS` is omitted from the template by design. It is dynamically injected during workflow execution alongside the production server address defined in GitHub Secrets.

---

### Error Handling
Execution control is enforced at four distinct levels:
1. **Step Level** (Default behaviour): If any individual step fails, the execution of that job stops immediately.
2. **Matrix Level** (`fail-fast: true`): Due explicit rule, if either the backend or frontend build fails, GitHub Actions immediately cancels the parallel runner to prevent wasteful resource usage.
3. **Job Level** (`needs: build`): **Job 2** explicitly dependends on **Job 1**. If any build task fails, deployment is aborted entirely, preventing a broken build from being deployed to your remote VM.
4. **Deployment Healthcheck & Auto-Rollback**: If container startup crashes or healthchecks fail on the VM, the script instantly redeploys the recorded `$WORKING_TAG` images, restoring application availability within seconds.

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
       │        ├── Conduit Backend ──► Dual-Tag (SHA + latest) ──► GHCR
       │        └── Conduit Frontend  ──► Dual-Tag (SHA + latest) ──► GHCR
       │
       └──► [ Job 2: Remote VM Deployment (SSH) and Automated Rollback ]
                ├── SCP docker-compose.yml to VM
                ├── Inspect and save current running tags for potential rollback (WORKING_TAG)
                ├── Inject .env + ALLOWED_HOSTS + GITHUB_REPOSITORY
                ├── Authenticate Docker with GHCR
                └── Pull & execute deployment using explicit commit SHA
                      │
                      ├──► [ SUCCESS: Healthchecks Healthy ] ──► Complete Workflow
                      │
                      └──► [ FAILURE: Startup Error ] ───────► Execute Immediate Rollback
                                                               ├── Redeploy WORKING_TAG
                                                               └── Exit 1 (Fail Job)
```

--- 

### Jobs Breakdown
#### Job 1: Build and Push (Parallel Matrix)
To optimize the process, **Job 1** uses a `strategy.matrix` to dispatch concurrent runners for the backend and the frontend. Both build their respective Docker images and push them to GitHub Container Registry (GHCR) indipendently.

The two highlights of this Job are:
- **Name Sanitazion**: Repository paths are automatically converted to lowercase (`REPO_LOWER=${GITHUB_REPOSITORY@L}`) to avoid potential Docker building errors caused by uppercase letters.
- **Dual Tagging**: Every image is built once and pushed with two distinct tags:
    - `ghcr.io/${{ env.REPO_LOWER }}/conduit-${{ matrix.name }}:latest` – Tracks the absolute newest build.
    - `ghcr.io/${{ env.REPO_LOWER }}/conduit-${{ matrix.name }}:${{ github.sha }}` – Provides a precise historical tag required for exact deployment and rollback operations.


#### Job 2: Remote VM Deployment (SSH) and Automated Rollback 
To keep deployment secure and automated, **Job 2** executes remotely via SSH:
- Copies `docker-compose.yml` to the VM workspace via SCP.
- Before making modifications, it inspects running containers to resolve and record the active image tag (`WORKING_TAG`).
- Generates the runtime `.env` file using the `ENV_FILE` secret and locks the permits.
- Dynamically appends computed environment variables (`ALLOWED_HOSTS`, lowercased `GITHUB_REPOSITORY`).
- Logs into GHCR on the target machine and pulls the newly published image tags.
- Recreates and restarts services cleanly using `docker compose up -d --wait --remove-orphans`.

The two highlights of this Job are:
- **Health Validation**: The `--wait` flag forces Docker Compose to block execution until container healthchecks report a healthy state.
- **Automated Rollback**: If the deployment fails, due initialization failures or health checks time out:
    - The pipeline intercepts the non-zero exit status.
    - Instantly executes `IMAGE_TAG=$WORKING_TAG docker compose up -d --remove-orphans` to revert the environment back to its last known healthy commit image.
    - Terminates with `exit 1` to notify maintainers via GitHub Actions UI.

---

## Data Persistency 
Data persistency remains unchanged from the original Docker Setup. The database data is stored and managed in a **Docker volume** (`postgre_data`), ensuring that articles, users, and comments persist across restarts, container recreation, or updates.

---