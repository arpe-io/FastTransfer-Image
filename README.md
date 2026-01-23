
# FastTransfer – Docker Image (Linux x64) – vX.Y.Z+

Minimal, production‑ready container image to run **FastTransfer** (high‑performance parallel data import/transfer CLI). This setup targets **FastTransfer ≥ X.Y.Z**, which supports passing the license **inline** via `--license "<content>"`.

> **Binary required for custom build**  
> The FastTransfer binary is **not** distributed in this repository. 
> Request the **Linux x64** build here : 
> [https://fasttransfer.arpe.io/start/](https://fasttransfer.arpe.io/start/)
> unzip and place it at the repository root (next to the `Dockerfile`), then build your own custom image.

## Table of contents

* [Prerequisites](#prerequisites)
* [Get the binary](#get-the-binary)
* [Build](#build)
* [Run FastTransfer](#run-fasttransfer)
* [License (inline support)](#license)
* [Prebuilt image on DockerHub](#prebuilt-image-on-dockerhub)
* [Usage](#usage)
* [Samples](#samples)
* [Volumes](#volumes)
* [Configuring FastTransfer Logging with Custom Settings](#configuring-fasttransfer-logging-with-custom-settings)
* [Performance & networking](#performance--networking)
* [Security tips](#security-tips)
* [Troubleshooting](#troubleshooting)
* [Notes](#notes)

---

## Prerequisites

* Docker 24+ (or Podman)
* **FastTransfer Linux x64 ≥ X.Y.Z** binary (for build only)
* Optional: `FastTransfer_Settings.json` to mount/copy into `/config` for custom logging settings

## Get the binary (for build only)

1. Request a trial: [https://fasttransfer.arpe.io/start/](https://fasttransfer.arpe.io/start/) ([Arpe][1])
2. Rename the downloaded file to `fasttransfer` and ensure it is executable if testing locally:

   ```bash
   chmod +x fasttransfer
   ```
3. Place it at the **repository root** (beside `Dockerfile`).

## Build

```bash
docker build -t fasttransfer:latest .
docker run --rm fasttransfer:latest --version
```

## Run FastTransfer

This container has `ENTRYPOINT` set to the `fasttransfer` binary. Any arguments you pass to `docker run` are forwarded to FastTransfer.

```bash
docker run --rm fasttransfer:latest --help
```

## License

Since version X.Y.Z, pass the **license content directly** via `--license "…"`.
(Ensure you have a valid license key or trial license issued by the vendor.)

## Prebuilt image on DockerHub

You can also use a prebuilt image on DockerHub that already includes the binary. You must provide your own license at runtime.

```bash
docker pull aetp/fasttransfer:latest
```

or specify a version tag:

```bash
docker pull aetp/fasttransfer:vX.Y.Z
```

## Samples

Here are a few example usage scenarios illustrating how to run FastTransfer inside the container.

* **Copy source DB → target DB using parallel mode**:

  ```bash
  export licenseContent=$(cat ./FastTransfer.lic)
  docker run --rm \
    aetp/fasttransfer:latest \
    --sourceconnectiontype "mssql" \
    --sourceserver "sourcehost,1433" \
    --sourceuser "SrcUser" \
    --sourcepassword "SrcPass" \
    --sourcedatabase "source_db" \
    --targetconnectiontype "msbulk" \
    --targetserver "desthost,1433" \
    --targetuser "DestUser" \
    --targetpassword "DestPass" \
    --targetdatabase "dest_db" \
    --method "Ntile" \
    --distributekeycolumn "id" \
    --loadmode "Truncate" \
    --paralleldegree 8 \
    --license "$licenseContent"
  ```

* **Import CSV files to PostgreSQL in parallel**:

  ```bash
  export licenseContent=$(cat ./FastTransfer.lic)
  docker run --rm \
    -v /local/data:/data \
    aetp/fasttransfer:latest \
    --sourceconnectiontype "file" \
    --fileinput "/data/files/*.csv" \
    --targetconnectiontype "pgcopy" \
    --targetserver "pghost:5432" \
    --targetuser "PgUser" \
    --targetpassword "PgPass" \
    --targetdatabase "pg_db" \
    --targetschema "public" \
    --targettable "imported_table" \
    --loadmode "Truncate" \
    --paralleldegree -2 \
    --license "$licenseContent"
  ```

**Good practice**: use `--env-file`, Docker/Compose/Kubernetes secrets or managed identities for credentials. Avoid leaving license content or passwords in shell history.

## Volumes

* `/work`   – working directory (container `WORKDIR`)
* `/config` – optional configuration directory (e.g., to store `FastTransfer_Settings.json` for custom logging)
* `/data`   – input directory for source files (CSV, Parquet, etc.) that you want to IMPORT into a target database
* `/logs`   – logs directory (ensure that logging config is set to write logs here)

> The `/data` volume is only used to provide input files for IMPORT operations. 

## Configuring FastTransfer Logging with Custom Settings

*Available starting from version X.Y.Z*
FastTransfer supports **custom logging configuration** through an external settings file in JSON format. This allows you to control **how and where logs are written** — to console, to files, or dynamically per run. ([Architecture & Performance][2])
[Custom settings files] (e.g., `FastTransfer_Settings.json`) must be **mounted into the container** under the `/config` directory.

---

### Example: Logging to Console, JSON File and Dynamic Log Files

The following configuration is recommended for most production or orchestrated environments (e.g., Airflow). It writes:

* Logs to the console for real‑time visibility
* Run summary logs to `/airflow/xcom/return.json` for integration
* Per‑run logs under `/logs`, automatically named with `{LogTimestamp}` and `{TraceId}`

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
          "outputTemplate": "{Timestamp:yyyy-MM-ddTHH:mm:ss.fff zzz} ‑|- {Application} ‑|- {runid} ‑|- {Level:u12} ‑|- {fulltargetname} ‑|- {Message}{NewLine}{Exception}",
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
                "encoding": "utf‑8"
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
* The file `/airflow/xcom/return.json` is designed to provide run summaries for integration with orchestration tools.

---

### Available Tokens for Path or Filename Formatting

You can use the following placeholders to dynamically generate log file names or directories:

| Token Name         | Description                                  |
| ------------------ | -------------------------------------------- |
| `{logdate}`        | Current date in `yyyy‑MM‑dd` format          |
| `{logtimestamp}`   | Full timestamp of the log entry              |
| `{sourcedatabase}` | Name of the source database                  |
| `{sourceschema}`   | Name of the source schema                    |
| `{sourcetable}`    | Name of the source table                     |
| `{filename}`       | Name of the file being processed             |
| `{runid}`          | Run identifier provided in the command line  |
| `{traceid}`        | Unique trace identifier generated at runtime |

---

### Mounting a Custom Settings File

The Docker image declares several volumes to organize data and configuration:

```dockerfile
VOLUME ["/config", "/data", "/work", "/logs"]
```

Your settings file (for example, `FastTransfer_Settings.json`) must be placed in `/config`, either by mounting a local directory or by using a Docker named volume.

Example:

```bash
docker run --rm \
  -v /path/to/local/config:/config \
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
  --query "SELECT * FROM public.orders" \
  --fileoutput "orders.parquet" \
  --directory "/data" \
  --paralleldegree 16 \
  --license "$licenseContent"
```

If the `--settingsfile` argument is not provided, FastTransfer will use its built‑in default logging configuration.

---

### Volume Configuration and Access Modes

| Volume Path | Description                                                | Access Mode            | Typical Usage                            |
| ----------- | ---------------------------------------------------------- | ---------------------- | ---------------------------------------- |
| `/config`   | Contains user‑provided configuration files (e.g., logging) | Read‑Only / Read‑Many  | Shared across containers; static configs |
| `/data`     | Directory of SOURCE files to import | Read‑Many / Write‑Many | Mount CSV/Parquet files to be loaded |
| `/work`     | Temporary working directory                                | Read‑Many / Write‑Many | Used internally for intermediate tasks   |
| `/logs`     | Log output directory (per‑run or aggregated logs)          | Read‑Many / Write‑Many | Stores runtime and execution logs        |

---

* Place `/data` on fast storage (e.g., NVMe) when handling large data imports locally.
* Tune `--paralleldegree` based on CPU cores and I/O throughput of source/target systems.
* On Linux, to reach a DB on the local host from container, you may need `--add-host=host.docker.internal:host-gateway` (or `extra_hosts` in Compose).
* For high‑bandwidth object‑store targets or remote databases, ensure consistent MTU and packet size; consider jumbo frames or dedicated endpoints.

## Security tips

* Never commit your license file or cloud credentials to source control.
* Prefer Docker/Compose/Kubernetes **secrets** or environment files (`--env-file`) and managed identities (IAM Role / IRSA / Workload Identity) when targeting cloud systems.
* FastTransfer supports secure logging and obfuscated credentials, but you should still restrict log access and audit credentials.

## Troubleshooting
  --query "SELECT * FROM public.orders" \
* **Permission denied writing under `/data` or `/logs`** → ensure host directory permissions allow the container user (often non‑root) to write.
* **Source or target host not reachable** → check network, DNS, firewall and `host.docker.internal` mapping for Docker.
* **License error / invalid license** → verify you passed correct license content via `--license`, or that your trial license is valid and the binary version matches.

## Notes

* This image **does not embed** the proprietary FastTransfer binary; you must provide it, and a valid license is required to operate.
* OCI labels are set for traceability (source, vendor, license) in the Dockerfile.
* FastTransfer supports many source and target database types (e.g., MySQL, PostgreSQL, SQL Server, Oracle, DuckDB, ClickHouse) and both file‑based and DB‑to‑DB transfers.


