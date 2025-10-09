// SAIF Payment Gateway - PostgreSQL HA Demo
// API Configuration

const API_BASE_URL = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    ? 'http://localhost:8000'
    : `${window.location.protocol}//${window.location.hostname.replace('web-', 'api-')}`;

// Helper Functions
function showAlert(message, type = 'info') {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    document.body.insertBefore(alertDiv, document.body.firstChild);
    
    setTimeout(() => {
        alertDiv.remove();
    }, 5000);
}

function formatCurrency(amount, currency = 'USD') {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: currency
    }).format(amount);
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(date);
}

// Dashboard Functions
let refreshIntervalId = null;

async function loadDashboard() {
    // Show refresh indicator
    const indicator = document.getElementById('refresh-indicator');
    if (indicator) {
        indicator.style.display = 'inline-block';
    }
    
    try {
        // Health Check
        const healthResponse = await fetch(`${API_BASE_URL}/api/healthcheck`);
        const healthData = await healthResponse.json();
        
        document.getElementById('health-status').innerHTML = healthData.status === 'healthy'
            ? '<span class="text-success">✓ Healthy</span>'
            : '<span class="text-danger">✗ Unhealthy</span>';
        
        document.getElementById('db-status').innerHTML = healthData.database === 'connected'
            ? '<span class="text-success">✓ Connected</span>'
            : '<span class="text-danger">✗ Disconnected</span>';
        
        // Database Status
        const dbStatusResponse = await fetch(`${API_BASE_URL}/api/db-status`);
        const dbStatusData = await dbStatusResponse.json();
        
        document.getElementById('db-version').textContent = dbStatusData.version || 'PostgreSQL 16';
        document.getElementById('tx-count').textContent = (dbStatusData.transaction_count || 0).toLocaleString();
        
        // HA Status (simulated - would need Azure API integration)
        document.getElementById('ha-status').innerHTML = '<span class="text-success">✓ Healthy</span>';
        
        // Update last updated timestamp
        updateLastUpdatedTime();
        
    } catch (error) {
        console.error('Dashboard load error:', error);
        document.getElementById('health-status').innerHTML = '<span class="text-danger">✗ Error</span>';
        document.getElementById('db-status').innerHTML = '<span class="text-danger">✗ Error</span>';
    } finally {
        // Hide refresh indicator
        if (indicator) {
            indicator.style.display = 'none';
        }
    }
}

function updateLastUpdatedTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit',
        hour12: false
    });
    const lastUpdatedElement = document.getElementById('last-updated');
    if (lastUpdatedElement) {
        lastUpdatedElement.textContent = timeString;
    }
}

function setupAutoRefresh() {
    const intervalSelect = document.getElementById('refresh-interval');
    const manualRefreshBtn = document.getElementById('manual-refresh');
    
    // Handle interval change
    if (intervalSelect) {
        intervalSelect.addEventListener('change', (e) => {
            const seconds = parseInt(e.target.value);
            
            // Clear existing interval
            if (refreshIntervalId) {
                clearInterval(refreshIntervalId);
                refreshIntervalId = null;
            }
            
            // Set new interval if not 0
            if (seconds > 0) {
                refreshIntervalId = setInterval(loadDashboard, seconds * 1000);
                showAlert(`Auto-refresh set to ${seconds} seconds`, 'success');
            } else {
                showAlert('Auto-refresh disabled', 'info');
            }
        });
    }
    
    // Handle manual refresh button
    if (manualRefreshBtn) {
        manualRefreshBtn.addEventListener('click', () => {
            loadDashboard();
            showAlert('Dashboard refreshed', 'success');
        });
    }
}

