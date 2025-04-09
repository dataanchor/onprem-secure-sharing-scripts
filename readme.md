Below is a **README.md** file tailored for the [onprem-secure-sharing-scripts](https://github.com/dataanchor/onprem-secure-sharing-scripts) repository. It explains how to **directly download** the two scripts—**`setup_minio.sh`** and **`setup_onprem.sh`**—using `curl`, outlines prerequisites, and provides usage details for each script.

---

```markdown
# 🚀 Fenixpyre On-Prem Secure Sharing Scripts

This repository contains two Bash scripts to automate the setup of **MinIO** and the **Fenixpyre On-Prem Secure Sharing Service**:

1. **`setup_minio.sh`**  
   - Provisions a TLS-enabled MinIO instance via Docker Compose.  
   - Optionally obtains TLS certificates from Let's Encrypt or allows manual placement.

2. **`setup_onprem.sh`**  
   - Sets up the Fenixpyre On-Prem Secure Sharing Service (including mTLS certificates, optional public TLS, Docker Compose deployment).  
   - Performs initial health checks on both the public (TLS) and private (mTLS) APIs.

---

## 📋 Prerequisites

- **Linux environment** with Bash.
- **Docker** and **Docker Compose** installed.
- **curl** for downloading the scripts.
- **Certbot** (if you plan to automatically generate TLS certificates via Let's Encrypt).

> **⚠️ Firewall:**  
> Ensure the server's ports 80/443 are open for certificate validation (if using Let's Encrypt). If you're using internal CA-signed certs, you can place them manually.

---

## 📥 Installation

You can **directly download** each script using `curl`:

### 1. Download `setup_minio.sh`

```bash
curl -fsSL https://raw.githubusercontent.com/dataanchor/onprem-secure-sharing-scripts/scripts/setup_minio.sh -o setup_minio.sh
chmod +x setup_minio.sh
```

### 2. Download `setup_onprem.sh`

```bash
curl -fsSL https://raw.githubusercontent.com/dataanchor/onprem-secure-sharing-scripts/scripts/setup_onprem.sh -o setup_onprem.sh
chmod +x setup_onprem.sh
```

---

## 🛠️ Usage

### Setting Up MinIO

1. **Run the Script:**

   ```bash
   sudo ./setup_minio.sh
   ```
   
   The script presents a menu with the following options:
   - **1) Setup MinIO**: Full setup process
   - **2) Setup Certificate Renewal**: Configure certificate renewal for an existing MinIO instance
   - **3) Exit**: Exit the script
   
2. **Follow Prompts:**
   - **Domain Name**: e.g., `minio.onpremsharing.example.com` (default)
   - **MinIO Root User** and **Password**.
   - **TLS Certificate**: Choose between auto-generation with Let's Encrypt or manual placement.
   
3. **Docker Compose Deployment:**
   - The script creates a `docker-compose.yaml` in `./minio/` (relative to the script location).
   - **MinIO** starts on **port 443** (internally mapped from container port `9000`).

4. **Health Check**:
   - The script verifies the endpoint at `https://<MINIO_DOMAIN>/minio/health/ready` to ensure MinIO is up and running.

> **✅ Result**: MinIO is available at `https://<MINIO_DOMAIN>` with TLS.

#### Certificate Renewal for MinIO

If you choose Let's Encrypt for certificates, the script automatically configures renewal:

- A daily cron job runs certbot with the `--quiet` option (minimizes output, showing only errors)
- A custom deploy hook runs after successful renewal to:
  - Copy new certificates to MinIO
  - Restart the MinIO container
  - Log the renewal event to `./minio/certificate-renewal.log`

To manually force certificate renewal for testing:

```bash
sudo certbot renew --cert-name your-minio-domain.com --deploy-hook /path/to/minio/scripts/cert-deploy-hook.sh --force-renewal --verbose
```

---

### Setting Up the Fenixpyre On-Prem Secure Sharing Service

1. **Run the Script:**

   ```bash
   sudo ./setup_onprem.sh
   ```

   The script presents a menu with the following options:
   - **1) Full Setup**: Complete installation and configuration
   - **2) Verify Deployment**: Check health of public and private APIs
   - **3) Extract Credentials**: Display stored credentials
   - **4) Create Credentials File**: Generate a new credentials file
   - **5) Setup Certificate Renewal**: Configure certificate renewal for an existing deployment

