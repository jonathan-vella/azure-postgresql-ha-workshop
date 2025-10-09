<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SAIF Payment Gateway - PostgreSQL Demo</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="/assets/css/custom.css">
</head>
<body>
    <!-- Navigation -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container-fluid">
            <a class="navbar-brand" href="/">
                <img src="/assets/img/saif-logo.svg" alt="SAIF" height="30" class="d-inline-block align-text-top">
                SAIF Payment Gateway
            </a>
            <span class="badge bg-danger ms-2">PostgreSQL HA Demo</span>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link active" href="#dashboard">Dashboard</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#process-payment">Process Payment</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#transactions">Transactions</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="#diagnostics">Diagnostics</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <!-- Hero Section -->
    <div class="hero-section">
        <div class="container">
            <div class="row align-items-center">
                <div class="col-lg-6">
                    <h1 class="display-4 fw-bold">SAIF Payment Gateway</h1>
                    <p class="lead">Secure payment processing with Azure PostgreSQL Zone-Redundant HA</p>
                    <div class="d-flex gap-2 mt-4">
                        <span class="badge bg-success fs-6"><i class="bi bi-check-circle"></i> 99.99% Uptime SLA</span>
                        <span class="badge bg-info fs-6"><i class="bi bi-shield-check"></i> Zero Data Loss</span>
                        <span class="badge bg-warning text-dark fs-6"><i class="bi bi-lightning"></i> 60-120s RTO</span>
                    </div>
                </div>
                <div class="col-lg-6">
                    <img src="/assets/img/dashboard-illustration.svg" alt="Dashboard" class="img-fluid">
                </div>
            </div>
        </div>
    </div>

    <!-- Warning Banner -->
    <div class="alert alert-danger alert-dismissible fade show m-3" role="alert">
        <i class="bi bi-exclamation-triangle-fill"></i>
        <strong>Educational Demo Only!</strong> This application contains intentional security vulnerabilities for learning purposes.
        Never use in production or with real data.
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>

    <!-- Main Content -->
    <div class="container my-5">
        <!-- Dashboard Section -->
        <section id="dashboard" class="mb-5">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h2 class="mb-0"><i class="bi bi-speedometer2"></i> System Dashboard</h2>
                <div class="d-flex align-items-center gap-3">
                    <div class="d-flex align-items-center gap-2">
                        <label class="form-label mb-0 small" for="refresh-interval">Auto-Refresh:</label>
                        <select id="refresh-interval" class="form-select form-select-sm" style="width: auto;">
                            <option value="0">Off</option>
                            <option value="5">5 seconds</option>
                            <option value="10" selected>10 seconds</option>
                            <option value="30">30 seconds</option>
                            <option value="60">60 seconds</option>
                        </select>
                    </div>
                    <button id="manual-refresh" class="btn btn-sm btn-outline-primary">
                        <i class="bi bi-arrow-clockwise"></i> Refresh Now
                    </button>
                    <small class="text-muted">
                        Last updated: <span id="last-updated">Never</span>
                        <span id="refresh-indicator" class="badge bg-secondary ms-2" style="display:none;">
                            <span class="spinner-border spinner-border-sm" role="status"></span> Updating...
                        </span>
                    </small>
                </div>
            </div>
            
            <div class="row g-4">
                <!-- Health Status Card -->
                <div class="col-md-3">
                    <div class="card stat-card h-100">
                        <div class="card-body text-center">
                            <div class="stat-icon health-icon">
                                <i class="bi bi-heart-pulse"></i>
                            </div>
                            <h5 class="card-title">System Health</h5>
                            <p class="stat-value" id="health-status">Loading...</p>
                            <small class="text-muted">API Status</small>
                        </div>
                    </div>
                </div>

                <!-- Database Status Card -->
                <div class="col-md-3">
                    <div class="card stat-card h-100">
                        <div class="card-body text-center">
                            <div class="stat-icon db-icon">
                                <i class="bi bi-database"></i>
                            </div>
                            <h5 class="card-title">Database</h5>
                            <p class="stat-value" id="db-status">Loading...</p>
                            <small class="text-muted">PostgreSQL 16</small>
                        </div>
                    </div>
                </div>

                <!-- HA Status Card -->
                <div class="col-md-3">
                    <div class="card stat-card h-100">
                        <div class="card-body text-center">
                            <div class="stat-icon ha-icon">
                                <i class="bi bi-shield-check"></i>
                            </div>
                            <h5 class="card-title">High Availability</h5>
                            <p class="stat-value" id="ha-status">Loading...</p>
                            <small class="text-muted">Zone-Redundant</small>
                        </div>
                    </div>
                </div>

                <!-- Transaction Count Card -->
                <div class="col-md-3">
                    <div class="card stat-card h-100">
                        <div class="card-body text-center">
                            <div class="stat-icon tx-icon">
                                <i class="bi bi-graph-up"></i>
                            </div>
                            <h5 class="card-title">Transactions</h5>
                            <p class="stat-value" id="tx-count">Loading...</p>
                            <small class="text-muted">Total Processed</small>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Database Details -->
            <div class="card mt-4">
                <div class="card-header bg-primary text-white">
                    <h5 class="mb-0"><i class="bi bi-info-circle"></i> PostgreSQL Configuration</h5>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-6">
                            <table class="table table-sm">
                                <tr>
                                    <td><strong>Database Version:</strong></td>
                                    <td id="db-version">Loading...</td>
                                </tr>
                                <tr>
                                    <td><strong>HA Mode:</strong></td>
                                    <td><span class="badge bg-success">Zone-Redundant</span></td>
                                </tr>
                                <tr>
                                    <td><strong>Primary Zone:</strong></td>
                                    <td>Zone 1 (Sweden Central)</td>
                                </tr>
                                <tr>
                                    <td><strong>Standby Zone:</strong></td>
                                    <td>Zone 2 (Sweden Central)</td>
                                </tr>
                            </table>
                        </div>
                        <div class="col-md-6">
                            <table class="table table-sm">
                                <tr>
                                    <td><strong>RPO (Data Loss):</strong></td>
                                    <td><span class="badge bg-success">0 seconds</span></td>
                                </tr>
                                <tr>
                                    <td><strong>RTO (Failover Time):</strong></td>
                                    <td><span class="badge bg-info">60-120 seconds</span></td>
                                </tr>
                                <tr>
                                    <td><strong>SLA Uptime:</strong></td>
                                    <td><span class="badge bg-success">99.99%</span></td>
                                </tr>
                                <tr>
                                    <td><strong>Compute SKU:</strong></td>
                                    <td>Standard_D4ds_v5 (4 vCore)</td>
                                </tr>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Process Payment Section -->
        <section id="process-payment" class="mb-5">
            <h2 class="mb-4"><i class="bi bi-credit-card"></i> Process Payment</h2>
            
            <div class="card">
                <div class="card-body">
                    <form id="payment-form">
                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Customer ID <span class="text-danger">*</span></label>
                                <input type="number" class="form-control" id="customer-id" required value="1">
                                <small class="text-muted">Test IDs: 1-1000</small>
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Merchant ID <span class="text-danger">*</span></label>
                                <input type="number" class="form-control" id="merchant-id" required value="1">
                                <small class="text-muted">Test IDs: 1-100</small>
                            </div>
                        </div>
                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Amount ($) <span class="text-danger">*</span></label>
                                <input type="number" class="form-control" id="amount" required min="0.01" step="0.01" value="99.99">
                            </div>
                            <div class="col-md-6 mb-3">
                                <label class="form-label">Currency <span class="text-danger">*</span></label>
                                <select class="form-select" id="currency">
                                    <option value="USD" selected>USD</option>
                                    <option value="EUR">EUR</option>
                                    <option value="GBP">GBP</option>
                                    <option value="SEK">SEK</option>
                                </select>
                            </div>
                        </div>
                        <div class="mb-3">
                            <label class="form-label">Description</label>
                            <input type="text" class="form-control" id="description" placeholder="Payment for services">
                        </div>
                        <button type="submit" class="btn btn-primary btn-lg w-100">
                            <i class="bi bi-check-circle"></i> Process Payment
                        </button>
                    </form>
                    <div id="payment-result" class="mt-3"></div>
                </div>
            </div>
        </section>

        <!-- Transactions Section -->
        <section id="transactions" class="mb-5">
            <h2 class="mb-4"><i class="bi bi-list-ul"></i> Recent Transactions</h2>
            
            <div class="card">
                <div class="card-body">
                    <div class="mb-3">
                        <label class="form-label">Customer ID</label>
                        <div class="input-group">
                            <input type="number" class="form-control" id="search-customer-id" placeholder="Enter customer ID">
                            <button class="btn btn-primary" id="search-transactions">
                                <i class="bi bi-search"></i> Search
                            </button>
                            <button class="btn btn-secondary" id="load-recent-transactions">
                                <i class="bi bi-clock-history"></i> Recent (All)
                            </button>
                        </div>
                    </div>
                    <div id="transactions-list">
                        <p class="text-muted">Enter a customer ID or click "Recent" to view transactions</p>
                    </div>
                </div>
            </div>
        </section>

        <!-- Diagnostics Section (Vulnerable) -->
        <section id="diagnostics" class="mb-5">
            <h2 class="mb-4"><i class="bi bi-wrench"></i> Diagnostics & Testing</h2>
            
            <div class="alert alert-warning">
                <i class="bi bi-exclamation-triangle"></i>
                <strong>Security Warning:</strong> These diagnostic endpoints contain intentional vulnerabilities for educational purposes.
            </div>

            <div class="row g-4">
                <!-- SQL Injection Test -->
                <div class="col-md-6">
                    <div class="card h-100">
                        <div class="card-header bg-danger text-white">
                            <i class="bi bi-bug"></i> SQL Injection Test
                        </div>
                        <div class="card-body">
                            <p class="card-text">Test SQL injection vulnerability</p>
                            <div class="input-group mb-2">
                                <input type="text" class="form-control" id="sql-customer-id" placeholder="Customer ID or SQL payload">
                                <button class="btn btn-danger" id="test-sql-injection">Test</button>
                            </div>
                            <small class="text-muted">Try: <code>1 OR 1=1</code></small>
                            <div id="sql-result" class="mt-2"></div>
                        </div>
                    </div>
                </div>

                <!-- SSRF Test -->
                <div class="col-md-6">
                    <div class="card h-100">
                        <div class="card-header bg-danger text-white">
                            <i class="bi bi-bug"></i> SSRF Test
                        </div>
                        <div class="card-body">
                            <p class="card-text">Test Server-Side Request Forgery</p>
                            <div class="input-group mb-2">
                                <input type="text" class="form-control" id="curl-url" placeholder="URL to fetch">
                                <button class="btn btn-danger" id="test-ssrf">Test</button>
                            </div>
                            <small class="text-muted">Try: <code>http://169.254.169.254/latest/meta-data/</code></small>
                            <div id="ssrf-result" class="mt-2"></div>
                        </div>
                    </div>
                </div>

                <!-- Info Disclosure Test -->
                <div class="col-md-6">
                    <div class="card h-100">
                        <div class="card-header bg-danger text-white">
                            <i class="bi bi-bug"></i> Information Disclosure
                        </div>
                        <div class="card-body">
                            <p class="card-text">View environment variables</p>
                            <button class="btn btn-danger w-100" id="test-info-disclosure">View Environment</button>
                            <div id="env-result" class="mt-2"></div>
                        </div>
                    </div>
                </div>

                <!-- Load Test -->
                <div class="col-md-6">
                    <div class="card h-100">
                        <div class="card-header bg-success text-white">
                            <i class="bi bi-speedometer"></i> Load Testing
                        </div>
                        <div class="card-body">
                            <p class="card-text">Generate test transactions</p>
                            <div class="input-group mb-2">
                                <input type="number" class="form-control" id="load-count" placeholder="Count" value="10">
                                <button class="btn btn-success" id="run-load-test">Generate</button>
                            </div>
                            <small class="text-muted">Creates test transactions using stored function</small>
                            <div id="load-result" class="mt-2"></div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </div>

    <!-- Footer -->
    <footer class="bg-dark text-white text-center py-4 mt-5">
        <div class="container">
            <p class="mb-0">SAIF Payment Gateway - PostgreSQL Zone-Redundant HA Demo</p>
            <small class="text-muted">Educational purposes only • Contains intentional vulnerabilities</small>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/assets/js/custom.js?v=<?php echo time(); ?>"></script>
</body>
</html>
