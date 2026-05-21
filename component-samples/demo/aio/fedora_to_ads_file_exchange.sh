#!/usr/bin/env bash

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

  # Message size is clamped by MessageSizeApi validation.
  curl --digest -u "$API_AUTH" --request POST \
    "$AIO_URL/api/v1/owner/messagesize" \
    --header 'Content-Type: text/plain' \
    --data-raw "$FDO_MESSAGE_SIZE"
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

cat > "/tmp/${RUNNER_SCRIPT_FILENAME}" <<EOF
#!/usr/bin/env sh
set +e
tar -xzf "${REMOTE_ARCHIVE_FILENAME}"
BIN="\$(find . -maxdepth 5 -type f -name "${REMOTE_BINARY_FILENAME}" | head -1)"
if [ -n "$BIN" ]; then
  chmod +x "$BIN" || true
  "$BIN"
  echo "bin_rc=\$?"
else
  echo "ERROR: ${REMOTE_BINARY_FILENAME} not found" >&2
fi
EOF

curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/resource?filename=${RUNNER_SCRIPT_FILENAME}" \
	--header 'Content-Type: text/plain' \
	--data-binary "@/tmp/${RUNNER_SCRIPT_FILENAME}"

cat > /tmp/svi_short_exec.json <<EOF
[
  {"module":"fdo_sys","filedesc":"${REMOTE_ARCHIVE_FILENAME}","resource":"${REMOTE_ARCHIVE_FILENAME}"},
  {"module":"fdo_sys","filedesc":"${RUNNER_SCRIPT_FILENAME}","resource":"${RUNNER_SCRIPT_FILENAME}"},
  {"module":"fdo_sys","exec":["sh","${RUNNER_SCRIPT_FILENAME}"]}
]
EOF

curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/svi" \
	--header 'Content-Type: text/plain' \
	--data-binary @/tmp/svi_short_exec.json

curl -s --digest -u "$API_AUTH" "$AIO_URL/api/v1/owner/svi"