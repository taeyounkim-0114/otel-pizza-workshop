#!/bin/sh
# Renders dash0.js.template into the served document root, substituting only the
# two Dash0 variables so the JavaScript in the template is left untouched.
set -eu

template=/etc/nginx/dash0/dash0.js.template
output=/usr/share/nginx/html/dash0.js

if [ ! -f "$template" ]; then
  echo "10-dash0-config.sh: $template not found, skipping" >&2
  exit 0
fi

export DASH0_BROWSER_ENDPOINT="${DASH0_BROWSER_ENDPOINT:-}"
export DASH0_WEBSITE_SERVICE_NAME="${DASH0_WEBSITE_SERVICE_NAME:-pizza-frontend}"

envsubst '${DASH0_BROWSER_ENDPOINT} ${DASH0_WEBSITE_SERVICE_NAME}' < "$template" > "$output"

echo "10-dash0-config.sh: wrote $output (service.name=$DASH0_WEBSITE_SERVICE_NAME, endpoint=${DASH0_BROWSER_ENDPOINT:-auto})"
