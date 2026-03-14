# Oracle CDC XStream Connector Setup in OCI RAC

This guide helps you set up a self-managed Oracle CDC XStream connector in OCI, connecting from the **xstrm-con** VM to the **Mani_RACDB** Oracle RAC database.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  OCI - US West (Phoenix)                                                 │
│                                                                          │
│  ┌──────────────────────┐         ┌─────────────────────────────────┐  │
│  │  xstrm-con (VM)       │         │  Mani_RACDB (Oracle RAC)         │  │
│  │  Public IP:           │  ────►  │  SCAN: racdb-scan.sub0106124...  │  │
│  │  161.153.48.163       │  1521   │  Port: 1521                       │  │
│  │  Oracle Linux 9       │         │  Cluster: xstrmracdb              │  │
│  │                       │         │  VCN: xstrm-connect-db2          │  │
│  │  - Confluent Platform │         │  SCAN IPs: 10.0.0.29, .238, .91  │  │
│  │  - Oracle XStream     │         │                                  │  │
│  │    CDC Connector      │         │  - XStream Out configured        │  │
│  └──────────────────────┘         └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites Checklist

### 1. SSH Access to VM

**Important:** For SSH login, you need the **private key** (not the public key):
- **Private key** (for login): `ssh-key-2026-03-12.key` 
- **Public key** (added to VM): `ssh-key-2026-03-12.key.pub`

The public key must be added to the VM's `~/.ssh/authorized_keys` when the instance was created.

### 2. Network Connectivity

The VM (10.0.0.43) and RAC (10.0.0.29, .238, .91) are in the same subnet. **Ensure the RAC client subnet's Security List allows inbound TCP 1521** from the VM subnet (e.g., 10.0.0.0/24).

- **RAC DB**: SCAN IPs 10.0.0.29, 10.0.0.238, 10.0.0.91 in `xstrm-connect-db2` VCN
- **VM**: Private IP 10.0.0.43 - same VCN
- **Action**: Add Security List ingress rule: Source=10.0.0.0/24, Dest Port=1521, Protocol=TCP

### 3. Oracle Database Requirements

- Oracle 19c or 21c Enterprise/Standard Edition
- ARCHIVELOG mode enabled
- XStream enabled (`enable_goldengate_replication=TRUE`)
- Supplemental logging configured
- XStream administrator and connect users created
- XStream Out outbound server created

## Quick Start

> **Full setup guide:** See [docs/EXECUTION-GUIDE.md](docs/EXECUTION-GUIDE.md)  
> **Troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Step 1: Connect to the VM via SSH

```bash
# Use mani-xstrm-vm (137.131.53.98) - same VCN as RAC
chmod 600 /path/to/ssh-key-2026-03-12.key
ssh -i /path/to/ssh-key-2026-03-12.key opc@137.131.53.98
```

> **Note:** OCI Oracle Linux uses `opc` as default user.

### Step 2: Verify Network Connectivity to RAC DB

From the VM, test connectivity to the RAC SCAN address:

```bash
# Test DNS resolution
nslookup racdb-scan.sub01061249390.xstrmconnectdb2.oraclevcn.com

# Test port connectivity
nc -zv racdb-scan.sub01061249390.xstrmconnectdb2.oraclevcn.com 1521
# or
telnet racdb-scan.sub01061249390.xstrmconnectdb2.oraclevcn.com 1521
```

### Step 3: Configure Oracle RAC Database (DBA Task)

