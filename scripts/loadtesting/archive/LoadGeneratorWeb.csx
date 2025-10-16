#!/usr/bin/env dotnet-script
// LoadGenerator Web Server Wrapper
// Provides HTTP endpoints to trigger and monitor load tests

#r "nuget: Npgsql, 8.0.0"
#r "nuget: Microsoft.AspNetCore.App.Ref, 8.0.0"

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Hosting;
using Npgsql;

// Global state for test execution
class TestState
{
    public bool IsRunning;
    public string Status = "idle";
    public DateTime StartTime;
    public long TransactionsCompleted;
    public long Errors;
    public List<string> Logs = new();
}

var testState = new TestState();

// Function to run load test
async Task RunLoadTest(string server, int port, string database, string username, string password, int targetTps, int workerCount, int testDuration)
{
    testState.IsRunning = true;
    testState.Status = "running";
    testState.StartTime = DateTime.UtcNow;
    testState.TransactionsCompleted = 0;
    testState.Errors = 0;
    testState.Logs.Clear();

    testState.Logs.Add($"Starting load test: {targetTps} TPS, {workerCount} workers, {testDuration}s duration");

    try
    {
        var connectionString = $"Host={server};Port={port};Database={database};Username={username};Password={password};SSL Mode=Require";
        
        using (var connection = new NpgsqlConnection(connectionString))
        {
            await connection.OpenAsync();
            testState.Logs.Add("✓ Connected to PostgreSQL");
        }

        // Simulate load test
        var tasks = new List<Task>();
        var cts = new CancellationTokenSource(TimeSpan.FromSeconds(testDuration));
        var stopwatch = Stopwatch.StartNew();

        for (int w = 0; w < workerCount; w++)
        {
            var worker = async () =>
            {
                while (!cts.Token.IsCancellationRequested)
                {
                    try
                    {
                        using (var conn = new NpgsqlConnection(connectionString))
                        {
                            await conn.OpenAsync();
                            using (var cmd = conn.CreateCommand())
                            {
                                cmd.CommandText = "SELECT 1";
                                await cmd.ExecuteScalarAsync();
                                Interlocked.Increment(ref testState.TransactionsCompleted);
                            }
                        }

                        // Rate limiting for target TPS
                        await Task.Delay(1);
                    }
                    catch
                    {
                        Interlocked.Increment(ref testState.Errors);
                    }
                }
            };

            tasks.Add(worker());
        }

        await Task.WhenAll(tasks);
        stopwatch.Stop();

        var tps = testState.TransactionsCompleted / stopwatch.Elapsed.TotalSeconds;
        testState.Logs.Add($"✓ Load test completed");
        testState.Logs.Add($"  Transactions: {testState.TransactionsCompleted}");
        testState.Logs.Add($"  Errors: {testState.Errors}");
        testState.Logs.Add($"  TPS: {tps:F2}");
        testState.Status = "completed";
    }
    catch (Exception ex)
    {
        testState.Logs.Add($"✗ Error: {ex.Message}");
        testState.Status = "failed";
    }
    finally
    {
        testState.IsRunning = false;
    }
}

// Build web app
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Health check endpoint
app.MapGet("/health", () => Results.Ok("healthy"));

// Status endpoint
app.MapGet("/status", () => new
{
    running = testState.IsRunning,
    status = testState.Status,
    startTime = testState.StartTime,
    transactionsCompleted = testState.TransactionsCompleted,
    errors = testState.Errors,
    uptime = DateTime.UtcNow - testState.StartTime,
    logs = testState.Logs
});

// Start test endpoint
app.MapPost("/start", async (HttpContext context) =>
{
    if (testState.IsRunning)
    {
        return Results.BadRequest("Test already running");
    }

    var server = Environment.GetEnvironmentVariable("POSTGRESQL_SERVER") ?? "localhost";
    var port = int.TryParse(Environment.GetEnvironmentVariable("POSTGRESQL_PORT"), out var p) ? p : 5432;
    var database = Environment.GetEnvironmentVariable("POSTGRESQL_DATABASE") ?? "postgres";
    var username = Environment.GetEnvironmentVariable("POSTGRESQL_USERNAME") ?? "postgres";
    var password = Environment.GetEnvironmentVariable("POSTGRESQL_PASSWORD") ?? "";
    var tps = int.TryParse(Environment.GetEnvironmentVariable("TARGET_TPS"), out var t) ? t : 100;
    var workers = int.TryParse(Environment.GetEnvironmentVariable("WORKER_COUNT"), out var w) ? w : 10;
    var duration = int.TryParse(Environment.GetEnvironmentVariable("TEST_DURATION"), out var d) ? d : 60;

    // Run in background
    _ = RunLoadTest(server, port, database, username, password, tps, workers, duration);

    return Results.Accepted();
});

// Logs endpoint
app.MapGet("/logs", () => testState.Logs);

// Start web server
var port = Environment.GetEnvironmentVariable("PORT") ?? "80";
app.Run($"http://0.0.0.0:{port}");
