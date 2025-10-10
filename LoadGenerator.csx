#!/usr/bin/env dotnet-script
#r "nuget: Npgsql, 8.0.3"
#r "nuget: System.Threading.Tasks.Dataflow, 8.0.0"

/*
 * High-Performance PostgreSQL Load Generator for Failover Testing
 * 
 * Features:
 * - 200+ parallel async workers
 * - Connection pooling with Npgsql
 * - Real-time TPS monitoring
 * - Failover detection and RTO measurement
 * - CSV metrics export
 * - P50/P95/P99 latency tracking
 * 
 * Environment Variables:
 * - POSTGRES_CONNECTION_STRING: PostgreSQL connection string (REQUIRED)
 * - TARGET_TPS: Target transactions per second (default: 8000)
 * - WORKER_COUNT: Number of parallel workers (default: 200)
 * - TEST_DURATION: Test duration in seconds (default: 300)
 * - OUTPUT_CSV: Path to CSV output file (default: ./loadtest_results.csv)
 * - ENABLE_VERBOSE: Enable verbose logging (default: false)
 * 
 * Usage:
 *   dotnet script LoadGenerator.csx
 * 
 * Example:
 *   export POSTGRES_CONNECTION_STRING="Host=server.postgres.database.azure.com;Port=6432;Database=saifdb;Username=admin;Password=xxx;SSL Mode=Require"
 *   export TARGET_TPS=8000
 *   export WORKER_COUNT=200
 *   export TEST_DURATION=300
 *   dotnet script LoadGenerator.csx
 */

using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Npgsql;

// ============================================================================
// MAIN ASYNC ENTRY POINT (Required for dotnet-script compatibility)
// ============================================================================

