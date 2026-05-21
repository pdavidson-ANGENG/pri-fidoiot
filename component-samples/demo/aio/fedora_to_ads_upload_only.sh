#!/usr/bin/env bash


if [[ ! -f "$LOCAL_FILE_PATH" ]]; then
  echo "ERROR: local file not found: $LOCAL_FILE_PATH" >&2
  exit 1
fi

if [[ "$TUNE_FDO_LIMITS" == "1" ]]; then
  curl --digest -u "$API_AUTH" --request POST \
    "$AIO_URL/api/v1/owner/svisize" \
    --header 'Content-Type: text/plain' \
    --data-raw "$FDO_SVI_SIZE"

  curl --digest -u "$API_AUTH" --request POST \
    "$AIO_URL/api/v1/owner/messagesize" \
    --header 'Content-Type: text/plain' \
    --data-raw "$FDO_MESSAGE_SIZE"
fi

if [[ "$RESET_SVI" == "1" ]]; then
  curl --digest -u "$API_AUTH" --request POST \
    "$AIO_URL/api/v1/owner/svi" \
    --header 'Content-Type: text/plain' \
    --data-raw '[]'
fi

curl --digest -u "$API_AUTH" --request POST \
  "$AIO_URL/api/v1/owner/resource?filename=${REMOTE_FILENAME}" \
  --header 'Content-Type: text/plain' \
  --data-binary "@${LOCAL_FILE_PATH}"

cat > /tmp/svi_upload_only.json <<EOF
[
  {"module":"fdo_sys","filedesc":"${REMOTE_FILENAME}","resource":"${REMOTE_FILENAME}"}
]
EOF

curl --digest -u "$API_AUTH" --request POST \
  "$AIO_URL/api/v1/owner/svi" \
  --header 'Content-Type: text/plain' \
  --data-binary @/tmp/svi_upload_only.json

echo "Posted upload-only SVI for ${REMOTE_FILENAME}."
curl -s --digest -u "$API_AUTH" "$AIO_URL/api/v1/owner/svi"
echo
