# High-Performance Architecture for 8000 TPS Failover Testing

**Target**: Achieve 8000+ transactions per second (TPS) for PostgreSQL failover testing  
**Current Performance**: ~12-13 TPS (PowerShell with Npgsql)  
**Required Improvement**: ~615x increase

---

## 📊 Current State Analysis

### Current Architecture Limitations

| Component | Current | Bottleneck | Impact on TPS |
|-----------|---------|------------|---------------|
| **Test Client** | PowerShell 7 | Single-threaded loop overhead | ~12-13 TPS max |
| **PostgreSQL SKU** | Standard_D4ds_v5 (4 vCore, 16GB) | CPU and connection limits | ~1000-2000 TPS max |
| **Connection Method** | Direct connections (port 5432) | No connection pooling | High latency per connection |
| **Network** | Internet from local PC | 50-100ms latency | Serialized operations |
| **Compute Location** | Local PC | Geographic distance to Azure | Network RTT overhead |

### Why 12-13 TPS?
The PowerShell script's current performance is limited by:
1. **PowerShell loop overhead**: ~80-90ms per iteration
2. **Single-threaded execution**: No parallel workers
3. **Network roundtrip**: 50-100ms from local PC to Azure
4. **Connection overhead**: Each transaction = new connection or reuse with overhead

---

## 🎯 Recommended Architecture Options

I'll present **three solutions** ranked by cost-effectiveness and complexity:

---

## ✅ Option 1: Azure Container Instances with Parallel Workers (RECOMMENDED)

