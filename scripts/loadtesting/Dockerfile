# Multi-stage Dockerfile for LoadGenerator Web Service
# Builds .NET web application for load testing

# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder

WORKDIR /src

# Copy project file and restore dependencies
COPY scripts/loadtesting/LoadGeneratorWeb.csproj .
RUN dotnet restore

# Copy source code and build
COPY scripts/loadtesting/Program.cs .
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0

WORKDIR /app

# Copy published application
COPY --from=builder /app/publish .

# Install curl for health checks
RUN apt-get update && apt-get install -y \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Environment variables (will be overridden at runtime)
ENV POSTGRESQL_SERVER="localhost"
ENV POSTGRESQL_PORT="5432"
ENV POSTGRESQL_DATABASE="postgres"
ENV POSTGRESQL_USERNAME="postgres"
ENV POSTGRESQL_PASSWORD=""
ENV TARGET_TPS="100"
ENV WORKER_COUNT="10"
ENV TEST_DURATION="60"
ENV ASPNETCORE_URLS="http://+:80"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Entrypoint - run the compiled web application
ENTRYPOINT ["dotnet", "LoadGeneratorWeb.dll"]
