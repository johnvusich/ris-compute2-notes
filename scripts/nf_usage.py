#!/usr/bin/env python3
"""Per-process usage from Nextflow execution reports + sacct.

usage: nf_usage.py <label> <execution_report.html> [...]  (label/report pairs)
Writes usage_<label>.tsv (per task) to $NF_USAGE_OUT (default: current dir) and prints a
per-process summary. Needs Slurm loaded (sacct). Example:
  python3 scripts/nf_usage.py dev results/pipeline_info/execution_report_<date>.html
"""
import json, os, subprocess, sys
from collections import defaultdict

OUT = os.environ.get("NF_USAGE_OUT", ".")


def load_report(path):
    s = open(path).read()
    i = s.index('window.data = ') + len('window.data = ')
    d, _ = json.JSONDecoder(strict=False).raw_decode(s[i:].replace('\\$', '$').replace("\\'", "'"))
    return d['trace']


def num(x, default=0.0):
    try:
        return float(str(x).replace('%', ''))
    except (TypeError, ValueError):
        return default


def parse_mem(s):
    # sacct sizes like 123456K, 1.5G, 0
    s = (s or '').strip()
    if not s:
        return 0.0
    mult = {'K': 1024, 'M': 1024**2, 'G': 1024**3, 'T': 1024**4}
    if s[-1] in mult:
        return float(s[:-1]) * mult[s[-1]]
    return float(s)


def parse_time(s):
    # [D-]HH:MM:SS(.fff) or MM:SS.fff
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
    h, m, sec = parts
    return days * 86400 + h * 3600 + m * 60 + sec


def sacct(ids):
    rows = {}
    for k in range(0, len(ids), 200):
        chunk = ','.join(ids[k:k + 200])
        out = subprocess.run(
            ['sacct', '-j', chunk, '-n', '-P',
             '--format=JobID,State,ReqCPUS,ReqMem,ElapsedRaw,CPUTimeRAW,TotalCPU,MaxRSS'],
            capture_output=True, text=True, check=True).stdout
        for line in out.splitlines():
            jid, state, rcpu, rmem, el, cpur, tcpu, maxrss = line.split('|')
            base = jid.split('.')[0]
            r = rows.setdefault(base, {'maxrss': 0.0})
            if '.' not in jid:
                r.update(state=state, reqcpus=int(rcpu or 0), reqmem=rmem,
                         elapsed=int(el or 0), cputimeraw=int(cpur or 0))
            r['totalcpu'] = max(r.get('totalcpu', 0.0), parse_time(tcpu))
            r['maxrss'] = max(r['maxrss'], parse_mem(maxrss))
    return rows


def main(args):
    for label, path in zip(args[0::2], args[1::2]):
        trace = load_report(path)
        acct = sacct([t['native_id'] for t in trace if t.get('native_id')])
        per = defaultdict(list)
        with open(os.path.join(OUT, f'usage_{label}.tsv'), 'w') as fh:
            cols = ['process', 'tag', 'status', 'native_id', 'req_cpus', 'req_mem_gb', 'req_time_h',
                    'realtime_s', 'pct_cpu', 'peak_rss_gb', 'sacct_elapsed_s', 'sacct_cputimeraw_s',
                    'sacct_totalcpu_s', 'sacct_maxrss_gb']
            fh.write('\t'.join(cols) + '\n')
            for t in trace:
                a = acct.get(t.get('native_id', ''), {})
                proc = t['process'].split(':')[-1]
                row = dict(process=proc, tag=t.get('tag') or '', status=t['status'],
                           native_id=t.get('native_id', ''),
                           req_cpus=int(num(t['cpus'], 1)),
                           req_mem_gb=num(t['memory']) / 1024**3,
                           req_time_h=num(t['time']) / 3.6e6,
                           realtime_s=num(t['realtime']) / 1000,
                           pct_cpu=num(t['%cpu']),
                           peak_rss_gb=num(t['peak_rss']) / 1024**3,
                           sacct_elapsed_s=a.get('elapsed', 0),
                           sacct_cputimeraw_s=a.get('cputimeraw', 0),
                           sacct_totalcpu_s=a.get('totalcpu', 0.0),
                           sacct_maxrss_gb=a.get('maxrss', 0.0) / 1024**3)
                fh.write('\t'.join(f'{row[c]:.4g}' if isinstance(row[c], float) else str(row[c])
                                   for c in cols) + '\n')
                per[proc].append(row)
        print(f'\n##### {label}  ({len(trace)} tasks, report {os.path.basename(path)})')
        print(f"{'process':42s} {'n':>3s} {'reqCPU':>6s} {'reqGB':>6s} {'maxReal_s':>9s} "
              f"{'max%cpu':>7s} {'maxRSS_GB':>9s} {'alloc_CPUh':>10s} {'used_CPUh':>9s}")
        tot_alloc = tot_used = 0.0
        for proc, rs in sorted(per.items(), key=lambda kv: -sum(r['sacct_cputimeraw_s'] for r in kv[1])):
            alloc = sum(r['sacct_cputimeraw_s'] for r in rs) / 3600
            used = sum(r['sacct_totalcpu_s'] for r in rs) / 3600
            tot_alloc += alloc
            tot_used += used
            rss = max(max(r['peak_rss_gb'], r['sacct_maxrss_gb']) for r in rs)
            print(f"{proc[:42]:42s} {len(rs):3d} {max(r['req_cpus'] for r in rs):6d} "
                  f"{max(r['req_mem_gb'] for r in rs):6.1f} {max(r['realtime_s'] for r in rs):9.1f} "
                  f"{max(r['pct_cpu'] for r in rs):7.0f} {rss:9.3f} {alloc:10.3f} {used:9.3f}")
        print(f"{'TOTAL':42s} {'':3s} {'':6s} {'':6s} {'':9s} {'':7s} {'':9s} {tot_alloc:10.3f} {tot_used:9.3f}")


if __name__ == '__main__':
    main(sys.argv[1:])
