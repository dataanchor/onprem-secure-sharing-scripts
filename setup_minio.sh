Below is a **README.md** file tailored for the [onprem-secure-sharing-scripts](https://github.com/dataanchor/onprem-secure-sharing-scripts) repository. It explains how to **directly download** the two scripts—**`setup_minio.sh`** and **`setup_onprem.sh`**—using `curl`, outlines prerequisites, and provides usage details for each script.

---

```markdown
# Fenixpyre On-Prem Secure Sharing Scripts

This repository contains two Bash scripts to automate the setup of **MinIO** and the **On-Prem Secure Sharing Service**:

1. **`setup_minio.sh`**  
   - Provisions a TLS-enabled MinIO instance via Docker Compose.    
   - Optionally obtains TLS certificates from Let's Encrypt or allows manual placement.

2. **`setup_onprem.sh`**  
   - Sets up the Fenixpyre On-Prem Secure Sharing Service (including mTLS certificates, optional public TLS, Docker Compose deployment).  
   - Performs initial health checks on both the public (TLS) and private (mTLS) APIs.

---

## Prerequisites

- **Linux environment** with Bash.
- **Docker** and **Docker Compose** installed.
- **curl** for downloading the scripts.
- **Certbot** (if you plan to automatically generate TLS certificates via Let’s Encrypt).

> **Firewall:**  
> Ensure the server’s ports 80/443 are open for certificate validation (if using Let's Encrypt). If you’re using internal CA-signed certs, you can place them manually.

---

## Installation

You can **directly download** each script using `curl`:

### 1. Download `setup_minio.sh`

```bash
curl -fsSL https://raw.githubusercontent.com/dataanchor/onprem-secure-sharing-scripts/main/setup_minio.sh -o setup_minio.sh
chmod +x setup_minio.sh
```

### 2. Download `setup_onprem.sh`

```bash
curl -fsSL https://raw.githubusercontent.com/dataanchor/onprem-secure-sharing-scripts/main/setup_onprem.sh -o setup_onprem.sh
chmod +x setup_onprem.sh
```

---

## Usage

### Setting Up MinIO

1. **Run the Script:**

   ```bash
   ./setup_minio.sh
   ```
   
2. **Follow Prompts:**
   - **Domain Name**: e.g., `minio.example.com`.
   - **MinIO Root User** and **Password**.
   - **TLS Certificate**: Choose between auto-generation with Let’s Encrypt or manual placement.
   
3. **Docker Compose Deployment:**
   - The script creates a `docker-compose.yaml` in `~/minio/`.
   - **MinIO** starts on **port 443** (internally mapped from container port `9000`).

4. **Health Check**:
   - The script verifies the endpoint at `https://<MINIO_DOMAIN>/minio/health/ready` to ensure MinIO is up and running.

> **Result**: MinIO is available at `https://<MINIO_DOMAIN>` with TLS.

---

### Setting Up the On-Prem Secure Sharing Service

1. **Run the Script:**

   ```bash
   ./setup_onprem.sh
   ```

2. **Place mTLS Certificates**:  
   - The script prompts you to put your mTLS (private API) certificates (`server.crt`, `server.key`, `ca.crt`) in `~/onpremsharing/certs/mtls/`.

3. **Obtain or Place TLS Certificate** (for the public API):
   - Similar to the MinIO script, you can opt for a Let’s Encrypt certificate or place your own in `~/onpremsharing/certs/ssl/`.

4. **Configuration Details**:
   - The script collects **PostgreSQL** and **MinIO** credentials, tokens/secrets, etc.
   - Generates `config.yaml` and a Docker Compose file in `~/onpremsharing/`.

5. **Docker Compose Deployment**:
   - Launches containers (PostgreSQL + On-Prem Secure Sharing) with `docker-compose up -d`.
   - **Public API** on port **443**, **private API** on port **8080** (mTLS).

6. **Health Checks**:
   - **Public** (TLS) endpoint: `https://<ONPREM_DOMAIN>/health`  
   - **Private** (mTLS) endpoint: tested on `https://<VM_PUBLIC_IP>:8080/health` using the server’s own certificates.

---

## Scripts Overview

### `setup_minio.sh`
- **Creates directories**: `~/minio/certs/minio/`, etc.
- **Prompts for**: domain, MinIO credentials, TLS certificate approach.
- **Generates** `docker-compose.yaml` under `~/minio/`.
- **Starts** MinIO container with TLS on port 443.
- **Verifies** readiness (`curl -k https://<MINIO_DOMAIN>/minio/health/ready`).

### `setup_onprem.sh`
- **Prompts for**: domain, mTLS certs, optional public TLS cert, Postgres + MinIO info, tokens.
- **Writes** `config.yaml` and `docker-compose.yaml` under `~/onpremsharing/`.
- **Starts** containers (`postgres`, `onprem`) using Docker Compose.
- **Checks** public API (`/health`) and private API (mTLS on port 8080).

---

## Known Issues and Troubleshooting

1. **Port Conflicts**:  
   If ports 80/443 are blocked by another service, Let’s Encrypt certificate generation may fail.
   
2. **DNS Resolution**:  
   Ensure your domain’s DNS correctly points to the VM’s public IP.

3. **Permission Errors**:  
   Use `sudo` if lacking permissions for writing to `/etc/letsencrypt` or installing packages.

4. **Docker Compose Not Found**:  
   Make sure you have installed Docker Compose on both VMs (for MinIO and On-Prem Service).

---