**Expected TPS**: 8000-12,000 TPS  
**Cost**: ~$50-100/month (when testing)  
**Complexity**: Medium  
**Best For**: On-demand high-performance testing without permanent infrastructure

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Azure Sweden Central Region                      │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │              Azure Container Instances (ACI)                    │ │
│  │                                                                  │ │
│  │  ┌─────────────────────────────────────────────────────────┐   │ │
│  │  │  Load Generator Container (C#/.NET 8)                    │   │ │
│  │  │  • CPU: 8-16 vCores                                      │   │ │
│  │  │  • RAM: 16-32 GB                                         │   │ │
│  │  │  • 100-200 async parallel workers                        │   │ │
│  │  │  • Connection pooling (Npgsql)                           │   │ │
│  │  │  • Expected: 8000-12000 TPS                             │   │ │
│  │  └─────────────────────────────────────────────────────────┘   │ │
│  │                             │                                    │ │
│  │                             │ <1-5ms latency                     │ │
│  │                             ▼                                    │ │
│  │  ┌─────────────────────────────────────────────────────────┐   │ │
│  │  │  Built-in PgBouncer (Port 6432)                          │   │ │
│  │  │  • Connection pooling enabled                            │   │ │
│  │  │  • Transaction mode                                      │   │ │
│  │  │  • 500-1000 pooled connections                           │   │ │
│  │  └─────────────────────────────────────────────────────────┘   │ │
│  │                             │                                    │ │
│  │                             ▼                                    │ │
│  │  ┌─────────────────────────────────────────────────────────┐   │ │
│  │  │  PostgreSQL Flexible Server (UPGRADED)                   │   │ │
│  │  │  SKU: Standard_D16ds_v5 or Standard_E4ds_v5             │   │ │
│  │  │  • 16 vCores, 64 GB RAM  OR  4 vCores, 32 GB RAM        │   │ │
│  │  │  • Zone-Redundant HA                                     │   │ │
│  │  │  • max_connections: 2000-5000                            │   │ │
│  │  │  • Optimized parameters                                  │   │ │
│  │  └─────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  Zone 1 (Primary)                    Zone 2 (Standby)               │
└──────────────────────────────────────────────────────────────────────┘
```

### Implementation Steps

#### 1. **Upgrade PostgreSQL SKU** (Required for 8000 TPS)

Your current **Standard_D4ds_v5** (4 vCore, 16GB RAM) cannot sustain 8000 TPS. Upgrade to:

**Option A: Compute-Optimized** (Best for high TPS)
```bicep
postgresqlSku: 'Standard_D16ds_v5'  // 16 vCore, 64 GB RAM
max_connections: 5000
shared_buffers: 16 GB
effective_cache_size: 48 GB
```
**Cost**: ~$1.50/hour (~$1,080/month)  
**TPS Capacity**: 10,000-15,000 TPS

**Option B: Memory-Optimized** (Best balance)
```bicep
postgresqlSku: 'Standard_E4ds_v5'   // 4 vCore, 32 GB RAM
max_connections: 2000
shared_buffers: 8 GB
effective_cache_size: 24 GB
```
**Cost**: ~$0.85/hour (~$612/month)  
**TPS Capacity**: 8,000-10,000 TPS

#### 2. **Enable Built-in PgBouncer**

```bash
# Enable PgBouncer on PostgreSQL Flexible Server
az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name pgbouncer.enabled \
    --value on

# Set PgBouncer parameters
az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name pgbouncer.default_pool_size \
    --value 100

az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name pgbouncer.max_client_conn \
    --value 5000

az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name pgbouncer.pool_mode \
    --value transaction
```

#### 3. **Deploy High-Performance Load Generator (C#/.NET 8)**

Create `scripts/LoadGenerator.csx` (C# script):

```csharp
#!/usr/bin/env dotnet-script
#r "nuget: Npgsql, 8.0.3"
#r "nuget: System.Threading.Tasks.Dataflow, 8.0.0"

using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Threading.Tasks.Dataflow;
using Npgsql;

// Configuration
var connectionString = Environment.GetEnvironmentVariable("POSTGRES_CONNECTION_STRING") 
    ?? throw new Exception("POSTGRES_CONNECTION_STRING not set");
var targetTps = int.Parse(Environment.GetEnvironmentVariable("TARGET_TPS") ?? "8000");
var workerCount = int.Parse(Environment.GetEnvironmentVariable("WORKER_COUNT") ?? "200");
var testDurationSeconds = int.Parse(Environment.GetEnvironmentVariable("TEST_DURATION") ?? "300");

Console.WriteLine($"🚀 High-Performance Load Generator");
Console.WriteLine($"   Target TPS: {targetTps}");
Console.WriteLine($"   Workers: {workerCount}");
Console.WriteLine($"   Duration: {testDurationSeconds}s");
Console.WriteLine();

// Connection pool configuration
var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
dataSourceBuilder.ConnectionString.MaxPoolSize = workerCount + 50;
dataSourceBuilder.ConnectionString.MinPoolSize = workerCount;
dataSourceBuilder.ConnectionString.ConnectionIdleLifetime = 300;
dataSourceBuilder.ConnectionString.ConnectionPruningInterval = 10;
await using var dataSource = dataSourceBuilder.Build();

// Metrics
var totalTransactions = 0L;
var successfulTransactions = 0L;
var failedTransactions = 0L;
var latencies = new ConcurrentBag<long>();
var failoverDetected = false;
var failoverStartTime = DateTime.MinValue;
var failoverEndTime = DateTime.MinValue;

// Worker task
async Task Worker(CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            await using var conn = await dataSource.OpenConnectionAsync(ct);
            await using var cmd = new NpgsqlCommand(
                "INSERT INTO transactions (customer_id, merchant_id, amount, status) " +
                "VALUES (1, 1, @amount, 'completed') RETURNING transaction_id", conn);
            cmd.Parameters.AddWithValue("amount", Random.Shared.Next(10, 1000));
            
            var result = await cmd.ExecuteScalarAsync(ct);
            
            sw.Stop();
            Interlocked.Increment(ref successfulTransactions);
            latencies.Add(sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            sw.Stop();
            Interlocked.Increment(ref failedTransactions);
            
            if (!failoverDetected && ex.Message.Contains("connection"))
            {
                failoverDetected = true;
                failoverStartTime = DateTime.UtcNow;
                Console.WriteLine($"⚠️  Failover detected at {failoverStartTime:HH:mm:ss.fff}");
            }
        }
        finally
        {
            Interlocked.Increment(ref totalTransactions);
        }
        
        // Rate limiting (optional)
        if (targetTps > 0)
        {
            var delayMs = (int)(1000.0 / (targetTps / (double)workerCount));
            if (delayMs > 0) await Task.Delay(delayMs, ct);
        }
    }
}

