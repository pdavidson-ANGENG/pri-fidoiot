#!/usr/bin/env bash

export AIO_HTTP_PORT="${AIO_HTTP_PORT:-8080}"
export REMOTE_ARCHIVE_FILENAME="${REMOTE_ARCHIVE_FILENAME:-dpn_data.tar.gz}"
export RUNNER_SCRIPT_FILENAME="${RUNNER_SCRIPT_FILENAME:-untar_dpn_data.sh}"
export FDO_SVI_SIZE="${FDO_SVI_SIZE:-7900}"
export FDO_MESSAGE_SIZE="${FDO_MESSAGE_SIZE:-7900}"
export TUNE_FDO_LIMITS="${TUNE_FDO_LIMITS:-1}"
export LOCAL_ARCHIVE_PATH="${LOCAL_ARCHIVE_PATH:-$HOME/Documents/${REMOTE_ARCHIVE_FILENAME}}"

export AIO_URL="http://127.0.0.1:${AIO_HTTP_PORT}"
export API_AUTH="apiUser:default"

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "Run this script directly: bash ${BASH_SOURCE[0]}" >&2
  return 0
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
ARCHIVE_PATH="${REMOTE_ARCHIVE_FILENAME}"
if [ ! -f "\$ARCHIVE_PATH" ]; then
  ARCHIVE_PATH="\$(find /opt/fdo/client-sdk-fidoiot /tmp . -maxdepth 4 -type f -name "${REMOTE_ARCHIVE_FILENAME}" 2>/dev/null | head -1)"
fi
if [ -z "\$ARCHIVE_PATH" ]; then
  exit 0
fi
if [ ! -f "\$ARCHIVE_PATH" ]; then
  exit 0
fi
ARCHIVE_DIR="\$(dirname "\$ARCHIVE_PATH")"
cd "\$ARCHIVE_DIR" || exit 0
tar -xzf "\$ARCHIVE_PATH"
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
echo