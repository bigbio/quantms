#!/usr/bin/env python3
"""Partition an LFQ design by explicit SDRF columns without discarding runs."""

import argparse
import csv
import hashlib
import json
from pathlib import Path


def read_table(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.reader(handle, delimiter="\t"))


def write_table(path, rows):
    with Path(path).open("w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, delimiter="\t", lineterminator="\n").writerows(rows)


def run_name(path):
    return Path(path).name.rsplit(".", 1)[0]


def index_column(header, name):
    matches = [i for i, column in enumerate(header) if column == name]
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one {name!r} column, found {len(matches)}")
    return matches[0]


def sdrf_groups(rows, columns):
    header, *body = rows
    indexes = [index_column(header, column) for column in columns]
    file_index = index_column(header, "comment[data file]")
    groups, assignments = {}, {}
    for row in body:
        if len(row) != len(header):
            raise ValueError("SDRF row does not match its header")
        key = tuple(row[index].strip() for index in indexes)
        if any(value.lower() in ("", "not available", "not applicable") for value in key):
            raise ValueError(f"Missing LFQ grouping value for {row[file_index]!r}")
        name = run_name(row[file_index])
        if name in assignments and assignments[name] != key:
            raise ValueError(f"Run {name!r} belongs to multiple LFQ groups")
        assignments[name] = key
        groups.setdefault(key, []).append(row)
    if not assignments:
        raise ValueError("SDRF contains no runs")
    return groups, assignments


def design_tables(rows):
    try:
        separator = next(i for i, row in enumerate(rows) if not row or not any(row))
    except StopIteration as exc:
        raise ValueError("Expected an OpenMS design with file and sample tables") from exc
    files = rows[:separator]
    samples = [row for row in rows[separator + 1 :] if row and any(row)]
    if len(files) < 2 or len(samples) < 2:
        raise ValueError("OpenMS design has an empty file or sample table")
    for table in (files, samples):
        if any(len(row) != len(table[0]) for row in table[1:]):
            raise ValueError("OpenMS design row does not match its header")
    return files, samples


def subset_design(files, samples, names):
    file_index = index_column(files[0], "Spectra_Filepath")
    sample_index = index_column(files[0], "Sample")
    group_index = index_column(files[0], "Fraction_Group")
    sample_id_index = index_column(samples[0], "Sample")
    selected = [row[:] for row in files[1:] if run_name(row[file_index]) in names]
    sample_ids = {row[sample_index] for row in selected}
    sample_rows = [row[:] for row in samples[1:] if row[sample_id_index] in sample_ids]
    if {row[sample_id_index] for row in sample_rows} != sample_ids:
        raise ValueError("OpenMS file table references missing sample metadata")
    # Reindex structural IDs locally; retain all condition and biological-replicate values.
    sample_map = {row[sample_id_index]: str(i + 1) for i, row in enumerate(sample_rows)}
    fraction_map = {}
    for row in selected:
        fraction_map.setdefault(row[group_index], str(len(fraction_map) + 1))
        row[group_index] = fraction_map[row[group_index]]
        row[sample_index] = sample_map[row[sample_index]]
    for row in sample_rows:
        row[sample_id_index] = sample_map[row[sample_id_index]]
    return [files[0], *selected, [], samples[0], *sample_rows]


def split_groups(sdrf, design, columns, output):
    if not columns or len(set(columns)) != len(columns):
        raise ValueError("Supply distinct, nonempty SDRF grouping columns")
    sdrf_rows = read_table(sdrf)
    groups, assignments = sdrf_groups(sdrf_rows, columns)
    files, samples = design_tables(read_table(design))
    file_index = index_column(files[0], "Spectra_Filepath")
    design_names = [run_name(row[file_index]) for row in files[1:]]
    if len(design_names) != len(set(design_names)):
        raise ValueError("OpenMS design contains duplicate run names")
    if set(design_names) != set(assignments):
        raise ValueError(
            f"SDRF/design run sets differ: missing from design={sorted(set(assignments) - set(design_names))}; "
            f"missing from SDRF={sorted(set(design_names) - set(assignments))}"
        )
    # A fractionated sample must stay intact within a quantification group.
    fraction_index = index_column(files[0], "Fraction_Group")
    fraction_groups = {}
    for row in files[1:]:
        key = assignments[run_name(row[file_index])]
        previous = fraction_groups.setdefault(row[fraction_index], key)
        if previous != key:
            raise ValueError(f"Fraction group {row[fraction_index]!r} crosses LFQ groups")

    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    manifest = [["group_id", "run_id", "sdrf_file", "design_file", *columns]]
    for key, rows in sorted(groups.items()):
        digest = hashlib.sha256(json.dumps([columns, key], ensure_ascii=False).encode()).hexdigest()[:16]
        group_id = f"lfq_group_{digest}"
        names = {name for name, assigned in assignments.items() if assigned == key}
        sdrf_name = f"{group_id}.sdrf.tsv"
        design_name = f"{group_id}_openms_design.tsv"
        write_table(output / sdrf_name, [sdrf_rows[0], *rows])
        write_table(output / design_name, subset_design(files, samples, names))
        manifest.extend([group_id, name, sdrf_name, design_name, *key] for name in sorted(names))
    write_table(output / "lfq_groups.tsv", manifest)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdrf", required=True)
    parser.add_argument("--design", required=True)
    parser.add_argument("--columns", required=True, nargs="+")
    parser.add_argument("--output", default=".")
    args = parser.parse_args()
    split_groups(args.sdrf, args.design, args.columns, args.output)


if __name__ == "__main__":
    main()
