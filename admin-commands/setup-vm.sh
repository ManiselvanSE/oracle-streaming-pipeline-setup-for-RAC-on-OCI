#!/bin/bash
# =============================================================================
# Oracle XStream CDC Connector - VM Setup Script
# Run on xstrm-con VM (Oracle Linux 9)
# Requires: sudo access
# =============================================================================

set -e

INSTALL_DIR="${INSTALL_DIR:-/opt/confluent}"
ORACLE_CLIENT_DIR="${ORACLE_CLIENT_DIR:-/opt/oracle/instantclient}"
# Instant Client zip extracts to versioned subdir (e.g. instantclient_19_30)
INSTANT_CLIENT_SUBDIR="${INSTANT_CLIENT_SUBDIR:-instantclient_19_30}"
CONFLUENT_VERSION="7.9.0"
CONFLUENT_MAJOR="7.9"
# CP 7.9.x: Java 17 recommended, 17/11/8 supported (8 deprecated)
JAVA_VERSION=17

echo "=== Oracle XStream CDC - VM Setup (Confluent Platform ${CONFLUENT_VERSION}) ==="

# 1. Install prerequisites (per CP 7.9 system requirements)
# - Java 17 (recommended for CP 7.9)
# - libaio: Oracle Instant Client
# - unzip, wget, curl: downloads and extraction
echo "Installing prerequisites for CP ${CONFLUENT_MAJOR}..."
sudo dnf install -y java-17-openjdk-devel libaio unzip wget curl

# Set JAVA_HOME for Confluent Platform
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=$JAVA_HOME_PATH" | sudo tee /etc/profile.d/java-home.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/java-home.sh
sudo chmod +x /etc/profile.d/java-home.sh
export JAVA_HOME=$JAVA_HOME_PATH

# 2. Create directories
sudo mkdir -p $INSTALL_DIR $ORACLE_CLIENT_DIR

# 3. Download and install Oracle Instant Client
# Note: You must accept Oracle license and download manually from:
# https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html
# Required: instantclient-basic, instantclient-sqlplus (optional), JDBC driver
echo ""
echo "Oracle Instant Client: Manual step required!"
echo "Download from: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"
echo "Required packages: instantclient-basic-linux.x64-19.*.zip"
echo "Extract to: $ORACLE_CLIENT_DIR (creates $INSTANT_CLIENT_SUBDIR/ subdir)"
echo "If your version differs (e.g. instantclient_19_26), set: export INSTANT_CLIENT_SUBDIR=instantclient_19_26"
echo ""

# 4. Set LD_LIBRARY_PATH for Oracle client (native libs are in versioned subdir)
ORACLE_LIB_PATH="$ORACLE_CLIENT_DIR/$INSTANT_CLIENT_SUBDIR"
echo "export LD_LIBRARY_PATH=$ORACLE_LIB_PATH:\$LD_LIBRARY_PATH" | sudo tee /etc/profile.d/oracle-instantclient.sh
sudo chmod +x /etc/profile.d/oracle-instantclient.sh
export LD_LIBRARY_PATH=$ORACLE_LIB_PATH:$LD_LIBRARY_PATH

# 5. Download Confluent Platform (community - for Kafka + Connect)
echo "Downloading Confluent Platform ${CONFLUENT_VERSION}..."
if [ ! -f "/tmp/confluent-${CONFLUENT_VERSION}.tar.gz" ]; then
  wget -q "https://packages.confluent.io/archive/${CONFLUENT_MAJOR}/confluent-${CONFLUENT_VERSION}.tar.gz" -O /tmp/confluent-${CONFLUENT_VERSION}.tar.gz
fi
sudo tar -xzf /tmp/confluent-${CONFLUENT_VERSION}.tar.gz -C $INSTALL_DIR
sudo ln -sf $INSTALL_DIR/confluent-${CONFLUENT_VERSION} $INSTALL_DIR/confluent

# 6. Install Oracle XStream CDC connector via Confluent Hub
# Default install path: share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source
echo "Installing Oracle XStream CDC connector..."
sudo $INSTALL_DIR/confluent/bin/confluent-hub install --no-prompt confluentinc/kafka-connect-oracle-xstream-cdc-source:latest

# 7. Add Oracle JDBC jars to connector lib (manual step after Instant Client is extracted)
CONNECTOR_LIB="$INSTALL_DIR/confluent/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib"
echo "Add ojdbc8.jar and xstreams.jar from Oracle Instant Client to connector lib:"
echo "  sudo cp $ORACLE_CLIENT_DIR/$INSTANT_CLIENT_SUBDIR/ojdbc8.jar $CONNECTOR_LIB/"
echo "  sudo cp $ORACLE_CLIENT_DIR/$INSTANT_CLIENT_SUBDIR/xstreams.jar $CONNECTOR_LIB/"

echo ""
echo "=== Setup complete ==="
echo "Next steps:"
echo "1. Extract Oracle Instant Client to $ORACLE_CLIENT_DIR (creates $INSTANT_CLIENT_SUBDIR/ subdir)"
echo "2. Copy JARs: sudo cp $ORACLE_CLIENT_DIR/$INSTANT_CLIENT_SUBDIR/{ojdbc8,xstreams}.jar $CONNECTOR_LIB/"
echo "3. Start Confluent (KRaft): cd /home/opc/oracle-xstream-cdc-poc && ./admin-commands/start-confluent-kraft.sh"
echo "4. Deploy connector with your config JSON"
echo "5. Run verify-connectivity.sh to test RAC connectivity"
