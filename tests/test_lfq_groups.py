"""Regression tests for lossless, design-aware LFQ partitioning."""

import importlib.util
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "split_lfq_groups", Path(__file__).resolve().parents[1] / "bin" / "split_lfq_groups.py"
)
GROUPS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GROUPS)


class LfqGroupsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.columns = ["comment[instrument]", "comment[gradient duration]"]
        self.sdrf = [
            ["source name", "comment[data file]", *self.columns, "comment[modification parameters]", "comment[modification parameters]"],
            ["sample A", "a.raw", "instrument A", "30 min", "fixed C", "variable M"],
            ["sample B", "b.raw", "instrument B", "120 min", "fixed C", "variable M"],
            ["sample C", "c.raw", "instrument A", "30 min", "fixed C", "variable M"],
            ["sample D", "d.raw", "instrument B", "120 min", "fixed C", "variable M"],
        ]
        self.design = [
            ["Fraction_Group", "Fraction", "Spectra_Filepath", "Label", "Sample"],
            ["1", "1", "a.mzML", "1", "1"],
            ["2", "1", "b.mzML", "1", "2"],
            ["3", "1", "c.mzML", "1", "3"],
            ["4", "1", "d.mzML", "1", "4"],
            [],
            ["Sample", "MSstats_Condition", "MSstats_BioReplicate"],
            ["1", "control", "D1"],
            ["2", "control", "D2"],
            ["3", "spike", "D3"],
            ["4", "spike", "D4"],
        ]

    def run_split(self):
        sdrf = self.root / "full.sdrf.tsv"
        design = self.root / "full_design.tsv"
        GROUPS.write_table(sdrf, self.sdrf)
        GROUPS.write_table(design, self.design)
        before = sdrf.read_bytes(), design.read_bytes()
        result = GROUPS.split_groups(sdrf, design, self.columns, self.root / "groups")
        self.assertEqual(before, (sdrf.read_bytes(), design.read_bytes()))
        return result

    def test_complete_partition_and_replicate_identity(self):
        manifest = self.run_split()
        self.assertEqual({row[1] for row in manifest[1:]}, {"a", "b", "c", "d"})
        self.assertEqual(len(manifest), 5)
        self.assertEqual(len({row[0] for row in manifest[1:]}), 2)
        emitted_rows = []
        seen_replicates = set()
        for name in {row[2] for row in manifest[1:]}:
            rows = GROUPS.read_table(self.root / "groups" / name)
            self.assertEqual(rows[0], self.sdrf[0])
            emitted_rows.extend(rows[1:])
        for name in {row[3] for row in manifest[1:]}:
            files, samples = GROUPS.design_tables(GROUPS.read_table(self.root / "groups" / name))
            self.assertEqual({row[4] for row in files[1:]}, {row[0] for row in samples[1:]})
            self.assertEqual({row[1] for row in samples[1:]}, {"control", "spike"})
            seen_replicates.update(row[2] for row in samples[1:])
        self.assertCountEqual(emitted_rows, self.sdrf[1:])
        self.assertEqual(seen_replicates, {"D1", "D2", "D3", "D4"})

    def test_group_ids_survive_row_reordering(self):
        first = self.run_split()
        self.sdrf[1:] = reversed(self.sdrf[1:])
        second = self.run_split()
        self.assertEqual({tuple(row[:2]) for row in first[1:]}, {tuple(row[:2]) for row in second[1:]})

    def test_unknown_grouping_column(self):
        self.columns = ["missing"]
        with self.assertRaisesRegex(ValueError, "Expected exactly one"):
            self.run_split()

    def test_missing_group_value(self):
        self.sdrf[1][2] = "not available"
        with self.assertRaisesRegex(ValueError, "Missing LFQ grouping"):
            self.run_split()

    def test_conflicting_run_assignment(self):
        self.sdrf.append(["sample A", "a.raw", "instrument B", "120 min", "fixed C", "variable M"])
        with self.assertRaisesRegex(ValueError, "multiple LFQ groups"):
            self.run_split()

    def test_unmatched_run_is_not_dropped(self):
        self.sdrf[1][1] = "unexpected.raw"
        with self.assertRaisesRegex(ValueError, "run sets differ"):
            self.run_split()

    def test_fractionated_sample_cannot_cross_groups(self):
        self.design[2][0] = "1"
        with self.assertRaisesRegex(ValueError, "crosses LFQ groups"):
            self.run_split()

    def test_missing_sample_metadata_is_rejected(self):
        self.design[-1][0] = "5"
        with self.assertRaisesRegex(ValueError, "missing sample metadata"):
            self.run_split()


if __name__ == "__main__":
    unittest.main()
