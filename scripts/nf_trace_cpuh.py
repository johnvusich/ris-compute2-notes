#!/usr/bin/env python3
"""Allocated CPU hours of one Nextflow run: head job + every task job, from sacct.

usage: nf_trace_cpuh.py <head_jobid> <execution_trace.txt> [...]
Reads task Slurm job IDs from the trace's native_id column (works when the HTML
report failed to render, unlike nf_usage.py). Needs Slurm loaded (sacct).
Prints per-process tasks / allocated CPU h / used CPU h, then the run total.
CACHED tasks (from -resume) are skipped: their CPU was spent in the earlier run.
"""
import csv, subprocess, sys
from collections import defaultdict


def secs(s):
    # sacct TotalCPU: [D-][HH:]MM:SS(.fff)
    s = (s or '').strip()
    if not s:
        return 0.0
    days = 0
    if '-' in s:
        d, s = s.split('-', 1)
        days = int(d)
    parts = [float(p) for p in s.split(':')]
    while len(parts) < 3:
        parts.insert(0, 0.0)
    return days * 86400 + parts[0] * 3600 + parts[1] * 60 + parts[2]


def sacct(ids):
    out = subprocess.run(
        ['sacct', '-n', '-P', '-X', '-j', ','.join(ids), '--format=JobID,CPUTimeRAW,TotalCPU,Elapsed'],
        capture_output=True, text=True, check=True).stdout
    rows = {}
    for line in out.splitlines():
        jid, cpuraw, total, elapsed = line.split('|')
        rows[jid] = (int(cpuraw or 0), secs(total), elapsed)
    # TotalCPU is only filled on the job's steps; take it from the non -X query
    out = subprocess.run(['sacct', '-n', '-P', '-j', ','.join(ids), '--format=JobID,TotalCPU'],
                         capture_output=True, text=True, check=True).stdout
    used = defaultdict(float)
    for line in out.splitlines():
        jid, total = line.split('|')
        used[jid.split('.')[0]] = max(used[jid.split('.')[0]], secs(total))
    return {j: (r[0], used.get(j, r[1]), r[2]) for j, r in rows.items()}


def main(head, traces):
    tasks = []
    for t in traces:
        for r in csv.DictReader(open(t), delimiter='\t'):
            # CACHED rows point at an earlier run's jobs; count them there, not here
            if r['native_id'] and r['native_id'] != '-' and r['status'] != 'CACHED':
                tasks.append((r['name'].split(' (')[0].split(':')[-1], r['native_id'], r['status']))
    acct = sacct([head] + [n for _, n, _ in tasks])
    per = defaultdict(lambda: [0, 0, 0.0, 0.0])
    for proc, nid, status in tasks:
        a = acct.get(nid, (0, 0.0, ''))
        p = per[proc]
        p[0] += 1
        p[1] += status != 'COMPLETED'
        p[2] += a[0] / 3600
        p[3] += a[1] / 3600
    h = acct.get(head, (0, 0.0, '?'))
    print(f"{'process':32} {'tasks':>5} {'failed':>6} {'alloc_CPUh':>10} {'used_CPUh':>9}")
    for proc, (n, f, al, us) in sorted(per.items(), key=lambda x: -x[1][2]):
        print(f"{proc:32} {n:5d} {f:6d} {al:10.3f} {us:9.3f}")
    task_al = sum(p[2] for p in per.values())
    print(f"head job {head}: elapsed {h[2]}, {h[0] / 3600:.3f} CPU h allocated")
    print(f"tasks: {len(tasks)} jobs, {task_al:.3f} CPU h allocated")
    print(f"TOTAL allocated CPU h: {task_al + h[0] / 3600:.3f}")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
