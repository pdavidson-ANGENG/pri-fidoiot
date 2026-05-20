#!/usr/bin/env bash
set -euo pipefail

export AIO_HTTP_PORT="${AIO_HTTP_PORT:-8080}"
export REMOTE_ARCHIVE_FILENAME="${REMOTE_ARCHIVE_FILENAME:-In_Line_proxy.tar.gz}"
export REMOTE_BINARY_FILENAME="${REMOTE_BINARY_FILENAME:-In_Line_proxy}"
export OUTPUT_FILE="${OUTPUT_FILE:-inline_proxy.out}"
export RUN_TIMEOUT_SECONDS="${RUN_TIMEOUT_SECONDS:-30}"
export FDO_SVI_SIZE="${FDO_SVI_SIZE:-16384}"
export TUNE_FDO_LIMITS="${TUNE_FDO_LIMITS:-1}"
export LOCAL_ARCHIVE_PATH="${LOCAL_ARCHIVE_PATH:-$HOME/Documents/${REMOTE_ARCHIVE_FILENAME}}"

AIO_URL="http://127.0.0.1:${AIO_HTTP_PORT}"
API_AUTH="apiUser:default"

if [[ ! -f "$LOCAL_ARCHIVE_PATH" ]]; then
  echo "ERROR: local archive not found: $LOCAL_ARCHIVE_PATH" >&2
  exit 1
fi

# Optional speed tuning for full-FDO transfer.
if [[ "$TUNE_FDO_LIMITS" == "1" ]]; then
  curl --digest -u "$API_AUTH" --request POST \
    "$AIO_URL/api/v1/owner/svisize" \
    --header 'Content-Type: text/plain' \
    --data-raw "$FDO_SVI_SIZE"

  # This endpoint is capped at 1500 by server-side logic.
  curl --digest -u "$API_AUTH" --request POST \
    "$AIO_URL/api/v1/owner/messagesize" \
    --header 'Content-Type: text/plain' \
    --data-raw '1500'
fi

# Reset SVI to avoid stale instructions
curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/svi" \
	--header 'Content-Type: text/plain' \
	--data-raw '[]'

curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/resource?filename=${REMOTE_ARCHIVE_FILENAME}" \
	--header 'Content-Type: text/plain' \
	--data-binary "@${LOCAL_ARCHIVE_PATH}"

cat > /tmp/svi_fdo_only.json <<EOF
[
  {"module":"fdo_sys","filedesc":"${REMOTE_ARCHIVE_FILENAME}","resource":"${REMOTE_ARCHIVE_FILENAME}"},
  {"module":"fdo_sys","exec":["bash","-lc","tar -xzf '${REMOTE_ARCHIVE_FILENAME}'"]},
  {"module":"fdo_sys","exec":["bash","-lc","set +e; BIN=\$(find . -maxdepth 5 -type f -name '${REMOTE_BINARY_FILENAME}' | head -1); if [ -n \"\$BIN\" ]; then chmod +x \"\$BIN\" || true; if command -v timeout >/dev/null 2>&1; then timeout ${RUN_TIMEOUT_SECONDS}s \"\$BIN\" > '${OUTPUT_FILE}' 2>&1; rc=\$?; else \"\$BIN\" > '${OUTPUT_FILE}' 2>&1; rc=\$?; fi; echo bin_rc=\$rc >> '${OUTPUT_FILE}'; else echo 'ERROR: ${REMOTE_BINARY_FILENAME} not found' > '${OUTPUT_FILE}'; fi"]},
  {"module":"fdo_sys","fetch":"${OUTPUT_FILE}"}
]
EOF

curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/svi" \
	--header 'Content-Type: text/plain' \
	--data-binary @/tmp/svi_fdo_only.json

curl -s --digest -u "$API_AUTH" "$AIO_URL/api/v1/owner/svi"