// Monitor task
async Task Monitor(CancellationToken ct)
{
    var lastTotal = 0L;
    var lastTime = DateTime.UtcNow;
    
    while (!ct.IsCancellationRequested)
    {
        await Task.Delay(1000, ct);
        
        var currentTotal = Interlocked.Read(ref totalTransactions);
        var currentTime = DateTime.UtcNow;
        var elapsed = (currentTime - lastTime).TotalSeconds;
        var tps = (currentTotal - lastTotal) / elapsed;
        
        var lats = latencies.ToArray();
        var p50 = lats.Length > 0 ? lats.OrderBy(x => x).ElementAt(lats.Length / 2) : 0;
        var p95 = lats.Length > 0 ? lats.OrderBy(x => x).ElementAt((int)(lats.Length * 0.95)) : 0;
        
        Console.WriteLine(
            $"[{currentTime:HH:mm:ss}] TPS: {tps:F0} | " +
            $"Total: {currentTotal} | Success: {successfulTransactions} | " +
            $"Failed: {failedTransactions} | P50: {p50}ms | P95: {p95}ms");
        
        // Detect recovery from failover
        if (failoverDetected && failoverEndTime == DateTime.MinValue && tps > (targetTps * 0.8))
        {
            failoverEndTime = DateTime.UtcNow;
            var rto = (failoverEndTime - failoverStartTime).TotalSeconds;
            Console.WriteLine($"✅ Failover recovered! RTO: {rto:F2} seconds");
        }
        
        lastTotal = currentTotal;
        lastTime = currentTime;
    }
}

// Start load test
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(testDurationSeconds));

// Start workers
var workerTasks = Enumerable.Range(0, workerCount)
    .Select(_ => Task.Run(() => Worker(cts.Token), cts.Token))
    .ToList();

// Start monitor
var monitorTask = Task.Run(() => Monitor(cts.Token), cts.Token);

Console.WriteLine($"✅ Started {workerCount} workers");
Console.WriteLine();

// Wait for completion
await Task.WhenAll(workerTasks.Concat(new[] { monitorTask }));

// Final report
Console.WriteLine();
Console.WriteLine("═══════════════════════════════════════════════════════");
Console.WriteLine("📊 FINAL RESULTS");
Console.WriteLine("═══════════════════════════════════════════════════════");
Console.WriteLine($"Total Transactions: {totalTransactions}");
Console.WriteLine($"Successful: {successfulTransactions}");
Console.WriteLine($"Failed: {failedTransactions}");
Console.WriteLine($"Success Rate: {(successfulTransactions * 100.0 / totalTransactions):F2}%");
Console.WriteLine($"Average TPS: {totalTransactions / (double)testDurationSeconds:F2}");

if (failoverDetected)
{
    var rto = failoverEndTime != DateTime.MinValue 
        ? (failoverEndTime - failoverStartTime).TotalSeconds 
        : -1;
    Console.WriteLine($"\n🔄 Failover Detected:");
    Console.WriteLine($"   Start: {failoverStartTime:HH:mm:ss.fff}");
    if (failoverEndTime != DateTime.MinValue)
    {
        Console.WriteLine($"   End: {failoverEndTime:HH:mm:ss.fff}");
        Console.WriteLine($"   RTO: {rto:F2} seconds");
    }
}
```

#### 4. **Deploy to Azure Container Instances**

```bash
# Create ACI with load generator
RG_NAME="rg-saif-pgsql-swc-01"
ACI_NAME="aci-loadgen-saif"
POSTGRES_SERVER="psql-saifpg-xxxxx"
POSTGRES_PASSWORD="YourPassword"

# Build connection string (using PgBouncer port 6432)
CONN_STRING="Host=${POSTGRES_SERVER}.postgres.database.azure.com;Port=6432;Database=saifdb;Username=saifadmin;Password=${POSTGRES_PASSWORD};SSL Mode=Require;Pooling=true;Minimum Pool Size=200;Maximum Pool Size=500;Connection Idle Lifetime=300"

