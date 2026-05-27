#!/usr/bin/env python3
"""
Sample Application for Datadog Integration POC
Exposes Prometheus metrics and simulates memory threshold crossing
"""

import os
import time
import psutil
from flask import Flask, Response
from prometheus_client import Counter, Gauge, generate_latest, REGISTRY

app = Flask(__name__)

# Prometheus metrics
memory_threshold_exceeded = Counter(
    'memory_threshold_exceeded_total',
    'Number of times memory threshold was exceeded'
)

current_memory_usage = Gauge(
    'app_memory_usage_percent',
    'Current memory usage percentage'
)

memory_threshold_gauge = Gauge(
    'memory_threshold_percent',
    'Memory threshold percentage'
)

# Configuration
MEMORY_THRESHOLD = float(os.getenv('MEMORY_THRESHOLD', '60.0'))
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', '10'))

memory_threshold_gauge.set(MEMORY_THRESHOLD)

# Hold allocated memory so load persists across requests
memory_load_holder = []
process = psutil.Process()


def _read_first_existing(paths):
    """Return stripped contents of the first existing readable file"""
    for path in paths:
        try:
            with open(path, 'r', encoding='utf-8') as handle:
                return handle.read().strip()
        except (FileNotFoundError, PermissionError, OSError):
            continue
    return None


def get_memory_usage_details():
    """Return memory usage based on container cgroup limits when available"""
    usage_paths = [
        '/sys/fs/cgroup/memory.current',
        '/sys/fs/cgroup/memory/memory.usage_in_bytes',
    ]
    limit_paths = [
        '/sys/fs/cgroup/memory.max',
        '/sys/fs/cgroup/memory/memory.limit_in_bytes',
    ]

    usage_raw = _read_first_existing(usage_paths)
    limit_raw = _read_first_existing(limit_paths)

    if usage_raw and limit_raw and limit_raw != 'max':
        try:
            usage_bytes = int(usage_raw)
            limit_bytes = int(limit_raw)
            if limit_bytes > 0:
                return {
                    'percent': (usage_bytes / limit_bytes) * 100,
                    'usage_bytes': usage_bytes,
                    'limit_bytes': limit_bytes,
                    'source': 'cgroup'
                }
        except ValueError:
            pass

    rss_bytes = process.memory_info().rss
    system_total = psutil.virtual_memory().total
    return {
        'percent': (rss_bytes / system_total) * 100,
        'usage_bytes': rss_bytes,
        'limit_bytes': system_total,
        'source': 'process_rss'
    }


def check_memory():
    """Check memory usage and increment counter if threshold exceeded"""
    memory_details = get_memory_usage_details()
    memory_percent = memory_details['percent']

    current_memory_usage.set(memory_percent)

    if memory_percent > MEMORY_THRESHOLD:
        memory_threshold_exceeded.inc()
        print(
            f"⚠️  Memory threshold exceeded: {memory_percent:.2f}% > {MEMORY_THRESHOLD}% "
            f"(source={memory_details['source']}, usage={memory_details['usage_bytes']}, "
            f"limit={memory_details['limit_bytes']})"
        )
        return True
    else:
        print(
            f"✓ Memory usage normal: {memory_percent:.2f}% <= {MEMORY_THRESHOLD}% "
            f"(source={memory_details['source']}, usage={memory_details['usage_bytes']}, "
            f"limit={memory_details['limit_bytes']})"
        )
        return False


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    check_memory()
    return Response(generate_latest(REGISTRY), mimetype='text/plain')


@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'healthy', 'memory_threshold': MEMORY_THRESHOLD}


@app.route('/simulate-load')
def simulate_load():
    """Simulate persistent memory load to trigger threshold"""
    global memory_load_holder

    chunk_mb = int(os.getenv('LOAD_CHUNK_MB', '10'))
    iterations = int(os.getenv('LOAD_ITERATIONS', '10'))

    allocated_mb = 0
    try:
        for _ in range(iterations):
            memory_load_holder.append(bytearray(chunk_mb * 1024 * 1024))
            allocated_mb += chunk_mb
            time.sleep(0.1)

        check_memory()
        return {
            'status': 'persistent load simulated',
            'allocated_mb_this_call': allocated_mb,
            'total_retained_chunks': len(memory_load_holder),
            'memory_threshold': MEMORY_THRESHOLD
        }
    except MemoryError:
        check_memory()
        return {
            'status': 'memory limit reached',
            'allocated_mb_this_call': allocated_mb,
            'total_retained_chunks': len(memory_load_holder),
            'memory_threshold': MEMORY_THRESHOLD
        }


@app.route('/clear-load')
def clear_load():
    """Clear retained memory load"""
    global memory_load_holder
    released_chunks = len(memory_load_holder)
    memory_load_holder = []
    check_memory()
    return {'status': 'load cleared', 'released_chunks': released_chunks}


@app.route('/')
def index():
    """Root endpoint with information"""
    memory_details = get_memory_usage_details()
    return {
        'app': 'Datadog Integration POC',
        'memory_usage_percent': memory_details['percent'],
        'memory_usage_bytes': memory_details['usage_bytes'],
        'memory_limit_bytes': memory_details['limit_bytes'],
        'memory_source': memory_details['source'],
        'memory_threshold': MEMORY_THRESHOLD,
        'retained_chunks': len(memory_load_holder),
        'endpoints': {
            '/metrics': 'Prometheus metrics',
            '/health': 'Health check',
            '/simulate-load': 'Simulate persistent memory load',
            '/clear-load': 'Clear retained memory load'
        }
    }


if __name__ == '__main__':
    print(f"Starting application with memory threshold: {MEMORY_THRESHOLD}%")
    print(f"Memory check interval: {CHECK_INTERVAL}s")
    app.run(host='0.0.0.0', port=8080)

# Made with Bob