2. **Place mTLS Certificates**:  
   - The script prompts you to put your mTLS (private API) certificates (`server.crt`, `server.key`, `ca.crt`) in `./onpremsharing/certs/mtls/`.

3. **Obtain or Place TLS Certificate** (for the public API):
   - Similar to the MinIO script, you can opt for a Let's Encrypt certificate or place your own in `./onpremsharing/certs/ssl/`.

4. **Configuration Details**:
   - The script collects **PostgreSQL** and **MinIO** credentials
   - **HMAC Secret** and **Sharing Service Token** are automatically generated using secure random values
   - Generates `config.yaml` and a Docker Compose file in `./onpremsharing/`.

5. **Docker Compose Deployment**:
   - Launches containers (PostgreSQL + Fenixpyre On-Prem Secure Sharing) with `docker-compose up -d`.
   - **Public API** on port **443**, **private API** on port **8080** (mTLS).

6. **Health Checks**:
   - **Public** (TLS) endpoint: `https://<ONPREM_DOMAIN>/health`  
   - **Private** (mTLS) endpoint: tested on `https://<VM_PUBLIC_IP>:8080/health` using the server's own certificates.

#### Certificate Renewal for OnPrem Service

If you choose Let's Encrypt for certificates, the script sets up automatic renewal:

- A daily cron job runs at 3:00 AM to check and renew certificates if needed
- A deploy hook handles certificate updates and container restart
- Renewal events are logged to `./onpremsharing/certificate-renewal.log`

To manually force certificate renewal for testing:

```bash
sudo certbot renew --cert-name your-onprem-domain.com --deploy-hook /path/to/onpremsharing/scripts/cert-deploy-hook.sh --force-renewal --verbose
```

---

## 📝 Scripts Overview

### `setup_minio.sh`
1. **Domain Prompt**: `minio.onpremsharing.example.com` (default)
2. **MinIO Credentials**: Root user/password
3. **TLS**: Let's Encrypt (auto) or manual
4. **Docker Compose**: Creates docker-compose.yaml in `./minio/`, starts MinIO on port 443
5. **Health Check**: Script verifies readiness at `https://<MINIO_DOMAIN>/minio/health/ready`
6. **Certificate Renewal**: Configures automated Let's Encrypt certificate renewal with `--quiet` flag

### `setup_onprem.sh`
1. **Domain Prompt**: `onpremsharing.example.com` (default)
2. **mTLS Certificates**: Place server.crt, server.key, ca.crt in `./onpremsharing/certs/mtls/`
3. **TLS**: Let's Encrypt (auto) or manual
4. **MinIO Configuration**: Endpoint, access key, secret key, bucket name
5. **Security Tokens**: Automatically generates HMAC secret and sharing service token
6. **Docker Compose**: Creates docker-compose.yaml in `./onpremsharing/`, starts services
7. **Health Checks**: Verifies both public API (TLS) and private API (mTLS)
8. **Certificate Renewal**: Configures automated Let's Encrypt certificate renewal with `--quiet` flag

---

## 🔄 Certificate Renewal Process

Both scripts set up automatic certificate renewal if Let's Encrypt is used:

1. **Cron Job**: Runs certbot daily to check certificate expiration
2. **Deploy Hook**: After successful renewal, certificates are:
   - Copied to the appropriate service location
   - Service containers are restarted to load new certificates
   - Events are logged for auditing
3. **Logs**: All renewal activities are recorded in:
   - `./minio/certificate-renewal.log` for MinIO
   - `./onpremsharing/certificate-renewal.log` for OnPrem Service

**Notes about certificate renewal:**
- Both scripts use the `--quiet` flag in production to minimize output and only show errors
- For manual testing, use `--verbose` to see detailed renewal information
- The deploy hook only takes action when certificates for the specific domain are renewed

---

## ⚠️ Known Issues and Troubleshooting

1. **Port Conflicts**:  
   If ports 80/443 are blocked by another service, Let's Encrypt certificate generation may fail.
   
2. **DNS Resolution**:  
   Ensure your domain's DNS correctly points to the VM's public IP.

3. **Permission Errors**:  
   Use `sudo` if lacking permissions for writing to `/etc/letsencrypt` or installing packages.

4. **Docker Compose Not Found**:  
   Make sure you have installed Docker Compose on both VMs (for MinIO and On-Prem Service).

