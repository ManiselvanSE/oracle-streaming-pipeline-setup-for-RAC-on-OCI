#!/bin/bash
# Check which CDC topics have messages - run on VM
# Usage: ./admin-commands/check-kafka-topics.sh

KAFKA_CONSUMER="/opt/confluent/confluent/bin/kafka-console-consumer"
[ -x "$KAFKA_CONSUMER" ] || KAFKA_CONSUMER="kafka-console-consumer"

echo "=== Checking CDC topics for messages ==="
echo ""

for topic in __cflt-oracle-heartbeat.racdb __orcl-schema-changes.racdb \
  racdb.XSTRPDB.ORDERMGMT.REGIONS racdb.XSTRPDB.ORDERMGMT.MTX_TRANSACTION_ITEMS \
  racdb.ORDERMGMT.REGIONS racdb.ORDERMGMT.MTX_TRANSACTION_ITEMS; do
  count=$(timeout 8 "$KAFKA_CONSUMER" \
    --bootstrap-server 127.0.0.1:9092 \
    --topic "$topic" \
    --partition 0 \
    --offset 0 \
    --max-messages 1 \
    --timeout-ms 5000 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    echo "HAS DATA: $topic"
  else
    echo "empty:    $topic"
  fi
done

echo ""
echo "=== Quick consume test (REGIONS - has snapshot data) ==="
timeout 12 "$KAFKA_CONSUMER" \
  --bootstrap-server 127.0.0.1:9092 \
  --topic racdb.ORDERMGMT.REGIONS \
  --partition 0 --offset 0 --max-messages 1 2>/dev/null | head -c 200 && echo "..." && echo "(got message)" || echo "(no message)"