Run the SQL scripts in `oracle-db-scripts/` on the RAC database. See [Oracle Database Setup](#oracle-database-setup) below.

### Step 4: Self-Managed Connector Installation (VM)

Follow these steps **in sequence** on the VM (mani-xstrm-vm, 137.131.53.98).

#### 4.1 Copy project to VM (from your Mac)

```bash
cd /path/to/airtel
scp -i /path/to/ssh-key-2026-03-12.key -r oracle-xstream-cdc-poc opc@137.131.53.98:/home/opc/
```

#### 4.2 Run setup script

```bash
ssh -i /path/to/ssh-key-2026-03-12.key opc@137.131.53.98

chmod +x /home/opc/oracle-xstream-cdc-poc/scripts/setup-vm.sh
sudo /home/opc/oracle-xstream-cdc-poc/scripts/setup-vm.sh
```

This installs: Java 17, Confluent Platform 7.9.0, Oracle XStream CDC Connector 1.3.2. Allow 10–15 minutes.

#### 4.2a Install Docker (optional)

Docker is optional. Use it if you prefer `confluent local` (Docker-based) instead of the KRaft tar install.

```bash
chmod +x /home/opc/oracle-xstream-cdc-poc/scripts/install-docker.sh
sudo /home/opc/oracle-xstream-cdc-poc/scripts/install-docker.sh
```

Verify: `sudo docker run hello-world`

To allow `opc` user to run Docker without sudo: log out and SSH back in after install.

**Manual Docker install (Oracle Linux 9):**

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker && sudo systemctl start docker
sudo usermod -aG docker opc   # then log out and back in
```

#### 4.3 Install Oracle Instant Client

1. Download from: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html  
2. **Required (connector):** `instantclient-basic-linux.x64-19.30.0.0.0dbru.zip` – Basic Package (OCI, JDBC; includes ojdbc8.jar, xstreams.jar)  
3. **Optional (SQL*Plus for running SQL scripts):** `instantclient-sqlplus-linux.x64-19.30.0.0.0dbru.zip` – SQL*Plus Package  
4. Copy and extract on VM:

```bash
# Create directory
sudo mkdir -p /opt/oracle/instantclient
cd /opt/oracle/instantclient

# Required: Basic Package (for connector)
sudo unzip -o instantclient-basic-linux.x64-19.30.0.0.0dbru.zip

# Optional: SQL*Plus (for running oracle-db-scripts via sqlplus)
sudo unzip -o instantclient-sqlplus-linux.x64-19.30.0.0.0dbru.zip
```

**Package names (19.30):**

| Package | Filename | Purpose |
|---------|----------|---------|
| Basic | `instantclient-basic-linux.x64-19.30.0.0.0dbru.zip` | Connector (ojdbc8, xstreams, OCI) |
| SQL*Plus | `instantclient-sqlplus-linux.x64-19.30.0.0.0dbru.zip` | Run SQL scripts (e.g. 07-produce-orders-procedure.sql) |

#### 4.4 Copy Oracle JARs to connector lib

The connector is installed under `confluentinc-kafka-connect-oracle-xstream-cdc-source`. Copy `ojdbc8.jar` and `xstreams.jar` from the Instant Client extract (e.g. `instantclient_19_30/`):

```bash
sudo cp /opt/oracle/instantclient/instantclient_19_30/ojdbc8.jar \
  /opt/confluent/confluent/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/
sudo cp /opt/oracle/instantclient/instantclient_19_30/xstreams.jar \
  /opt/confluent/confluent/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/
```

Verify:

```bash
ls -la /opt/confluent/confluent/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/
```

#### 4.5 Set LD_LIBRARY_PATH

```bash
export LD_LIBRARY_PATH=/opt/oracle/instantclient/instantclient_19_30:$LD_LIBRARY_PATH
```

Persist in profile:

```bash
echo 'export LD_LIBRARY_PATH=/opt/oracle/instantclient/instantclient_19_30:$LD_LIBRARY_PATH' | sudo tee /etc/profile.d/oracle-instantclient.sh
```

**SQL*Plus (if installed):** To run SQL scripts (e.g. `07-produce-orders-procedure.sql`):

```bash
export ORACLE_HOME=/opt/oracle/instantclient/instantclient_19_30
export PATH=$ORACLE_HOME:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH
sqlplus ordermgmt/<password>@//racdb-scan.sub01061249390.xstrmconnectdb2.oraclevcn.com:1521/XSTRPDB.sub01061249390.xstrmconnectdb2.oraclevcn.com
```

#### 4.6 Start Confluent Platform (KRaft mode, no Zookeeper)

**First run – fix permissions** (Confluent was installed with sudo, so logs dir is root-owned):

```bash
sudo mkdir -p /opt/confluent/confluent/logs
sudo chown -R opc:opc /opt/confluent/confluent/logs
```

**Start Confluent:**

```bash
export LD_LIBRARY_PATH=/opt/oracle/instantclient/instantclient_19_30:$LD_LIBRARY_PATH
cd /home/opc/oracle-xstream-cdc-poc
chmod +x scripts/start-confluent-kraft.sh
./scripts/start-confluent-kraft.sh
```

To stop: `./scripts/stop-confluent-kraft.sh`

**If `kafka-storage` not found:** The Confluent community tar may not include it. Try `ls /opt/confluent/confluent/bin/ | grep storage` to verify. If missing, use Docker: `confluent local services start`.

**Alternative (Docker):** If Docker is installed, you can use `confluent local services start` instead.

#### 4.7 Update connector config and deploy

1. Copy `oracle-xstream-rac.json.example` to `oracle-xstream-rac.json` and set `database.password`, `database.service.name`, `table.include.list`  
2. Deploy:

```bash
curl -X POST -H "Content-Type: application/json" \
  --data @/home/opc/oracle-xstream-cdc-poc/connector-config/oracle-xstream-rac.json \
  http://localhost:8083/connectors
```

#### 4.8 List and describe Kafka topics

**List all topics:**
```bash
/opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 --list
```

**List CDC topics only:**
```bash
/opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 --list | grep racdb
```

**Describe a topic (partitions, replication, config):**
```bash
/opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 \
  --describe --topic racdb.XSTRPDB.ORDERMGMT.REGIONS
```

**Describe all topics:**
```bash
/opt/confluent/confluent/bin/kafka-topics --bootstrap-server localhost:9092 --describe
```

**Example CDC topics:** `racdb.XSTRPDB.ORDERMGMT.REGIONS`, `racdb.XSTRPDB.ORDERMGMT.ORDERS`, etc.

#### Key paths (reference)

| Component | Path |
|-----------|------|
| Confluent Platform | `/opt/confluent/confluent/` |
| Connector lib | `/opt/confluent/confluent/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/` |
| Oracle Instant Client | `/opt/oracle/instantclient/instantclient_19_30` |

### Step 5: Deploy and Start the Connector

Use the connector configuration in `connector-config/oracle-xstream-rac.json`.

---

## Oracle Database Setup

Your DBA must run these scripts on the RAC database. Connect as SYSDBA.

### 3.1 Run scripts in order (01 → 08)

Execute in sequence: `01` → `02` → `03` → `04` → `05` → `06` → `07`.

### 3.2 Enable XStream and Verify ARCHIVELOG

```sql
-- Enable XStream (all RAC instances)
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;

-- Verify
SELECT VALUE FROM V$PARAMETER WHERE NAME = 'enable_goldengate_replication';
SELECT LOG_MODE FROM V$DATABASE;  -- Should show ARCHIVELOG
```

### 3.3 Supplemental Logging

```sql
-- Minimal (prerequisite)
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- For specific tables (recommended for POC) - ORDERMGMT schema from 01-create-sample-schema.sql
ALTER SESSION SET CONTAINER = XSTRPDB;
ALTER TABLE ORDERMGMT.REGIONS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.COUNTRIES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.LOCATIONS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.WAREHOUSES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.EMPLOYEES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.PRODUCT_CATEGORIES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.PRODUCTS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.CUSTOMERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.CONTACTS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.ORDERS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.ORDER_ITEMS ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.INVENTORIES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER TABLE ORDERMGMT.NOTES ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

### 3.4 Create XStream Users and Outbound Server

See `oracle-db-scripts/` for complete SQL scripts. Run in order: 01 → 02 → 03 → 04 → 05 → 06 → 07.

---

## RAC-Specific Connector Configuration

For Oracle RAC, use the **SCAN address** as `database.hostname` and the **XStream service name** from `gv$SERVICES`.

### Get XStream service name (RAC)

Run this on the RAC database after creating the XStream outbound server:

```sql
SELECT inst_id, service_id, name, network_name 
FROM gv$SERVICES 
WHERE NAME LIKE '%XOUT%';
```

Use the `network_name` value as `database.service.name` in the connector config. Example output:

```
   INST_ID SERVICE_ID
---------- ----------
NAME
----------------------------------------------------------------
NETWORK_NAME
--------------------------------------------------------------------------------
         1          3
SYS.Q$_XOUT_5
SYS$SYS.Q$_XOUT_5.DB0312.SUB01061249390.XSTRMCONNECTDB2.ORACLEVCN.COM
```

### Connector properties

| Property | Value |
|----------|-------|
| database.hostname | `racdb-scan.sub01061249390.xstrmconnectdb2.oraclevcn.com` |
| database.port | `1521` |
| database.service.name | *(From `network_name` in query above, e.g. `SYS$SYS.Q$_XOUT_5.DB0312.SUB01061249390.XSTRMCONNECTDB2.ORACLEVCN.COM`)* |

---

## File Structure

```
oracle-xstream-cdc-poc/
├── README.md                    # This file
├── oracle-db-scripts/           # SQL scripts for Oracle DB setup
│   ├── 01-create-sample-schema.sql    # ORDERMGMT sample (from ora0600/confluent-new-cdc-connector)
│   ├── 02-enable-xstream.sql
│   ├── 03-supplemental-logging.sql
│   ├── 04-create-xstream-users.sql
│   ├── 05-load-sample-data.sql
│   ├── 06-create-outbound-ordermgmt.sql
│   ├── 07-produce-orders-procedure.sql
│   ├── 08-verify-xstream-outbound.sql   # Verify outbound server config
│   ├── 09-check-and-start-xstream.sql   # Check status, start capture/apply if disabled
│   └── 10-teardown-xstream-outbound.sql # Drop XStream outbound (teardown)
├── config/                      # KRaft configs (server-kraft.properties, schema-registry-kraft.properties)
├── connector-config/
│   ├── oracle-xstream-rac.json.example   # Template (copy to oracle-xstream-rac.json, add secrets)
│   └── README.md
├── scripts/                     # VM setup and utility scripts
│   ├── setup-vm.sh
│   ├── install-docker.sh          # Optional: Install Docker on Oracle Linux 9
│   ├── start-confluent-kraft.sh   # Start Confluent 7.9 with KRaft (no Zookeeper)
│   ├── stop-confluent-kraft.sh
│   ├── verify-connectivity.sh
│   ├── check-and-start-xstream.sh # Check/start XStream capture and apply on DB
│   ├── teardown-vm.sh            # Stop Confluent, delete connector, Kafka data
│   ├── teardown-all.sh           # Full teardown (DB + VM)
│   ├── setup-from-scratch.sh     # Setup after teardown (Confluent + connector)
│   └── ssh-connect.sh
├── docs/
│   └── EXECUTION-GUIDE.md       # Complete setup commands and flow
├── TROUBLESHOOTING.md           # Common issues and fixes
```

---

## Before First Use

1. Copy `connector-config/oracle-xstream-rac.json.example` to `oracle-xstream-rac.json`
2. Edit `oracle-xstream-rac.json`: set `database.password`, `database.service.name`, `database.hostname` for your environment
3. Deploy with: `curl -X POST -H "Content-Type: application/json" --data @connector-config/oracle-xstream-rac.json http://localhost:8083/connectors`

## Security Note

- `oracle-xstream-rac.json` (with real credentials) is in `.gitignore` and is not committed.
- SQL scripts and setup scripts use a default POC password. **Change all passwords before production use.**

## License Note

The Oracle XStream CDC connector is a **Confluent Premium connector** requiring an Enterprise subscription. A 30-day trial is available for POC evaluation.

---

## References

- [Confluent Oracle XStream CDC Connector Docs](https://docs.confluent.io/kafka-connectors/oracle-xstream-cdc-source/current/overview.html)
- [Oracle XStream Out Configuration](https://docs.oracle.com/en/database/oracle/oracle-database/19/xstrm/configuring-xstream-out.html)
