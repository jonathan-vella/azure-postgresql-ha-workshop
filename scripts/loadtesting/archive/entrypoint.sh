#!/bin/sh
# Entrypoint script for LoadGenerator container
# Runs LoadGenerator as a web service with HTTP endpoints

set -e

echo "🚀 Starting LoadGenerator Web Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Display configuration
echo "Configuration:"
echo "  PostgreSQL Server: $POSTGRESQL_SERVER:$POSTGRESQL_PORT"
echo "  Database: $POSTGRESQL_DATABASE"
echo "  Target TPS: $TARGET_TPS"
echo "  Worker Count: $WORKER_COUNT"
echo "  Test Duration: ${TEST_DURATION}s"
echo "  Listen Port: ${PORT:-80}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run LoadGenerator Web Server using dotnet script
cd /app

# Run C# script using dotnet's script support
# This provides HTTP endpoints for monitoring and controlling the load test
dotnet script LoadGeneratorWeb.csx

echo "✅ LoadGenerator Web Server stopped"
