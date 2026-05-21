#!/usr/bin/env bash

export AIO_HTTP_PORT="${AIO_HTTP_PORT:-8080}"
AIO_URL="http://127.0.0.1:${AIO_HTTP_PORT}"

# Use the auth mode that matches your active AIO config.
# Example for digest auth mode:
API_AUTH="apiUser:default"

SCRIPT="$HOME/pri-fidoiot/hello_world_date.sh"

cat > "$SCRIPT" <<'EOF'
#!/usr/bin/env bash
{
	echo "hello from ADS client"
	date
	hostname
	whoami
} > hello_world_date.out 2>&1
EOF
chmod +x "$SCRIPT"

curl -D - --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/resource?filename=hello_world_date.sh" \
	--header 'Content-Type: text/plain' \
	--data-binary @"$SCRIPT"

cat > /tmp/svi_hello_world_date.json <<'EOF'
[
	{"filedesc":"hello_world_date.sh","resource":"hello_world_date.sh"},
	{"exec":["bash","hello_world_date.sh"]},
	{"fetch":"hello_world_date.out"}
]
EOF

curl -D - --digest -u "$API_AUTH" --request POST \
	"$AIO_URL/api/v1/owner/svi" \
	--header 'Content-Type: text/plain' \
	--data-binary @/tmp/svi_hello_world_date.json

# Note: With Digest auth, seeing an initial 401 challenge followed by 200 is expected.