# Create container instance
az container create \
    --resource-group $RG_NAME \
    --name $ACI_NAME \
    --image mcr.microsoft.com/dotnet/sdk:8.0 \
    --cpu 16 \
    --memory 32 \
    --restart-policy Never \
    --environment-variables \
        POSTGRES_CONNECTION_STRING="$CONN_STRING" \
        TARGET_TPS=8000 \
        WORKER_COUNT=200 \
        TEST_DURATION=300 \
    --command-line "/bin/bash -c 'apt-get update && apt-get install -y curl && curl -o LoadGenerator.csx https://raw.githubusercontent.com/YOUR-REPO/main/scripts/LoadGenerator.csx && dotnet script LoadGenerator.csx'"

# Monitor logs
az container logs --resource-group $RG_NAME --name $ACI_NAME --follow
```

### Performance Tuning Parameters

#### PostgreSQL Server Parameters (for 8000+ TPS)

```sql
-- Connection settings
ALTER SYSTEM SET max_connections = 2000;
ALTER SYSTEM SET superuser_reserved_connections = 10;

-- Memory settings (for Standard_E4ds_v5: 32GB RAM)
ALTER SYSTEM SET shared_buffers = '8GB';
ALTER SYSTEM SET effective_cache_size = '24GB';
ALTER SYSTEM SET work_mem = '16MB';
ALTER SYSTEM SET maintenance_work_mem = '2GB';

-- Write-ahead log
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM SET min_wal_size = '1GB';

-- Query planner
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Vacuum/Autovacuum (important for high write workloads)
ALTER SYSTEM SET autovacuum_max_workers = 4;
ALTER SYSTEM SET autovacuum_vacuum_cost_limit = 3000;

-- Reload configuration
SELECT pg_reload_conf();
```

### Expected Performance

| Metric | Expected Value |
|--------|---------------|
| **Sustained TPS** | 8,000-12,000 |
| **Peak TPS** | 15,000+ |
| **Latency (P50)** | 5-10ms |
| **Latency (P95)** | 20-30ms |
| **Failover RTO** | 60-90 seconds |
| **Failover RPO** | 0 seconds (synchronous replication) |

### Cost Estimate (Option 1)

| Component | SKU/Config | Monthly Cost | Notes |
|-----------|------------|--------------|-------|
| PostgreSQL Flexible Server | Standard_E4ds_v5 (Zone-Redundant) | ~$612 | 24/7 |
| Azure Container Instances | 16 vCPU, 32 GB, on-demand | ~$0.10/test | Only during tests |
| Storage (128 GB) | Included | Included | Part of PostgreSQL |
| **Total Monthly** | | **~$612-700** | Assuming daily 1-hour tests |

---

## ⚡ Option 2: Azure Kubernetes Service (AKS) with Distributed Load (HIGHEST PERFORMANCE)

**Expected TPS**: 20,000-50,000+ TPS  
**Cost**: ~$300-500/month (small cluster) | ~$1000+/month (production cluster)  
**Complexity**: High  
**Best For**: Continuous testing, production-grade validation, multi-scenario testing

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 AKS Cluster (Sweden Central)                     │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │           Load Generator Deployment (10-50 pods)          │  │
│  │                                                            │  │
│  │  Pod 1       Pod 2       Pod 3  ...  Pod N               │  │
│  │  ┌─────┐    ┌─────┐    ┌─────┐      ┌─────┐             │  │
│  │  │8 CPU│    │8 CPU│    │8 CPU│      │8 CPU│             │  │
│  │  │16 GB│    │16 GB│    │16 GB│      │16 GB│             │  │
│  │  │     │    │     │    │     │      │     │             │  │
│  │  │200  │    │200  │    │200  │      │200  │             │  │
│  │  │work-│    │work-│    │work-│      │work-│             │  │
│  │  │ers  │    │ers  │    │ers  │      │ers  │             │  │
│  │  └──┬──┘    └──┬──┘    └──┬──┘      └──┬──┘             │  │
│  │     │          │          │             │                │  │
│  └─────┼──────────┼──────────┼─────────────┼────────────────┘  │
│        │          │          │             │                   │
│        └──────────┴──────────┴─────────────┘                   │
│                            │                                    │
│                            │ 1-5ms latency                      │
│                            ▼                                    │
│  ┌───────────────────────────────────────────────────────┐     │
│  │      PostgreSQL with PgBouncer (Port 6432)            │     │
│  │      SKU: Standard_D32ds_v5 (32 vCore, 128 GB)        │     │
│  │      max_connections: 10,000                           │     │
│  └───────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘

Total Capacity: 10 pods × 2000 TPS/pod = 20,000 TPS
Scaled Capacity: 50 pods × 1000 TPS/pod = 50,000 TPS
```