// Payment Processing
document.getElementById('payment-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const customerId = document.getElementById('customer-id').value;
    const merchantId = document.getElementById('merchant-id').value;
    const amount = parseFloat(document.getElementById('amount').value);
    const currency = document.getElementById('currency').value;
    const description = document.getElementById('description').value;
    
    const resultDiv = document.getElementById('payment-result');
    resultDiv.innerHTML = '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Processing...</span></div>';
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/payments/process`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': 'demo_api_key_12345'
            },
            body: JSON.stringify({
                customer_id: parseInt(customerId),
                merchant_id: parseInt(merchantId),
                amount: amount,
                currency: currency,
                description: description
            })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            resultDiv.innerHTML = `
                <div class="alert alert-success">
                    <h5><i class="bi bi-check-circle"></i> Payment Successful!</h5>
                    <p><strong>Transaction ID:</strong> ${data.transaction_id}</p>
                    <p><strong>Amount:</strong> ${formatCurrency(amount, currency)}</p>
                    <p><strong>Status:</strong> ${data.status}</p>
                    <p><strong>Timestamp:</strong> ${formatDate(data.transaction_date)}</p>
                </div>
            `;
            
            // Refresh dashboard
            loadDashboard();
        } else {
            resultDiv.innerHTML = `
                <div class="alert alert-danger">
                    <h5><i class="bi bi-x-circle"></i> Payment Failed</h5>
                    <p>${data.detail || 'An error occurred'}</p>
                </div>
            `;
        }
    } catch (error) {
        console.error('Payment error:', error);
        resultDiv.innerHTML = `
            <div class="alert alert-danger">
                <h5><i class="bi bi-x-circle"></i> Payment Failed</h5>
                <p>Network error or API unavailable</p>
            </div>
        `;
    }
});

// Transaction Search
document.getElementById('search-transactions').addEventListener('click', async () => {
    const customerId = document.getElementById('search-customer-id').value;
    
    if (!customerId) {
        showAlert('Please enter a customer ID', 'warning');
        return;
    }
    
    const listDiv = document.getElementById('transactions-list');
    listDiv.innerHTML = '<div class="spinner-border text-primary" role="status"></div>';
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/customer/${customerId}/transactions`);
        const data = await response.json();
        
        if (response.ok && data.transactions && data.transactions.length > 0) {
            let html = `
                <h5>Transactions for Customer #${customerId}</h5>
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Date</th>
                                <th>Merchant</th>
                                <th>Amount</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
            `;
            
            data.transactions.forEach(tx => {
                const statusClass = tx.status === 'completed' ? 'success' : tx.status === 'failed' ? 'danger' : 'warning';
                html += `
                    <tr>
                        <td>#${tx.id}</td>
                        <td>${formatDate(tx.created_at)}</td>
                        <td>${tx.merchant_name || 'N/A'}</td>
                        <td>${formatCurrency(tx.amount, tx.currency)}</td>
                        <td><span class="badge bg-${statusClass}">${tx.status}</span></td>
                    </tr>
                `;
            });
            
            html += '</tbody></table></div>';
            listDiv.innerHTML = html;
        } else {
            listDiv.innerHTML = `
                <div class="alert alert-info">
                    <i class="bi bi-info-circle"></i> No transactions found for customer #${customerId}
                </div>
            `;
        }
    } catch (error) {
        console.error('Transaction search error:', error);
        listDiv.innerHTML = `
            <div class="alert alert-danger">
                <i class="bi bi-x-circle"></i> Failed to load transactions
            </div>
        `;
    }
});

// Load Recent Transactions
document.getElementById('load-recent-transactions').addEventListener('click', async () => {
    const listDiv = document.getElementById('transactions-list');
    listDiv.innerHTML = '<div class="spinner-border text-primary" role="status"></div>';
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/transactions/recent?limit=20`);
        const data = await response.json();
        
        if (response.ok && data.transactions && data.transactions.length > 0) {
            let html = `
                <h5>Recent Transactions (Last 20)</h5>
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Date</th>
                                <th>Customer</th>
                                <th>Merchant</th>
                                <th>Amount</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
            `;
            
            data.transactions.forEach(tx => {
                const statusClass = tx.status === 'completed' ? 'success' : tx.status === 'failed' ? 'danger' : 'warning';
                html += `
                    <tr>
                        <td>#${tx.id}</td>
                        <td>${formatDate(tx.created_at)}</td>
                        <td>#${tx.customer_id}</td>
                        <td>#${tx.merchant_id}</td>
                        <td>${formatCurrency(tx.amount, tx.currency)}</td>
                        <td><span class="badge bg-${statusClass}">${tx.status}</span></td>
                    </tr>
                `;
            });
            
            html += '</tbody></table></div>';
            listDiv.innerHTML = html;
        } else {
            listDiv.innerHTML = `
                <div class="alert alert-info">
                    <i class="bi bi-info-circle"></i> No transactions found
                </div>
            `;
        }
    } catch (error) {
        console.error('Recent transactions error:', error);
        listDiv.innerHTML = `
            <div class="alert alert-danger">
                <i class="bi bi-x-circle"></i> Failed to load transactions
            </div>
        `;
    }
});

// Diagnostics - SQL Injection Test
document.getElementById('test-sql-injection').addEventListener('click', async () => {
    const customerId = document.getElementById('sql-customer-id').value;
    const resultDiv = document.getElementById('sql-result');
    
    resultDiv.innerHTML = '<div class="spinner-border spinner-border-sm text-danger" role="status"></div>';
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/sqlversion`, {
            headers: { 'X-API-Key': 'demo_api_key_12345' }
        });
        const data = await response.json();
        
        resultDiv.innerHTML = `
            <div class="alert alert-warning mt-2">
                <pre class="mb-0">${JSON.stringify(data, null, 2)}</pre>
            </div>
        `;
    } catch (error) {
        resultDiv.innerHTML = `<div class="alert alert-danger mt-2">Error: ${error.message}</div>`;
    }
});