5. **Certificate Renewal Failures**:  
   If the automatic renewal process fails, check `/var/log/letsencrypt/letsencrypt.log` and the service-specific logs for details.

---

## ❓ Frequently Asked Questions

### Certificate Management

**Q: How can I forcefully renew the certificates?**  
A: You can force certificate renewal using the following commands:

For MinIO:
```bash
sudo certbot renew --cert-name your-minio-domain.com --deploy-hook /path/to/minio/scripts/cert-deploy-hook.sh --force-renewal --verbose
```

For OnPrem Service:
```bash
sudo certbot renew --cert-name your-onprem-domain.com --deploy-hook /path/to/onpremsharing/scripts/cert-deploy-hook.sh --force-renewal --verbose
```

The `--force-renewal` flag forces renewal regardless of expiration date, and `--verbose` provides detailed output for troubleshooting.

**Q: How do I check when my certificates will expire?**  
A: You can check certificate expiration dates with:
```bash
sudo certbot certificates
```
This will list all certificates managed by certbot, including their expiration dates.

**Q: Can I use my own certificates instead of Let's Encrypt?**  
A: Yes, both scripts support manual certificate placement. When prompted for TLS options, select the manual option and place your certificates in the appropriate directories:
- For MinIO: `./minio/certs/minio/private.key` and `./minio/certs/minio/public.crt`
- For OnPrem Service: `./onpremsharing/certs/ssl/server.key` and `./onpremsharing/certs/ssl/server.crt`

### Service Management

**Q: How do I restart the services after making configuration changes?**  
A: Navigate to the service directory and use Docker Compose:
```bash
# For MinIO
cd ./minio
sudo docker compose restart

# For OnPrem Service
cd ./onpremsharing
sudo docker compose restart
```

**Q: How can I view the logs for the services?**  
A: Use Docker Compose logs command:
```bash
# For MinIO
cd ./minio
sudo docker compose logs -f

# For OnPrem Service
cd ./onpremsharing
sudo docker compose logs -f
```

**Q: Where are the application logs stored?**  
A: Application logs are stored in the following locations:
- **OnPrem Service**: `./onpremsharing/logs/` directory
- **MinIO**: Logs are available through Docker Compose logs command
- **PostgreSQL**: Logs are available through Docker Compose logs command

You can also access these logs directly from the container:
```bash
# For OnPrem Service logs
sudo docker exec onprem cat /app/logs/app.log

# For MinIO logs
sudo docker exec minio cat /var/log/minio/minio.log
```

**Q: Where can I find the certificate renewal logs?**  
A: Certificate renewal logs are stored in multiple locations:
- **Service-specific logs**: 
  - MinIO: `./minio/certificate-renewal.log`
  - OnPrem Service: `./onpremsharing/certificate-renewal.log`
- **Certbot logs**: `/var/log/letsencrypt/letsencrypt.log`
- **Cron job logs**: Check system logs with `grep CRON /var/log/syslog`

### Security and Credentials

**Q: Where are the HMAC secret and sharing service token stored?**  
A: These are stored in:
- The `config.yaml` file in the OnPrem service directory
- A separate `onprem_details.txt` file for easy reference

**Q: How can I change the MinIO credentials after initial setup?**  
A: You can update the credentials in the `docker-compose.yaml` file and restart the service:
```bash
cd ./minio
# Edit docker-compose.yaml to update MINIO_ROOT_USER and MINIO_ROOT_PASSWORD
sudo docker compose down
sudo docker compose up -d
```

**Q: How do I backup my configuration and data?**  
A: For MinIO, backup the `./minio/data` directory. For OnPrem Service, backup:
- `./onpremsharing/config.yaml`
- `./onpremsharing/certs` directory
- PostgreSQL data volume (requires Docker volume backup)

### Integration and Usage

**Q: Can I use the same MinIO instance for multiple OnPrem deployments?**  
A: Yes, you can use a single MinIO instance for multiple OnPrem deployments by creating separate buckets for each deployment.

**Q: How do I verify that my setup is working correctly?**  
A: Both scripts include health check functionality. You can also manually verify:
- MinIO: Visit `https://<MINIO_DOMAIN>/minio/health/ready`
- OnPrem Public API: Visit `https://<ONPREM_DOMAIN>/health`
- OnPrem Private API: Use curl with mTLS certificates to access `https://<VM_PUBLIC_IP>:8080/health`

---
