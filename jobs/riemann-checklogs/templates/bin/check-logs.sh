#!/bin/bash

set -e -x

TODAY=$(date +%Y.%m.%d)
YESTERDAY=$(date -d "1 day ago" +%Y.%m.%d)

TTL=${TTL:-600}
JQ_PATH=${JQ_PATH:-/var/vcap/packages/jq-1.5/bin/jq}
INTERVAL=${INTERVAL:-5m}
ES_URL=${ES_URL:-localhost:9200}
RIEMANNC_PATH=/var/vcap/jobs/riemannc/bin/riemannc

function raw {
  echo "${1}" | ${JQ_PATH} -R .
}

function query {
  echo $(curl "${ES_URL}/logs-${1}-${2}/_search" -d "${QUERY}" | ${JQ_PATH} ".hits.total")
}

QUERY=$(${JQ_PATH} -n "{
  query: {
    range: {
      $(raw "@timestamp"): {
        gte: $(raw "now-${INTERVAL}/s")
      }
    }
  }
"})

PLATFORM_LOGS=$(( $(query "platform" ${TODAY}) + $(query "platform" ${YESTERDAY}) ))
${RIEMANNC_PATH} --service "logsearch.health.platform" --host $(hostname) --ttl ${TTL} --metric ${PLATFORM_LOGS}

APP_LOGS=$(( $(query "app" ${TODAY}) + $(query "app" ${YESTERDAY}) ))
${RIEMANNC_PATH} --service "logsearch.health.app" --host $(hostname) --ttl ${TTL} --metric ${APP_LOGS}