### Key Advantages
- **Horizontal scaling**: Add more pods for more TPS
- **Distributed load**: No single point of bottleneck
- **Kubernetes orchestration**: Auto-scaling, health checks, self-healing
- **Production-grade**: Suitable for continuous integration/testing
- **Cost-effective at scale**: Per-pod cost decreases with larger clusters

### Implementation Complexity
- Requires AKS cluster setup and management
- Need Kubernetes expertise
- More moving parts (ingress, services, deployments)
- Best suited for teams already using Kubernetes

---

## 💰 Option 3: VM Scale Set with Multiple Test Runners (COST-OPTIMIZED)

**Expected TPS**: 5,000-10,000 TPS  
**Cost**: ~$400-600/month  
**Complexity**: Medium-Low  
**Best For**: Budget-conscious teams, less frequent testing

### Architecture

```
┌────────────────────────────────────────────────────────────┐
│           VM Scale Set (3-5 instances)                      │
│                                                             │
│  VM1 (D4s_v5)      VM2 (D4s_v5)      VM3 (D4s_v5)         │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐         │
│  │ 4 vCPU   │      │ 4 vCPU   │      │ 4 vCPU   │         │
│  │ 16 GB    │      │ 16 GB    │      │ 16 GB    │         │
│  │          │      │          │      │          │         │
│  │ 50-100   │      │ 50-100   │      │ 50-100   │         │
│  │ workers  │      │ workers  │      │ workers  │         │
│  │          │      │          │      │          │         │
│  │ ~2-3K TPS│      │ ~2-3K TPS│      │ ~2-3K TPS│         │
│  └────┬─────┘      └────┬─────┘      └────┬─────┘         │
│       │                 │                  │               │
│       └─────────────────┴──────────────────┘               │
│                         │                                  │
└─────────────────────────┼──────────────────────────────────┘
                          │
                          ▼
              PostgreSQL + PgBouncer
              (Standard_E8ds_v5)
```

### Key Features
- Use Azure Load Balancer to distribute trigger commands
- Each VM runs independent C# load generator
- Coordinate via Azure Storage Queue or Service Bus
- Simpler than AKS, more scalable than single ACI

---

## 📋 Comparison Matrix

| Criteria | Option 1: ACI | Option 2: AKS | Option 3: VM Scale Set |
|----------|---------------|---------------|------------------------|
| **Expected TPS** | 8,000-12,000 | 20,000-50,000+ | 5,000-10,000 |
| **Setup Complexity** | ⭐⭐ Medium | ⭐⭐⭐⭐ High | ⭐⭐⭐ Medium-High |
| **Monthly Cost** | $612-700 | $300-1000+ | $400-600 |
| **Scaling** | Manual (re-deploy) | Automatic (HPA) | Manual (scale set) |
| **Best For** | On-demand testing | Continuous/Production | Regular testing |
| **Maintenance** | Low | High | Medium |
| **Production Ready** | ✅ Yes (on-demand) | ✅ Yes (always-on) | ✅ Yes (scheduled) |

---

## 🎯 Recommended Implementation Path

### Phase 1: Quick Win (Week 1)
1. ✅ **Enable PgBouncer** (10 minutes)
   - Immediate improvement in connection handling
   - No code changes required
   - Connect on port 6432 instead of 5432

2. ✅ **Upgrade PostgreSQL SKU** to Standard_E4ds_v5 (30 minutes)
   - Required for 8000 TPS
   - Can scale up/down as needed

### Phase 2: Load Generator (Week 1-2)
3. ✅ **Create C# Load Generator Script** (2-3 hours)
   - Based on LoadGenerator.csx template above
   - Test locally first (will get ~500-1000 TPS)
   - Validate connection pooling works

