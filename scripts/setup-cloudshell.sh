#!/bin/bash
# Cloud Shell Setup Script - Save as setup-cloudshell.sh

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Azure Cloud Shell Setup for SAIF-PostgreSQL Testing        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check if dotnet-script is already installed
echo "🔍 Checking for dotnet-script..."
if command -v dotnet-script &> /dev/null; then
    echo "✅ dotnet-script is already installed"
    dotnet-script --version
else
    echo "📦 Installing dotnet-script..."
    dotnet tool install -g dotnet-script
    
    if [ $? -eq 0 ]; then
        echo "✅ dotnet-script installed successfully"
    else
        echo "❌ Failed to install dotnet-script"
        exit 1
    fi
fi

# Step 2: Add to PATH for current session
echo ""
echo "🔧 Configuring PATH..."
export PATH="$PATH:$HOME/.dotnet/tools"

# Step 3: Verify installation
echo ""
echo "✅ Verification:"
dotnet-script --version

# Step 4: Set up for bash profile (persistent)
echo ""
echo "📝 Adding to ~/.bashrc for future sessions..."
if ! grep -q ".dotnet/tools" ~/.bashrc; then
    echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> ~/.bashrc
    echo "✅ Added to ~/.bashrc"
else
    echo "✅ Already in ~/.bashrc"
fi

# Step 5: Clone repository
echo ""
echo "📥 Checking for SAIF repository..."
if [ -d "SAIF" ]; then
    echo "✅ SAIF repository already exists"
    cd SAIF
    git pull origin main
    echo "✅ Updated to latest version"
else
    echo "📥 Cloning SAIF repository..."
    git clone https://github.com/jonathan-vella/SAIF.git
    if [ $? -eq 0 ]; then
        echo "✅ Repository cloned successfully"
    else
        echo "❌ Failed to clone repository"
        exit 1
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 Next steps:"
echo "   1. cd SAIF/SAIF-pgsql/scripts"
echo "   2. Get your connection string (see below)"
echo "   3. Run: dotnet script Test-PostgreSQL-Failover.csx -- \"\$CONN_STRING\" 10 5"
echo ""
echo "🔐 Get connection string from Key Vault:"
echo "   export PG_PASSWORD=\$(az keyvault secret show --vault-name <vault> --name postgresql-admin-password --query value -o tsv)"
echo "   export CONN_STRING=\"Host=<server>.postgres.database.azure.com;Database=saifdb;Username=saifadmin;Password=\$PG_PASSWORD;SSL Mode=Require\""
echo ""
