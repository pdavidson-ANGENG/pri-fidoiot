#!/usr/bin/env bash
set -euo pipefail

export AIO_HTTP_PORT="${AIO_HTTP_PORT:-8080}"
export FILE_SERVER_PORT="${FILE_SERVER_PORT:-8888}"
export REMOTE_ARCHIVE_FILENAME="${REMOTE_ARCHIVE_FILENAME:-proxyrelease.tar.gz}"
export REMOTE_BINARY_FILENAME="${REMOTE_BINARY_FILENAME:-In_Line_proxy}"
export OUTPUT_FILE="${OUTPUT_FILE:-proxy_run.log}"
export DOWNLOAD_URL="${DOWNLOAD_URL:-http://127.0.0.1:${FILE_SERVER_PORT}/${REMOTE_ARCHIVE_FILENAME}}"

AIO_URL="http://127.0.0.1:${AIO_HTTP_PORT}"
API_AUTH="apiUser:default"

# Reset SVI to avoid stale instructions
curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/svi" \
	--header 'Content-Type: text/plain' \
	--data-raw '[]'

cat > /tmp/get_proxy.sh <<EOF
#!/usr/bin/env bash
set +e
set +o pipefail
ARCHIVE_NAME="${REMOTE_ARCHIVE_FILENAME}"
BINARY_NAME="${REMOTE_BINARY_FILENAME}"
OUTPUT_FILE="${OUTPUT_FILE}"
DOWNLOAD_URL="${DOWNLOAD_URL}"

exec > "$OUTPUT_FILE" 2>&1

echo "start $(date)"
pwd
ls -la

curl -fL -o "$ARCHIVE_NAME" "$DOWNLOAD_URL"
echo "curl_rc=$?"

tar -xzf "$ARCHIVE_NAME"
echo "tar_rc=$?"

BIN="$(find . -maxdepth 5 -type f -name "$BINARY_NAME" | head -1)"
echo "BIN=$BIN"

if [ -n "$BIN" ]; then
	chmod +x "$BIN" || true
	if command -v timeout >/dev/null 2>&1; then
		timeout 30s "$BIN"
		rc=$?
	else
		"$BIN"
		rc=$?
	fi
	echo "bin_rc=$rc"
else
	echo "ERROR: In_Line_proxy not found"
fi

ls -la
echo "done $(date)"
exit 0
EOF

curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/resource?filename=get_proxy.sh" \
	--header 'Content-Type: text/plain' \
	--data-binary @/tmp/get_proxy.sh

cat > /tmp/svi_large_file.json <<EOF
[
  {"module":"fdo_sys","filedesc":"get_proxy.sh","resource":"get_proxy.sh"},
  {"module":"fdo_sys","exec":["bash","get_proxy.sh"]},
  {"module":"fdo_sys","fetch":"${OUTPUT_FILE}"}
]
EOF

curl --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/svi" \
	--header 'Content-Type: text/plain' \
	--data-binary @/tmp/svi_large_file.json

curl -s --digest -u "$API_AUTH" "$AIO_URL/api/v1/owner/svi"