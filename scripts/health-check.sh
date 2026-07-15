#!/bin/bash
set -euo pipefail

if [ -z "${CLOUDFRONT_DOMAIN:-}" ]; then
  echo "Error: CLOUDFRONT_DOMAIN environment variable is not set."
  echo "Usage: CLOUDFRONT_DOMAIN=your-distribution.cloudfront.net ./health-check.sh"
  exit 1
fi

echo "Checking frontend availability..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${CLOUDFRONT_DOMAIN}/")
if [ "${FRONTEND_STATUS}" -eq 200 ]; then
  echo "Frontend OK (HTTP ${FRONTEND_STATUS})"
else
  echo "Frontend check failed (HTTP ${FRONTEND_STATUS})"
fi

echo "Checking backend health endpoint via CloudFront..."
BACKEND_RESPONSE=$(curl -s "https://${CLOUDFRONT_DOMAIN}/api/v1/health")
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${CLOUDFRONT_DOMAIN}/api/v1/health")

echo "Backend response: ${BACKEND_RESPONSE}"

if [ "${BACKEND_STATUS}" -eq 200 ]; then
  echo "Backend OK (HTTP ${BACKEND_STATUS})"
elif [ "${BACKEND_STATUS}" -eq 503 ]; then
  echo "Backend reachable but reporting degraded status (HTTP 503) - check database/cache connectivity"
else
  echo "Backend check failed (HTTP ${BACKEND_STATUS})"
fi

echo "Checking SPA client-side routing fallback..."
SPA_ROUTE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${CLOUDFRONT_DOMAIN}/some-client-route")
if [ "${SPA_ROUTE_STATUS}" -eq 200 ]; then
  echo "SPA routing fallback OK (HTTP ${SPA_ROUTE_STATUS})"
else
  echo "SPA routing fallback failed (HTTP ${SPA_ROUTE_STATUS})"
fi