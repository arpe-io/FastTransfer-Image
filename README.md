# FastTransfer Docker Image

Minimal, production-ready container image to run **[FastTransfer](https://www.arpe.io/fasttransfer)** (parallel data import/transfer CLI), a high-performance data transfer utility designed for data integration and automation workflows.

This setup targets **FastTransfer ≥ 0.14.0**, which supports passing the license **inline** via `--license "<content>"`.

## Image Overview

* **Base image:** `dhi.io/debian-base:trixie`
* **Entrypoint:** `/usr/local/bin/FastTransfer`
* **Repository:** [https://github.com/aetperf/FastTransfer-Image](https://github.com/aetperf/FastTransfer-Image)
* **DockerHub:** [aetp/fasttransfer](https://hub.docker.com/r/aetp/fasttransfer)
* **Published automatically** via GitHub Actions for each new release and weekly security updates

> **For custom builds**  
> The FastTransfer binary is **not** distributed in this repository. Request the **Linux x64** build here:  
> https://www.arpe.io/get-your-fasttransfer-trial/  
> Unzip and place it at the repository root (next to the `Dockerfile`), then build your own custom image.


## Table of contents

### Building Your Own Image
* [Prerequisites](#prerequisites)
* [Get the binary](#get-the-binary-for-build-only)
* [Build](#build)
* [Run FastTransfer](#run-fasttransfer)

### Using the Prebuilt Image from DockerHub
* [Prebuilt image on DockerHub](#prebuilt-image-on-dockerhub)
* [Usage](#usage)
* [Examples](#examples)

### Configuration & Advanced Usage
* [Volumes](#volumes)
* [Configuring FastTransfer Logging](#configuring-fasttransfer-logging-with-custom-settings)
* [Performance & networking](#performance--networking)
* [Security tips](#security-tips)

### Reference
* [Troubleshooting](#troubleshooting)
* [Notes](#notes)

---

## Prerequisites
- Docker 24+ (or Podman)
- **FastTransfer Linux x64 ≥ 0.14.0** binary (for build only)
- Optional: `FastTransfer_Settings.json` to mount/copy into `/config` for custom logging settings

## Get the binary (for build only)
1. Request a trial: https://www.arpe.io/get-your-fasttransfer-trial/
2. Rename the downloaded file to `FastTransfer` and ensure it is executable if testing locally:
   ```bash
   chmod +x FastTransfer
   ```
3. Place it at the **repository root** (beside `Dockerfile`).

## Build
```bash
docker build -t fasttransfer:latest .
docker run --rm fasttransfer:latest --version
```

## Run FastTransfer
This container has `ENTRYPOINT` set to the `FastTransfer` binary. Any arguments you pass to `docker run` are forwarded to FastTransfer.
```bash
docker run --rm fasttransfer:latest --help
```

## Prebuilt image on DockerHub

You can use a prebuilt image from DockerHub that already includes the FastTransfer binary. You must provide your own license at runtime.

**DockerHub repository:** [aetp/fasttransfer](https://hub.docker.com/r/aetp/fasttransfer)

### Available tags
- **Version-specific tags** are aligned with FastTransfer releases (e.g., `v0.28.8`)
- **`latest`** tag always points to the most recent FastTransfer version

### Automatic updates
- **New releases:** Images are automatically built when new FastTransfer versions are released
- **Security updates:** The **latest version of each minor branch** (e.g., latest v0.27.x, v0.28.x, v0.29.x) is automatically rebuilt weekly (every Monday) with the latest base image and security patches
  - This ensures that all actively used versions remain secure without breaking compatibility
  - Example: If you use `v0.28.9` (latest of 0.28.x branch), it gets security updates even after `v0.29.0` is released

### Pull the image

```bash
# Latest version
docker pull aetp/fasttransfer:latest

# Specific version
docker pull aetp/fasttransfer:v0.28.8
```

### Run FastTransfer directly

```bash
# Get help
docker run --rm aetp/fasttransfer:latest --help

# Check version
docker run --rm aetp/fasttransfer:latest --version
```

# Usage

The Docker image uses the FastTransfer binary as its entrypoint, so you can run it directly with parameters as defined in the FastTransfer documentation.

### Basic commands

```bash
# Get command line help
docker run --rm aetp/fasttransfer:latest --help

# Check version
docker run --rm aetp/fasttransfer:latest --version
```

### License requirement

Since version 0.14.0, pass the **license content directly** via `--license "…"`.

```bash
export licenseContent=$(cat ./FastTransfer.lic)

# Use $licenseContent in your docker run commands
docker run --rm aetp/fasttransfer:latest \
  --license "$licenseContent" \
  [other parameters...]
```

**Best practice:** Prefer `--env-file`, Docker/Compose/Kubernetes secrets, or managed identities for cloud credentials. Avoid leaving the license content in shell history.

## Examples

> The exact parameters depend on your source and target settings. The snippets below illustrate the call pattern from Docker in a **Linux shell**.

### 1) SQL Server → SQL Server (parallel DB-to-DB transfer)

```bash
export licenseContent=$(cat ./FastTransfer.lic)

docker run --rm \
aetp/fasttransfer:latest \
--sourceconnectiontype "mssql" \
--sourceserver "host.docker.internal,1433" \
--sourceuser "SrcUser" \
--sourcepassword "SrcPass" \
--sourcedatabase "source_db" \
--targetconnectiontype "msbulk" \
--targetserver "host.docker.internal,1433" \
--targetuser "DestUser" \
--targetpassword "DestPass" \
--targetdatabase "dest_db" \
--method "Ntile" \
--distributekeycolumn "id" \
--loadmode "Truncate" \
--paralleldegree 8 \
--license "$licenseContent"
```

### 2) Import CSV files to PostgreSQL in parallel

```bash
export licenseContent=$(cat ./FastTransfer.lic)

docker run --rm \
-v /local/data:/data \
aetp/fasttransfer:latest \
--sourceconnectiontype "file" \
--fileinput "/data/files/*.csv" \
--targetconnectiontype "pgcopy" \
--targetserver "host.docker.internal:5432" \
--targetuser "PgUser" \
--targetpassword "PgPass" \
--targetdatabase "pg_db" \
--targetschema "public" \
--targettable "imported_table" \
--loadmode "Truncate" \
--paralleldegree -2 \
--license "$licenseContent"
```

### 3) Export SQL Server → Parquet on AWS S3

```bash
export licenseContent=$(cat ./FastTransfer.lic)

docker run --rm \
-e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
-e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
-e AWS_REGION=${AWS_REGION} \
aetp/fasttransfer:latest \
--sourceconnectiontype "mssql" \
--sourceserver "host.docker.internal,1433" \
--sourceuser "SrcUser" \
--sourcepassword "SrcPass" \
--sourcedatabase "source_db" \
--query "SELECT * FROM dbo.orders WHERE year(o_orderdate)=2024" \
--fileoutput "orders.parquet" \
--directory "s3://my-bucket/data/" \
--paralleldegree 12 \
--parallelmethod "Ntile" \
--distributekeycolumn "o_orderkey" \
--merge false \
--license "$licenseContent"
```

### 4) Export PostgreSQL → Parquet on Azure Data Lake Storage (ADLS)

```bash
export licenseContent=$(cat ./FastTransfer.lic)
export adlscontainer="my-adls-container"

docker run --rm \
-e AZURE_CLIENT_ID=${AZURE_CLIENT_ID} \
-e AZURE_TENANT_ID=${AZURE_TENANT_ID} \
-e AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET} \
aetp/fasttransfer:latest \
--sourceconnectiontype "pgcopy" \
--sourceserver "host.docker.internal:5432" \
--sourceuser "PgUser" \
--sourcepassword "PgPass" \
--sourcedatabase "pg_db" \
--sourceschema "public" \
--sourcetable "orders" \
--query "SELECT * FROM public.orders WHERE order_date >= '2024-01-01'" \
--fileoutput "orders.parquet" \
--directory "abfss://${adlscontainer}.dfs.core.windows.net/data/orders" \
--paralleldegree -2 \
--parallelmethod "Ctid" \
--license "$licenseContent"
```

### 5) Export Oracle → Parquet on Google Cloud Storage (GCS)

```bash
export licenseContent=$(cat ./FastTransfer.lic)
export gcsbucket="my-gcs-bucket"
export GOOGLE_APPLICATION_CREDENTIALS_JSON=$(cat ./gcp-credentials.json)

docker run --rm \
-e GOOGLE_APPLICATION_CREDENTIALS="${GOOGLE_APPLICATION_CREDENTIALS_JSON}" \
aetp/fasttransfer:latest \
--sourceconnectiontype "oraodp" \
--sourceserver "host.docker.internal:1521/FREEPDB1" \
--sourceuser "SCHEMA_USER" \
--sourcepassword "SCHEMA_PASS" \
--database "FREEPDB1" \
--sourceschema "SCHEMA_USER" \
--sourcetable "ORDERS" \
--fileoutput "orders.parquet" \
--directory "gs://${gcsbucket}/data/orders" \
--parallelmethod "Rowid" \
--paralleldegree -2 \
--license "$licenseContent"
```

## Volumes

The Docker image declares several volumes to organize data and configuration:

```dockerfile
VOLUME ["/config", "/data", "/work", "/logs"]
```

### Volume configuration and access modes

| Volume Path | Description                                                         | Access Mode               | Typical Usage                                   |
| ----------- | ------------------------------------------------------------------- | ------------------------- | ----------------------------------------------- |
| `/config`   | Contains user-provided configuration files (e.g., Serilog settings) | **Read-only / Read-many** | Shared across multiple containers; not modified |
| `/data`     | Input/output data directory for file-based operations               | **Read-many/Write-many**  | Stores imported or exported data files          |
| `/work`     | Temporary working directory (container `WORKDIR`)                   | **Read-many/Write-many**  | Used internally for temporary processing        |
| `/logs`     | Log output directory (per-run or aggregated logs)                   | **Read-many/Write-many**  | Stores runtime and execution logs               |

## Configuring FastTransfer Logging with Custom Settings

*Available starting from version **0.14.0***

FastTransfer supports **custom logging configuration** through an external Serilog settings file in JSON format.
This allows you to control **how and where logs are written** — to the console, to files, or dynamically per run.

Custom settings files must be **mounted into the container** under the `/config` directory.

---

### Example: Logging to Console, Airflow, and Dynamic Log Files

The following configuration is recommended for most production or Airflow environments.
It writes:

* Logs to the console for real-time visibility
* Run summary logs to `/airflow/xcom/return.json` for Airflow integration
* Per-run logs under `/logs`, automatically named with `{LogTimestamp}` and `{TraceId}`

```json
{
  "Serilog": {
    "Using": [
      "Serilog.Sinks.Console",
      "Serilog.Sinks.File",
      "Serilog.Enrichers.Environment",
      "Serilog.Enrichers.Thread",
      "Serilog.Enrichers.Process",
      "Serilog.Enrichers.Context",
      "Serilog.Formatting.Compact"
    ],
    "WriteTo": [
      {
        "Name": "Console",
        "Args": {
          "outputTemplate": "{Timestamp:yyyy-MM-ddTHH:mm:ss.fff zzz} -|- {Application} -|- {runid} -|- {Level:u12} -|- {fulltargetname} -|- {Message}{NewLine}{Exception}",
          "theme": "Serilog.Sinks.SystemConsole.Themes.ConsoleTheme::None, Serilog.Sinks.Console",
          "applyThemeToRedirectedOutput": false
        }
      },
      {
        "Name": "File",
        "Args": {
          "path": "/airflow/xcom/return.json",
          "formatter": "Serilog.Formatting.Compact.CompactJsonFormatter, Serilog.Formatting.Compact"
        }
      },
      {
        "Name": "Map",
        "Args": {
          "to": [
            {
              "Name": "File",
              "Args": {
                "path": "/logs/{logdate}/{sourcedatabase}/log-{filename}-{LogTimestamp}-{TraceId}.json",
                "formatter": "Serilog.Formatting.Compact.CompactJsonFormatter, Serilog.Formatting.Compact",
                "rollingInterval": "Infinite",
                "shared": false,
                "encoding": "utf-8"
              }
            }
          ]
        }
      }
    ],
    "Enrich": [
      "FromLogContext",
      "WithMachineName",
      "WithProcessId",
      "WithThreadId"
    ],
    "Properties": {
      "Application": "FastTransfer"
    }
  }
}
```

Important notes:

* If a target directory (such as `/logs` or `/airflow/xcom`) does not exist, FastTransfer automatically creates it.
* The file `/airflow/xcom/return.json` is designed to provide run summaries compatible with Airflow's XCom mechanism.

---

### Available Tokens for Path or Filename Formatting

You can use the following placeholders to dynamically generate log file names or directories:

| Token Name         | Description                                  |
| ------------------ | -------------------------------------------- |
| `{logdate}`        | Current date in `yyyy-MM-dd` format          |
| `{logtimestamp}`   | Full timestamp of the log entry              |
| `{sourcedatabase}` | Name of the source database                  |
| `{sourceschema}`   | Name of the source schema                    |
| `{sourcetable}`    | Name of the source table                     |
| `{filename}`       | Name of the file being processed             |
| `{runid}`          | Run identifier provided in the command line  |
| `{traceid}`        | Unique trace identifier generated at runtime |

---

### Mounting a Custom Settings File

Your Serilog configuration file (for example, `FastTransfer_Settings.json`) must be placed in `/config`,
either by mounting a local directory or by using a Docker named volume.

Example with named volumes:

```bash
# First, copy your config file to a volume location
cp ~/FastTransfer_Settings.json /volumes/fasttransfer-config/

# Then run FastTransfer with mounted volumes
docker run --rm \
-v fasttransfer-config:/config \
-v fasttransfer-data:/data \
-v fasttransfer-logs:/logs \
aetp/fasttransfer:latest \
--settingsfile "/config/FastTransfer_Settings.json" \
--sourceconnectiontype "mssql" \
--sourceserver "host.docker.internal,1433" \
--sourceuser "SrcUser" \
--sourcepassword "SrcPass" \
--sourcedatabase "source_db" \
--targetconnectiontype "pgcopy" \
--targetserver "host.docker.internal:5432" \
--targetuser "PgUser" \
--targetpassword "PgPass" \
--targetdatabase "pg_db" \
--query "SELECT * FROM dbo.orders" \
--fileoutput "orders.parquet" \
--directory "/data" \
--paralleldegree 12 \
--parallelmethod "Ntile" \
--distributekeycolumn "o_orderkey" \
--merge false \
--license "$licenseContent"
```

If the `--settingsfile` argument is not provided, FastTransfer will use its built-in default logging configuration.

---

## Performance & networking
- Place `/data` on fast storage (NVMe) when exporting/importing large datasets locally.
- Tune `--paralleldegree` according to CPU cores and I/O throughput of source/target systems.
- To reach a DB on the local host from Linux, add `--add-host=host.docker.internal:host-gateway` (or the `extra_hosts` entry in Compose).
- For high-bandwidth object-store targets (S3/ADLS/GCS), ensure consistent MTU settings end-to-end; consider jumbo frames where appropriate and if possible a dedicated endpoint.

## Security tips
- Never commit your license or cloud credentials to source control.
- Prefer Docker/Compose/Kubernetes **secrets** or environment files (`--env-file`) and managed identities (IAM Role / IRSA / Workload Identity / Managed Identity).
- FastTransfer will try classic methods to authenticate to cloud object stores (default profile, IAM Role, Env) if no explicit credentials are provided.
- FastTransfer supports secure logging and obfuscated credentials, but you should still restrict log access and audit credentials.

## Troubleshooting
- **Exec format error** → ensure the binary is Linux x64 and executable (`chmod +x FastTransfer`).
- **Missing `libicu`/`libssl`/`zlib`/`krb5`** → the image includes `libicu76`, `libssl3`, `zlib1g`, `libkrb5-3`. If your build requires additional libs, add them via `apt`.
- **Permission denied** writing under `/data` or `/logs` → ensure the host directory permissions match the container UID (`10001`).
- **DB host not reachable** → on Linux, use `--add-host=host.docker.internal:host-gateway` or the Compose `extra_hosts` equivalent.
- **License error / invalid license** → verify you passed correct license content via `--license`, or that your trial license is valid and the binary version matches.

## Notes
- This image **embeds the proprietary FastTransfer binary** in DockerHub prebuilt images. You must provide a valid license (or request a trial license) for the tool to work. **Do not share your private license outside your organization.**
- OCI labels are set for traceability (source, vendor, license) in the Dockerfile.
- **Security maintenance:** The latest version of each minor branch (e.g., v0.27.x, v0.28.x, v0.29.x) is automatically rebuilt weekly with security patches, ensuring long-term security without forcing upgrades to newer minor versions.
- FastTransfer supports many source and target database types (e.g., MySQL, PostgreSQL, SQL Server, Oracle, DuckDB, ClickHouse) and both file-based and DB-to-DB transfers.
- For questions or support, visit the [FastTransfer documentation](https://www.arpe.io/fasttransfer) or contact [ARPE.IO](https://www.arpe.io/).
