Below is a **README.md** that includes information for **both** the Fenixpyre On-Prem Secure Sharing Service setup script (`onprem_service.sh`) **and** the MinIO setup script (`setup_minio.sh`). This guide instructs users on installing both scripts via direct download using `curl`, outlines prerequisites, and explains how to run each script step-by-step.

---

```markdown
# Fenixpyre On-Prem Secure Sharing & MinIO Setup Scripts

A collection of Bash scripts to automate:
1. **MinIO Setup** – Creates a secure, TLS-enabled MinIO instance.  
2. **Fenixpyre On-Prem Secure Sharing Setup** – Installs, configures, and verifies the On-Prem Sharing Service.

## Overview

This repository provides two scripts:

1. **`setup_minio.sh`**  
   - Sets up MinIO with TLS (including optional Let's Encrypt certificate retrieval).  
   - Prompts for MinIO credentials (root user/password) and domain name.  
   - Generates a Docker Compose file to run MinIO in a container.

2. **`onprem_service.sh`** (menu-driven)  
   - **Full Setup** – Guides you through placing mTLS certificates, optionally generating a public TLS certificate, configuring Docker Compose, and performing health checks on both public (TLS) and private (mTLS) APIs.  
   - **Verify Deployment** – Checks public and private APIs’ health without re-running the entire setup.  
   - **Extract Credentials** – Displays credentials from `onprem_details.txt`.  
   - **Create Credentials File** – Uses `config.yaml` to rebuild `onprem_details.txt`.

## Prerequisites

- **Linux Environment** with Bash.  
- **Docker** and **Docker Compose** installed.  
- **curl** installed.  
- **Certbot** (optional, for generating TLS certificates automatically).  
- Appropriate firewall ports open (e.g., port 80/443 for Certbot validation, ports 443/8080 for the services).

---

## Installation

You can download each script **directly** via `curl`:

### 1) MinIO Setup Script

```bash
curl -fsSL https://raw.githubusercontent.com/<YOUR_ORG>/<YOUR_REPO>/<BRANCH>/setup_minio.sh -o setup_minio.sh
chmod +x setup_minio.sh
```

### 2) On-Prem Sharing Script

```bash
curl -fsSL https://raw.githubusercontent.com/<YOUR_ORG>/<YOUR_REPO>/<BRANCH>/onprem_service.sh -o onprem_service.sh
chmod +x onprem_service.sh
```

> Replace `<YOUR_ORG>`, `<YOUR_REPO>`, and `<BRANCH>` with the correct values for your GitHub organization, repository name, and branch.

---

## Usage

### 1) Setting Up MinIO

1. **Run the Script:**
   ```bash
   ./setup_minio.sh
   ```
2. **Enter Domain & Credentials:**
   - Prompts for the MinIO domain (e.g., `minio.onpremsharing.example.com`), the MinIO root user, and password.
3. **Certificate Handling:**
   - Optionally obtains a TLS certificate via Let’s Encrypt or prompts for manual certificate placement.
4. **Docker Compose Deployment:**
   - Creates a `docker-compose.yaml` for MinIO.
   - Launches MinIO in a container on port 443 (mapped from internal port 9000).
5. **Verification:**
   - The script checks the health endpoint (`/minio/health/ready`) to ensure MinIO is running securely under TLS.

Once complete, MinIO should be accessible at `https://<MINIO_DOMAIN>/` (e.g., `https://minio.onpremsharing.example.com/`).

### 2) Setting Up Fenixpyre On-Prem Secure Sharing

1. **Run the Script:**
   ```bash
   ./onprem_service.sh
   ```
2. **Select an Option** from the menu:

   1. **Full Setup**  
      - Guides you through placing mTLS certificates, optionally generating a TLS certificate, collecting credentials (database, MinIO, tokens), and deploying via Docker Compose.  
      - Performs health checks on the public API (`/health`) and private API (`/health` with mTLS).

   2. **Verify Deployment**  
      - Prompts for the On-Prem domain and VM public IP.  
      - Checks both the public API (TLS) and private API (mTLS) health endpoints.

   3. **Extract Credentials**  
      - Reads the existing `onprem_details.txt` (created during setup) and displays the stored values:  
        - Public URL  
        - Private URL  
        - Sharing Service Token  
        - HMAC Secret  

   4. **Create Credentials File**  
      - Parses `config.yaml` within the `onpremsharing` directory.  
      - Prompts for the VM’s public IP to construct the private URL.  
      - Rebuilds the `onprem_details.txt` file.

---

## MinIO & On-Prem Service Relationship

**MinIO** acts as secure object storage for the On-Prem Sharing Service. Ensure:

1. MinIO is installed and TLS-enabled (using `setup_minio.sh`).  
2. The `onprem_service.sh` script knows your MinIO endpoint, credentials, and domain (minio user, password, etc.).

During **On-Prem Setup**, you will be prompted for:  
- **MinIO endpoint** (e.g., `minio.onpremsharing.example.com`).  
- **Access Key** and **Secret Key**.  
- **Bucket name** for secure file storage.

---

## Certificates and TLS

- **mTLS Certificates** (server.crt, server.key, ca.crt) for the private API must be manually placed in the `onpremsharing/certs/mtls` directory.  
- **TLS Certificates** for the public API can be obtained automatically via Certbot or placed manually into `onpremsharing/certs/ssl/`.  
- **MinIO** uses its own TLS certificate placed in `~/minio/certs/minio/` (configured by `setup_minio.sh`).

---

## Credentials and Secrets

- **MinIO Root User and Password**: Required to manage the MinIO server.  
- **Database Credentials**: PostgreSQL username/password.  
- **Sharing Service Token and HMAC Secret**: Used for secure communication with the On-Prem Sharing Service.  
- **`onprem_details.txt`**: Stores final connection details (public URL, private URL, tokens).

Handle these values carefully and store them securely.

---

## Troubleshooting

1. **Port Conflicts**: Ensure ports 80/443 are not in use by other processes if Let’s Encrypt is used. MinIO also needs port 443 available.  
2. **Permission Issues**: If encountering permission errors, use `sudo` where necessary or confirm correct file ownership.  
3. **Certificate Errors**: Make sure DNS points to your server, and ports 80/443 are open if using Let’s Encrypt.  
4. **Docker Compose**: Ensure Docker Compose is installed and accessible.  
5. **Health Checks Fail**: Confirm the correct domain/IP, valid certificates, and that containers are running (`docker ps`).

---
