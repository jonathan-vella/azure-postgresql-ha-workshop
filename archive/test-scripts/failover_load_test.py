"""
PostgreSQL Failover Load Test with Write Operations

This script generates continuous write load to PostgreSQL and measures
failover timing during a planned failover operation.

Usage:
    python tests/failover_load_test.py

Required environment variables:
    POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DATABASE, 
    POSTGRES_USERNAME, POSTGRES_PASSWORD, POSTGRES_SSL

Before running:
1. Ensure your PostgreSQL Flexible Server has zone-redundant HA enabled
2. The server must be General Purpose or Memory Optimized tier (not Burstable)
3. Set all required environment variables
"""

import asyncio
import os
import sys
import time
from datetime import datetime
from typing import Dict, List
import statistics

from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError, DatabaseError
from sqlmodel import Session, select

# Add parent directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from fastapi_app.models import InfoRequest, Cruise, engine as default_engine


class FailoverMetrics:
    """Track metrics during failover testing"""
    
    def __init__(self):
        self.write_attempts: List[Dict] = []
        self.connection_failures: List[Dict] = []
        self.successful_writes: int = 0
        self.failed_writes: int = 0
        self.start_time: datetime = None
        self.first_failure_time: datetime = None
        self.last_failure_time: datetime = None
        self.first_recovery_time: datetime = None
        self.test_running: bool = True
        
    def record_write_attempt(self, success: bool, duration_ms: float, error: str = None):
        """Record a write attempt with timestamp"""
        timestamp = datetime.now()
        
        self.write_attempts.append({
            'timestamp': timestamp,
            'success': success,
            'duration_ms': duration_ms,
            'error': error
        })
        
        if success:
            self.successful_writes += 1
            if self.first_failure_time and not self.first_recovery_time:
                self.first_recovery_time = timestamp
                print(f"\n✅ [RECOVERY DETECTED] First successful write after failure at {timestamp.isoformat()}")
        else:
            self.failed_writes += 1
            if not self.first_failure_time:
                self.first_failure_time = timestamp
                print(f"\n❌ [FAILURE DETECTED] First write failure at {timestamp.isoformat()}")
            self.last_failure_time = timestamp
    
    def get_failover_duration_seconds(self) -> float:
        """Calculate failover duration from first failure to first recovery"""
        if self.first_failure_time and self.first_recovery_time:
            delta = self.first_recovery_time - self.first_failure_time
            return delta.total_seconds()
        return None
    
    def get_summary(self) -> Dict:
        """Get summary statistics"""
        failover_duration = self.get_failover_duration_seconds()
        
        successful_durations = [
            w['duration_ms'] for w in self.write_attempts if w['success']
        ]
        
        return {
            'total_attempts': len(self.write_attempts),
            'successful_writes': self.successful_writes,
            'failed_writes': self.failed_writes,
            'success_rate': (self.successful_writes / len(self.write_attempts) * 100) if self.write_attempts else 0,
            'test_start_time': self.start_time.isoformat() if self.start_time else None,
            'first_failure_time': self.first_failure_time.isoformat() if self.first_failure_time else None,
            'first_recovery_time': self.first_recovery_time.isoformat() if self.first_recovery_time else None,
            'failover_duration_seconds': failover_duration,
            'avg_write_duration_ms': statistics.mean(successful_durations) if successful_durations else None,
            'median_write_duration_ms': statistics.median(successful_durations) if successful_durations else None,
        }


