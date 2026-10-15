#!/usr/bin/env python3
"""Check a samplesheet (e.g. from fetchngs --nf_core_pipeline rnaseq) against nf-core/rnaseq's assets/schema_input.json.

usage: check_rnaseq_samplesheet.py <schema_input.json> <samplesheet.csv>
Applies the schema's required / pattern / enum / format:file-path + exists / number min-max rules
per row, treating empty cells as absent (as nf-schema does). Extra columns are allowed (the schema
does not set additionalProperties: false). Also flags single/paired-end mixing per sample.
Exit 0 = valid. No third-party modules needed.
"""
import csv, json, os, re, sys
from collections import defaultdict


def main(schema_path, sheet_path):
    schema = json.load(open(schema_path))['items']
    props, required = schema['properties'], schema.get('required', [])
    errors = []
    rows = list(csv.DictReader(open(sheet_path, newline='')))
    layouts = defaultdict(set)
    for i, row in enumerate(rows, start=2):  # line 1 = header
        row = {k: v for k, v in row.items() if v not in ('', None)}
        for col in required:
            if col not in row:
                errors.append(f'line {i}: missing required "{col}"')
        for col, val in row.items():
            rule = props.get(col)
            if not rule:
                continue
            if 'pattern' in rule and not re.search(rule['pattern'], val):
                errors.append(f'line {i}: {col}={val!r}: {rule.get("errorMessage", "pattern mismatch")}')
            if 'enum' in rule and val not in rule['enum']:
                errors.append(f'line {i}: {col}={val!r} not in {rule["enum"]}')
            if rule.get('format') == 'file-path' and rule.get('exists') and not os.path.isfile(val):
                errors.append(f'line {i}: {col} does not exist: {val}')
            if rule.get('type') == 'number':
                try:
                    x = float(val)
                    if not rule.get('minimum', x) <= x <= rule.get('maximum', x):
                        errors.append(f'line {i}: {col}={val} out of range')
                except ValueError:
                    errors.append(f'line {i}: {col}={val!r} is not a number')
        if 'sample' in row:
            layouts[row['sample']].add('PE' if 'fastq_2' in row else 'SE')
    for s, l in layouts.items():
        if len(l) > 1:
            errors.append(f'sample {s}: mixes single- and paired-end rows')
    known = [c for c in rows[0].keys() if c in props] if rows else []
    print(f'{len(rows)} rows, {len(layouts)} samples; schema columns present: {known}; '
          f'{len(rows[0]) - len(known) if rows else 0} extra metadata columns')
    for e in errors:
        print('ERROR', e)
    print('VALID' if not errors else f'INVALID ({len(errors)} errors)')
    return 1 if errors else 0


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(*sys.argv[1:]))