await Main();

    async Task<int> Main()
    {
    // ============================================================================
    // CONFIGURATION
    // ============================================================================

    var connectionString = Environment.GetEnvironmentVariable("POSTGRES_CONNECTION_STRING") 
        ?? throw new Exception("POSTGRES_CONNECTION_STRING environment variable is required");

    var targetTps = int.Parse(Environment.GetEnvironmentVariable("TARGET_TPS") ?? "8000");
    var workerCount = int.Parse(Environment.GetEnvironmentVariable("WORKER_COUNT") ?? "200");
    var testDurationSeconds = int.Parse(Environment.GetEnvironmentVariable("TEST_DURATION") ?? "300");
    var outputCsvPath = Environment.GetEnvironmentVariable("OUTPUT_CSV") ?? "./loadtest_results.csv";
    var enableVerbose = bool.Parse(Environment.GetEnvironmentVariable("ENABLE_VERBOSE") ?? "false");

    // ============================================================================
    // BANNER
    // ============================================================================

    Console.WriteLine("═══════════════════════════════════════════════════════════════");
    Console.WriteLine("🚀 HIGH-PERFORMANCE POSTGRESQL LOAD GENERATOR");
    Console.WriteLine("═══════════════════════════════════════════════════════════════");
    Console.WriteLine($"📅 Started at: {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC");
    Console.WriteLine($"🎯 Target TPS: {targetTps:N0}");
    Console.WriteLine($"👷 Workers: {workerCount}");
    Console.WriteLine($"⏱️  Duration: {testDurationSeconds}s ({TimeSpan.FromSeconds(testDurationSeconds):hh\\:mm\\:ss})");
    Console.WriteLine($"📊 CSV Output: {outputCsvPath}");
    Console.WriteLine($"🔌 Connection: {connectionString.Split(';').First()}...");
    Console.WriteLine("═══════════════════════════════════════════════════════════════");
    Console.WriteLine();

    // ============================================================================
    // CONNECTION POOL SETUP
    // ============================================================================

    Console.WriteLine("🔧 Configuring connection pool...");

    var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);

    // Connection pool settings optimized for high TPS
    var connStringBuilder = new NpgsqlConnectionStringBuilder(connectionString)
    {
        MaxPoolSize = workerCount + 100,              // Allow more connections than workers
        MinPoolSize = Math.Min(50, workerCount / 4),  // Pre-warm 25% of workers
        ConnectionIdleLifetime = 300,                  // 5 minutes idle lifetime
        ConnectionPruningInterval = 10,                // Prune every 10 seconds
        Timeout = 30,                                  // 30 second connection timeout
        CommandTimeout = 30,                           // 30 second command timeout
        MaxAutoPrepare = 20,                          // Auto-prepare frequently used statements
        AutoPrepareMinUsages = 5,                     // Prepare after 5 uses
        Pooling = true,                               // Enable pooling
        KeepAlive = 30,                               // TCP keepalive every 30 seconds
        TcpKeepAliveTime = 30,
        TcpKeepAliveInterval = 10
    };

    dataSourceBuilder = new NpgsqlDataSourceBuilder(connStringBuilder.ToString());
    await using var dataSource = dataSourceBuilder.Build();

    Console.WriteLine($"✅ Connection pool configured:");
    Console.WriteLine($"   Max Pool Size: {connStringBuilder.MaxPoolSize}");
    Console.WriteLine($"   Min Pool Size: {connStringBuilder.MinPoolSize}");
    Console.WriteLine($"   Pooling: {connStringBuilder.Pooling}");
    Console.WriteLine();

    // ============================================================================
    // METRICS TRACKING
    // ============================================================================

    // Counters
    var totalTransactions = 0L;
    var successfulTransactions = 0L;
    var failedTransactions = 0L;
    var connectionErrors = 0L;
    var timeoutErrors = 0L;
    var otherErrors = 0L;

    // Latency tracking (thread-safe)
    var latencies = new ConcurrentBag<long>();

    // Failover detection
    var failoverDetected = false;
    var failoverStartTime = DateTime.MinValue;
    var failoverEndTime = DateTime.MinValue;
    var failoverDuration = TimeSpan.Zero;

    // Per-second metrics for CSV export
    var metricsHistory = new ConcurrentBag<(DateTime timestamp, long tps, long total, long success, long failed, double p50, double p95, double p99)>();

    // Test start time
    var testStartTime = DateTime.UtcNow;

    // ============================================================================
    // WORKER FUNCTION
    // ============================================================================

    async Task Worker(int workerId, CancellationToken ct)
    {
    var workerTransactions = 0L;
    var workerErrors = 0L;
    
    if (enableVerbose)
    {
        Console.WriteLine($"[Worker {workerId:D3}] Started");
    }
    
    while (!ct.IsCancellationRequested)
    {
        var sw = Stopwatch.StartNew();
        var success = false;
        
        try
        {
            await using var conn = await dataSource.OpenConnectionAsync(ct);
            await using var cmd = new NpgsqlCommand(
                "INSERT INTO transactions (customer_id, merchant_id, amount, status) " +
                "VALUES (@customer_id, @merchant_id, @amount, 'completed') RETURNING transaction_id", 
                conn);
            
            cmd.Parameters.AddWithValue("customer_id", Random.Shared.Next(1, 1001));
            cmd.Parameters.AddWithValue("merchant_id", Random.Shared.Next(1, 101));
            cmd.Parameters.AddWithValue("amount", Random.Shared.Next(10, 10000) / 100.0m);
            
            var result = await cmd.ExecuteScalarAsync(ct);
            
            sw.Stop();
            Interlocked.Increment(ref successfulTransactions);
            latencies.Add(sw.ElapsedMilliseconds);
            success = true;
            workerTransactions++;
        }
        catch (OperationCanceledException)
        {
            // Test ended, exit gracefully
            break;
        }
        catch (NpgsqlException ex) when (ex.Message.Contains("connection") || ex.Message.Contains("Connection"))
        {
            sw.Stop();
            Interlocked.Increment(ref failedTransactions);
            Interlocked.Increment(ref connectionErrors);
            workerErrors++;
            
            // Detect failover start
            if (!failoverDetected && !ct.IsCancellationRequested)
            {
                lock (typeof(Program))
                {
                    if (!failoverDetected)
                    {
                        failoverDetected = true;
                        failoverStartTime = DateTime.UtcNow;
                        Console.WriteLine();
                        Console.WriteLine($"⚠️  FAILOVER DETECTED at {failoverStartTime:HH:mm:ss.fff}");
                        Console.WriteLine($"⚠️  Error: {ex.Message}");
                        Console.WriteLine();
                    }
                }
            }
            
            if (enableVerbose)
            {
                Console.WriteLine($"[Worker {workerId:D3}] Connection error: {ex.Message}");
            }
        }
        catch (TimeoutException ex)
        {
            sw.Stop();
            Interlocked.Increment(ref failedTransactions);
            Interlocked.Increment(ref timeoutErrors);
            workerErrors++;
            
            if (enableVerbose)
            {
                Console.WriteLine($"[Worker {workerId:D3}] Timeout: {ex.Message}");
            }
        }
        catch (Exception ex)
        {
            sw.Stop();
            Interlocked.Increment(ref failedTransactions);
            Interlocked.Increment(ref otherErrors);
            workerErrors++;
            
            if (enableVerbose)
            {
                Console.WriteLine($"[Worker {workerId:D3}] Error: {ex.GetType().Name}: {ex.Message}");
            }
        }
        finally
        {
            Interlocked.Increment(ref totalTransactions);
        }
        
        // Rate limiting (distribute target TPS across workers)
        if (targetTps > 0 && success)
        {
            var delayMs = (int)(1000.0 / (targetTps / (double)workerCount));
            if (delayMs > 0 && delayMs < 1000)
            {
                await Task.Delay(delayMs, ct);
            }
        }
    }
    
    if (enableVerbose)
    {
        Console.WriteLine($"[Worker {workerId:D3}] Finished: {workerTransactions} transactions, {workerErrors} errors");
    }
    }

    // ============================================================================
    // MONITORING FUNCTION
    // ============================================================================

    async Task Monitor(CancellationToken ct)
    {
    var lastTotal = 0L;
    var lastTime = DateTime.UtcNow;
    var secondCounter = 0;
    
    Console.WriteLine("📊 Real-time Metrics (updates every second)");
    Console.WriteLine("─────────────────────────────────────────────────────────────────────────────────────────────────────");
    Console.WriteLine($"{"Time",-12} {"TPS",-8} {"Total",-10} {"Success",-10} {"Failed",-8} {"P50",6} {"P95",6} {"P99",6} Status");
    Console.WriteLine("─────────────────────────────────────────────────────────────────────────────────────────────────────");
    
    while (!ct.IsCancellationRequested)
    {
        await Task.Delay(1000, ct);
        
        var currentTotal = Interlocked.Read(ref totalTransactions);
        var currentSuccess = Interlocked.Read(ref successfulTransactions);
        var currentFailed = Interlocked.Read(ref failedTransactions);
        var currentTime = DateTime.UtcNow;
        var elapsed = (currentTime - lastTime).TotalSeconds;
        var tps = (long)((currentTotal - lastTotal) / elapsed);
        
        // Calculate percentiles
        var lats = latencies.ToArray();
        var p50 = 0.0;
        var p95 = 0.0;
        var p99 = 0.0;
        
        if (lats.Length > 0)
        {
            var sorted = lats.OrderBy(x => x).ToArray();
            p50 = sorted[sorted.Length / 2];
            p95 = sorted[Math.Min((int)(sorted.Length * 0.95), sorted.Length - 1)];
            p99 = sorted[Math.Min((int)(sorted.Length * 0.99), sorted.Length - 1)];
        }
        
        // Status indicator
        var status = "🟢 OK";
        if (failoverDetected && failoverEndTime == DateTime.MinValue)
        {
            status = "🔴 FAILOVER";
        }
        else if (failoverDetected && failoverEndTime != DateTime.MinValue)
        {
            status = "🟡 RECOVERED";
        }
        else if (tps < targetTps * 0.5)
        {
            status = "🟡 LOW TPS";
        }
        
        // Print metrics
        Console.WriteLine(
            $"{currentTime:HH:mm:ss.fff} {tps,7:N0} {currentTotal,9:N0} {currentSuccess,9:N0} {currentFailed,7:N0} " +
            $"{p50,5:F0}ms {p95,5:F0}ms {p99,5:F0}ms {status}");
        
        // Record metrics for CSV
        metricsHistory.Add((currentTime, tps, currentTotal, currentSuccess, currentFailed, p50, p95, p99));
        
        // Detect recovery from failover
        if (failoverDetected && failoverEndTime == DateTime.MinValue && tps > (targetTps * 0.8))
        {
            failoverEndTime = DateTime.UtcNow;
            failoverDuration = failoverEndTime - failoverStartTime;
            
            Console.WriteLine("─────────────────────────────────────────────────────────────────────────────────────────────────────");
            Console.WriteLine($"✅ FAILOVER RECOVERED at {failoverEndTime:HH:mm:ss.fff}");
            Console.WriteLine($"✅ RTO (Recovery Time Objective): {failoverDuration.TotalSeconds:F2} seconds");
            Console.WriteLine("─────────────────────────────────────────────────────────────────────────────────────────────────────");
        }
        
        lastTotal = currentTotal;
        lastTime = currentTime;
        secondCounter++;
    }
    }

    // ============================================================================
    // START LOAD TEST
    // ============================================================================

    Console.WriteLine("🏁 Starting load test...");
    Console.WriteLine();

    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(testDurationSeconds));

    // Start all workers
    var workerTasks = Enumerable.Range(0, workerCount)
    .Select(i => Task.Run(() => Worker(i, cts.Token), cts.Token))
    .ToList();

    // Start monitoring
    var monitorTask = Task.Run(() => Monitor(cts.Token), cts.Token);

    Console.WriteLine($"✅ Started {workerCount} workers");
    Console.WriteLine();

    // Wait for completion or cancellation
    try
    {
    await Task.WhenAll(workerTasks.Concat(new[] { monitorTask }));
    }
    catch (OperationCanceledException)
    {
    // Expected when test duration expires
    }

    var testEndTime = DateTime.UtcNow;
    var totalTestDuration = testEndTime - testStartTime;

    // ============================================================================
    // FINAL RESULTS
    // ============================================================================

    Console.WriteLine();
    Console.WriteLine("═══════════════════════════════════════════════════════════════");
    Console.WriteLine("📊 FINAL RESULTS");
    Console.WriteLine("═══════════════════════════════════════════════════════════════");
    Console.WriteLine($"⏱️  Test Duration: {totalTestDuration.TotalSeconds:F2}s");
    Console.WriteLine($"📅 Completed at: {testEndTime:yyyy-MM-dd HH:mm:ss} UTC");
    Console.WriteLine();

    Console.WriteLine("📈 Transaction Summary:");
    Console.WriteLine($"   Total Transactions: {totalTransactions:N0}");
    Console.WriteLine($"   Successful: {successfulTransactions:N0} ({(successfulTransactions * 100.0 / Math.Max(1, totalTransactions)):F2}%)");
    Console.WriteLine($"   Failed: {failedTransactions:N0} ({(failedTransactions * 100.0 / Math.Max(1, totalTransactions)):F2}%)");
    Console.WriteLine($"   Average TPS: {(totalTransactions / totalTestDuration.TotalSeconds):F2}");
    Console.WriteLine();

    Console.WriteLine("❌ Error Breakdown:");
    Console.WriteLine($"   Connection Errors: {connectionErrors:N0}");
    Console.WriteLine($"   Timeout Errors: {timeoutErrors:N0}");
    Console.WriteLine($"   Other Errors: {otherErrors:N0}");
    Console.WriteLine();

    // Calculate final percentiles
    var finalLats = latencies.ToArray();
    if (finalLats.Length > 0)
    {
    var sorted = finalLats.OrderBy(x => x).ToArray();
    var p50 = sorted[sorted.Length / 2];
    var p95 = sorted[Math.Min((int)(sorted.Length * 0.95), sorted.Length - 1)];
    var p99 = sorted[Math.Min((int)(sorted.Length * 0.99), sorted.Length - 1)];
    var p999 = sorted[Math.Min((int)(sorted.Length * 0.999), sorted.Length - 1)];
    var min = sorted[0];
    var max = sorted[sorted.Length - 1];
    var avg = sorted.Average();
    
    Console.WriteLine("⚡ Latency Statistics:");
    Console.WriteLine($"   Min: {min}ms");
    Console.WriteLine($"   Average: {avg:F2}ms");
    Console.WriteLine($"   P50 (Median): {p50}ms");
    Console.WriteLine($"   P95: {p95}ms");
    Console.WriteLine($"   P99: {p99}ms");
    Console.WriteLine($"   P99.9: {p999}ms");
    Console.WriteLine($"   Max: {max}ms");
    Console.WriteLine();
    }

    if (failoverDetected)
    {
    Console.WriteLine("🔄 Failover Analysis:");
    Console.WriteLine($"   Failover Start: {failoverStartTime:yyyy-MM-dd HH:mm:ss.fff} UTC");
    
    if (failoverEndTime != DateTime.MinValue)
    {
        Console.WriteLine($"   Failover End: {failoverEndTime:yyyy-MM-dd HH:mm:ss.fff} UTC");
        Console.WriteLine($"   RTO (Recovery Time): {failoverDuration.TotalSeconds:F2} seconds");
        Console.WriteLine($"   Transactions Lost: {failedTransactions:N0}");
        Console.WriteLine($"   Recovery Status: ✅ RECOVERED");
    }
    else
    {
        Console.WriteLine($"   Recovery Status: ⚠️  NOT RECOVERED (test ended during failover)");
    }
    Console.WriteLine();
    }

    // ============================================================================
    // EXPORT TO CSV
    // ============================================================================

    Console.WriteLine($"💾 Exporting metrics to CSV: {outputCsvPath}");

    try
    {
    var csv = new StringBuilder();
    csv.AppendLine("Timestamp,ElapsedSeconds,TPS,TotalTransactions,SuccessfulTransactions,FailedTransactions,P50_Latency_ms,P95_Latency_ms,P99_Latency_ms");
    
    foreach (var metric in metricsHistory.OrderBy(m => m.timestamp))
    {
        var elapsed = (metric.timestamp - testStartTime).TotalSeconds;
        csv.AppendLine($"{metric.timestamp:yyyy-MM-dd HH:mm:ss.fff},{elapsed:F3},{metric.tps},{metric.total},{metric.success},{metric.failed},{metric.p50:F2},{metric.p95:F2},{metric.p99:F2}");
    }
    
    await File.WriteAllTextAsync(outputCsvPath, csv.ToString());
    Console.WriteLine($"✅ Metrics exported successfully");
    Console.WriteLine($"   Total data points: {metricsHistory.Count}");
    }
    catch (Exception ex)
    {
    Console.WriteLine($"❌ Failed to export CSV: {ex.Message}");
    }

    Console.WriteLine();
    Console.WriteLine("═══════════════════════════════════════════════════════════════");
    Console.WriteLine("✅ LOAD TEST COMPLETED");
    Console.WriteLine("═══════════════════════════════════════════════════════════════");

    // Exit with success code if we met our target
    var avgTps = totalTransactions / totalTestDuration.TotalSeconds;
    var exitCode = avgTps >= (targetTps * 0.8) ? 0 : 1;
    
    return exitCode;
} // End of Main()