class FailoverLoadTester:
    """Generate write load and measure failover timing"""
    
    def __init__(self, num_workers: int = 10, writes_per_second: int = 50):
        self.num_workers = num_workers
        self.writes_per_second = writes_per_second
        self.write_delay = 1.0 / (writes_per_second / num_workers)
        self.metrics = FailoverMetrics()
        self.cruise_ids: List[int] = []
        
        # Create connection string
        postgres_host = os.environ.get("POSTGRES_HOST")
        postgres_port = os.environ.get("POSTGRES_PORT", 5432)
        postgres_db = os.environ.get("POSTGRES_DATABASE")
        postgres_user = os.environ.get("POSTGRES_USERNAME")
        postgres_password = os.environ.get("POSTGRES_PASSWORD")
        postgres_ssl = os.environ.get("POSTGRES_SSL")
        
        if not all([postgres_host, postgres_db, postgres_user, postgres_password]):
            raise ValueError("Missing required PostgreSQL environment variables")
        
        connection_string = (
            f"postgresql://{postgres_user}:{postgres_password}@"
            f"{postgres_host}:{postgres_port}/{postgres_db}"
        )
        if postgres_ssl:
            connection_string += f"?sslmode={postgres_ssl}"
        
        # Create engine with connection pooling
        self.engine = create_engine(
            connection_string,
            pool_size=num_workers + 5,
            max_overflow=10,
            pool_pre_ping=True,  # Verify connections before using
            pool_recycle=3600,
            connect_args={
                "connect_timeout": 10,
                "options": "-c statement_timeout=5000"  # 5 second statement timeout
            }
        )
    
    def setup_test_data(self):
        """Ensure we have cruise data to reference"""
        print("Setting up test data...")
        try:
            with Session(self.engine) as session:
                cruises = session.exec(select(Cruise)).all()
                if not cruises:
                    print("⚠️  No cruise data found. Please run seed_data.py first.")
                    sys.exit(1)
                self.cruise_ids = [c.id for c in cruises]
                print(f"✓ Found {len(self.cruise_ids)} cruises for testing")
        except Exception as e:
            print(f"❌ Failed to setup test data: {e}")
            sys.exit(1)
    
    def write_info_request(self, worker_id: int) -> tuple[bool, float, str]:
        """
        Perform a single write operation
        Returns: (success, duration_ms, error_message)
        """
        start_time = time.perf_counter()
        
        try:
            with Session(self.engine) as session:
                # Create an info request
                import random
                cruise_id = random.choice(self.cruise_ids)
                
                info_request = InfoRequest(
                    name=f"LoadTest-Worker{worker_id}",
                    email=f"worker{worker_id}@loadtest.example.com",
                    notes=f"Failover test at {datetime.now().isoformat()}",
                    cruise_id=cruise_id
                )
                
                session.add(info_request)
                session.commit()
                
                duration_ms = (time.perf_counter() - start_time) * 1000
                return (True, duration_ms, None)
                
        except (OperationalError, DatabaseError) as e:
            duration_ms = (time.perf_counter() - start_time) * 1000
            error_msg = str(e.orig) if hasattr(e, 'orig') else str(e)
            return (False, duration_ms, error_msg)
        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000
            return (False, duration_ms, str(e))
    
    async def worker(self, worker_id: int):
        """Worker that continuously writes to the database"""
        print(f"Worker {worker_id} started")
        
        while self.metrics.test_running:
            # Perform write in thread pool (SQLAlchemy is synchronous)
            loop = asyncio.get_event_loop()
            success, duration_ms, error = await loop.run_in_executor(
                None, self.write_info_request, worker_id
            )
            
            # Record metrics
            self.metrics.record_write_attempt(success, duration_ms, error)
            
            # Print status (only show failures and periodic successes)
            if not success:
                print(f"  Worker {worker_id}: FAILED after {duration_ms:.1f}ms - {error}")
            elif len(self.metrics.write_attempts) % 100 == 0:
                print(f"  Worker {worker_id}: SUCCESS ({duration_ms:.1f}ms) - Total: {len(self.metrics.write_attempts)}")
            
            # Rate limiting
            await asyncio.sleep(self.write_delay)
        
        print(f"Worker {worker_id} stopped")
    
    async def monitor_progress(self):
        """Print progress summary periodically"""
        while self.metrics.test_running:
            await asyncio.sleep(5)
            
            if self.metrics.write_attempts:
                recent_writes = self.metrics.write_attempts[-50:]
                recent_success_rate = sum(1 for w in recent_writes if w['success']) / len(recent_writes) * 100
                
                print(f"\n📊 [PROGRESS] Total: {len(self.metrics.write_attempts)} | "
                      f"Success: {self.metrics.successful_writes} | "
                      f"Failed: {self.metrics.failed_writes} | "
                      f"Recent Success Rate: {recent_success_rate:.1f}%")
    
    async def run_load_test(self, duration_seconds: int = 300):
        """
        Run the load test for specified duration
        
        Args:
            duration_seconds: How long to run the test (default 5 minutes)
        """
        print("=" * 80)
        print("PostgreSQL FAILOVER LOAD TEST")
        print("=" * 80)
        print(f"Configuration:")
        print(f"  - Workers: {self.num_workers}")
        print(f"  - Target writes/sec: {self.writes_per_second}")
        print(f"  - Test duration: {duration_seconds} seconds")
        print(f"  - Database: {os.environ.get('POSTGRES_HOST')}")
        print(f"\n⚠️  INSTRUCTIONS:")
        print(f"  1. Let this test run and stabilize (watch for consistent writes)")
        print(f"  2. Initiate a PLANNED FAILOVER from Azure Portal or CLI:")
        print(f"     az postgres flexible-server restart \\")
        print(f"       --resource-group <YOUR_RG> \\")
        print(f"       --name <YOUR_SERVER> \\")
        print(f"       --failover Planned")
        print(f"  3. This script will automatically detect and measure the failover")
        print(f"  4. Wait for recovery and let it run for a bit longer")
        print(f"  5. Press Ctrl+C to stop and see results")
        print("=" * 80)
        print()
        
        self.setup_test_data()
        self.metrics.start_time = datetime.now()
        
        # Start all workers and monitor
        workers = [
            asyncio.create_task(self.worker(i))
            for i in range(self.num_workers)
        ]
        workers.append(asyncio.create_task(self.monitor_progress()))
        
        try:
            # Run for specified duration
            await asyncio.sleep(duration_seconds)
            print("\n⏱️  Test duration completed. Stopping workers...")
            
        except KeyboardInterrupt:
            print("\n\n🛑 Test stopped by user")
        
        finally:
            # Stop all workers
            self.metrics.test_running = False
            await asyncio.gather(*workers, return_exceptions=True)
            
            # Print summary
            self.print_summary()
    
    def print_summary(self):
        """Print comprehensive test summary"""
        summary = self.metrics.get_summary()
        
        print("\n" + "=" * 80)
        print("FAILOVER TEST RESULTS")
        print("=" * 80)
        print(f"\n📈 OVERALL STATISTICS:")
        print(f"  Total write attempts:     {summary['total_attempts']}")
        print(f"  Successful writes:        {summary['successful_writes']}")
        print(f"  Failed writes:            {summary['failed_writes']}")
        print(f"  Overall success rate:     {summary['success_rate']:.2f}%")
        
        if summary['avg_write_duration_ms']:
            print(f"\n⏱️  WRITE PERFORMANCE (successful writes only):")
            print(f"  Average duration:         {summary['avg_write_duration_ms']:.2f} ms")
            print(f"  Median duration:          {summary['median_write_duration_ms']:.2f} ms")
        
        if summary['failover_duration_seconds']:
            print(f"\n🔄 FAILOVER METRICS:")
            print(f"  Test start time:          {summary['test_start_time']}")
            print(f"  First failure detected:   {summary['first_failure_time']}")
            print(f"  First recovery detected:  {summary['first_recovery_time']}")
            print(f"  ⭐ FAILOVER DURATION:      {summary['failover_duration_seconds']:.2f} seconds")
            print(f"  Target SLA:               < 120 seconds")
            
            if summary['failover_duration_seconds'] < 120:
                print(f"  ✅ PASSED - Within SLA target")
            else:
                print(f"  ❌ EXCEEDED SLA target")
        else:
            print(f"\n⚠️  NO FAILOVER DETECTED")
            print(f"  Either no failover occurred, or the test was too short.")
            print(f"  To measure failover: trigger a planned failover during the test.")
        
        print("\n" + "=" * 80)
        
        # Export detailed results to CSV
        self.export_results()
    
    def export_results(self):
        """Export detailed results to CSV file"""
        import csv
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"failover_test_results_{timestamp}.csv"
        
        try:
            with open(filename, 'w', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=[
                    'timestamp', 'success', 'duration_ms', 'error'
                ])
                writer.writeheader()
                
                for attempt in self.metrics.write_attempts:
                    writer.writerow({
                        'timestamp': attempt['timestamp'].isoformat(),
                        'success': attempt['success'],
                        'duration_ms': f"{attempt['duration_ms']:.2f}",
                        'error': attempt['error'] or ''
                    })
            
            print(f"\n💾 Detailed results exported to: {filename}")
            print(f"   Import into Excel/PowerBI for visualization")
            
        except Exception as e:
            print(f"\n⚠️  Failed to export results: {e}")


async def main():
    """Main entry point"""
    # Configuration
    NUM_WORKERS = 10  # Number of concurrent writers
    WRITES_PER_SECOND = 50  # Target write rate
    TEST_DURATION = 300  # Run for 5 minutes (adjust as needed)
    
    tester = FailoverLoadTester(
        num_workers=NUM_WORKERS,
        writes_per_second=WRITES_PER_SECOND
    )
    
    await tester.run_load_test(duration_seconds=TEST_DURATION)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        # Graceful exit on Ctrl+C - results already printed in finally block
        print("\n")
        pass