4. ✅ **Deploy to Azure Container Instances** (1 hour)
   - Start with 8 vCPU, 16 GB
   - Scale up to 16 vCPU, 32 GB if needed
   - **This gets you to 8000 TPS target** ✅

### Phase 3: Optimization (Week 2-3)
5. ✅ **Tune PostgreSQL Parameters** (1-2 hours)
   - Apply recommended settings
   - Monitor with Azure Monitor
   - Adjust based on metrics

6. ✅ **Run Failover Tests** (ongoing)
   - Measure RTO/RPO
   - Document results
   - Create runbooks

---

## 📊 Quick Start Script

I'll create a complete deployment script for **Option 1 (ACI)** - the recommended approach:

```bash
#!/bin/bash
# Quick deployment script for 8000 TPS load testing

RG_NAME="rg-saif-pgsql-swc-01"
LOCATION="swedencentral"
POSTGRES_SERVER="psql-saifpg-xxxxx"  # Replace with your server name
POSTGRES_PASSWORD="YourSecurePassword"  # Replace with your password

echo "🚀 Deploying High-Performance Load Testing Infrastructure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Enable PgBouncer
echo "📍 Step 1/4: Enabling PgBouncer..."
az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name pgbouncer.enabled \
    --value on

# Step 2: Upgrade PostgreSQL SKU
echo "📍 Step 2/4: Upgrading PostgreSQL to Standard_E4ds_v5..."
az postgres flexible-server update \
    --resource-group $RG_NAME \
    --name $POSTGRES_SERVER \
    --sku-name Standard_E4ds_v5 \
    --tier MemoryOptimized

# Step 3: Update PostgreSQL parameters
echo "📍 Step 3/4: Optimizing PostgreSQL parameters..."
az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name max_connections \
    --value 2000

az postgres flexible-server parameter set \
    --resource-group $RG_NAME \
    --server-name $POSTGRES_SERVER \
    --name shared_buffers \
    --value 2097152  # 8GB in 8KB pages

# Step 4: Deploy load generator to ACI
echo "📍 Step 4/4: Deploying load generator..."

# Build connection string with PgBouncer port
CONN_STRING="Host=${POSTGRES_SERVER}.postgres.database.azure.com;Port=6432;Database=saifdb;Username=saifadmin;Password=${POSTGRES_PASSWORD};SSL Mode=Require;Pooling=true;Minimum Pool Size=200;Maximum Pool Size=500"

az container create \
    --resource-group $RG_NAME \
    --name "aci-loadgen-$(date +%s)" \
    --image mcr.microsoft.com/dotnet/sdk:8.0 \
    --cpu 16 \
    --memory 32 \
    --restart-policy Never \
    --environment-variables \
        POSTGRES_CONNECTION_STRING="$CONN_STRING" \
        TARGET_TPS=8000 \
        WORKER_COUNT=200 \
        TEST_DURATION=300 \
    --command-line "/bin/bash -c 'echo \"Load generator would start here\"'"

echo "✅ Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo "1. Upload LoadGenerator.csx to the container"
echo "2. Monitor with: az container logs --follow"
echo "3. Trigger failover and measure RTO"
```

---

## 🎓 Key Takeaways

1. **Your current bottleneck is the test client**, not PostgreSQL  
   → Solution: Deploy load generator in Azure (same region)

2. **PgBouncer is essential** for high connection counts  
   → Use built-in PgBouncer on port 6432

3. **PostgreSQL SKU upgrade is required** for 8000+ TPS  
   → Standard_E4ds_v5 minimum (4 vCore, 32 GB RAM)

4. **Parallel workers are mandatory** for high throughput  
   → 100-200 async workers minimum

5. **Network latency is critical**  
   → Deploy test client in same Azure region (<5ms RTT)

---

## 📞 Next Steps

Would you like me to:
1. ✅ Create the complete C# load generator script?
2. ✅ Update your Bicep template with the new PostgreSQL SKU?
3. ✅ Create a PowerShell wrapper to deploy and manage ACI tests?
4. ✅ Add monitoring/metrics collection to track TPS in real-time?

Let me know which option you'd like to pursue, and I'll provide the complete implementation!