// Diagnostics - SSRF Test
document.getElementById('test-ssrf').addEventListener('click', async () => {
    const url = document.getElementById('curl-url').value;
    const resultDiv = document.getElementById('ssrf-result');
    
    if (!url) {
        showAlert('Please enter a URL', 'warning');
        return;
    }
    
    resultDiv.innerHTML = '<div class="spinner-border spinner-border-sm text-danger" role="status"></div>';
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/curl?url=${encodeURIComponent(url)}`);
        const data = await response.json();
        
        resultDiv.innerHTML = `
            <div class="alert alert-warning mt-2">
                <pre class="mb-0" style="max-height: 200px; overflow-y: auto;">${JSON.stringify(data, null, 2)}</pre>
            </div>
        `;
    } catch (error) {
        resultDiv.innerHTML = `<div class="alert alert-danger mt-2">Error: ${error.message}</div>`;
    }
});

// Diagnostics - Info Disclosure
document.getElementById('test-info-disclosure').addEventListener('click', async () => {
    const resultDiv = document.getElementById('env-result');
    
    resultDiv.innerHTML = '<div class="spinner-border spinner-border-sm text-danger" role="status"></div>';
    
    try {
        const response = await fetch(`${API_BASE_URL}/api/printenv`, {
            headers: { 'X-API-Key': 'demo_api_key_12345' }
        });
        const data = await response.json();
        
        resultDiv.innerHTML = `
            <div class="alert alert-warning mt-2">
                <pre class="mb-0" style="max-height: 200px; overflow-y: auto;">${JSON.stringify(data, null, 2)}</pre>
            </div>
        `;
    } catch (error) {
        resultDiv.innerHTML = `<div class="alert alert-danger mt-2">Error: ${error.message}</div>`;
    }
});

// Load Test
document.getElementById('run-load-test').addEventListener('click', async () => {
    const count = parseInt(document.getElementById('load-count').value) || 10;
    const resultDiv = document.getElementById('load-result');
    
    resultDiv.innerHTML = '<div class="spinner-border spinner-border-sm text-success" role="status"></div>';
    
    try {
        const promises = [];
        for (let i = 0; i < count; i++) {
            promises.push(
                fetch(`${API_BASE_URL}/api/test/create-transaction`, { method: 'POST' })
            );
        }
        
        const startTime = Date.now();
        await Promise.all(promises);
        const duration = Date.now() - startTime;
        const tps = (count / (duration / 1000)).toFixed(2);
        
        resultDiv.innerHTML = `
            <div class="alert alert-success mt-2">
                <p class="mb-0"><strong>✓ Generated ${count} transactions</strong></p>
                <small>Duration: ${duration}ms | TPS: ${tps}</small>
            </div>
        `;
        
        // Refresh dashboard
        loadDashboard();
    } catch (error) {
        resultDiv.innerHTML = `<div class="alert alert-danger mt-2">Error: ${error.message}</div>`;
    }
});

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', () => {
    // Initial load
    loadDashboard();
    
    // Setup auto-refresh controls
    setupAutoRefresh();
    
    // Start auto-refresh with default interval (10 seconds)
    const defaultInterval = document.getElementById('refresh-interval');
    if (defaultInterval && defaultInterval.value) {
        const seconds = parseInt(defaultInterval.value);
        if (seconds > 0) {
            refreshIntervalId = setInterval(loadDashboard, seconds * 1000);
        }
    }
});
