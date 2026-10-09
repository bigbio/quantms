"""Check Sage output-to-run identity using the real Nextflow module."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class SageOutputsTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("nextflow"), "Nextflow is required")
    def test_prefix_collisions_and_single_run_keep_exact_identity(self):
        module = Path(__file__).resolve().parents[1] / "modules/local/openms/sage/main.nf"
        with tempfile.TemporaryDirectory(prefix="sage-output-test-") as temporary:
            root = Path(temporary)
            # Fake only the search executables; Nextflow performs the actual
            # output glob expansion and transpose used by the production caller.
            bindir = root / "bin"
            bindir.mkdir()
            tool = bindir / "fake_search"
            tool.write_text(f"#!{sys.executable}\n" + '''
import json
import sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
if not args:
    print("Version: 3.5.0" if name == "SageAdapter" else "Version 0.15.0")
elif name == "SageAdapter":
    inputs = args[args.index("-in") + 1:args.index("-out")]
    output = Path(args[args.index("-out") + 1])
    output.mkdir()
    (output / "runs.json").write_text(json.dumps([Path(p).stem for p in inputs]))
elif name == "IDRipper":
    source = Path(args[args.index("-in") + 1])
    for run in json.loads((source / "runs.json").read_text()):
        # Bruker .d directory suffixes are removed by the real IDRipper output.
        normalized = run[:-2] if run.endswith(".d") else run
        Path(normalized + ".idparquet").mkdir()
''')
            tool.chmod(0o755)
            for name in ("SageAdapter", "IDRipper", "sage"):
                (bindir / name).symlink_to(tool)
            runs = [f"sample_fr{n}" for n in range(1, 10)] + ["bruker_890.d", "single", "bruker_single.d"]
            for run in runs:
                (root / f"{run}.mzML").touch()
            (root / "search.fasta").touch()
            (root / "nextflow.config").write_text('''
process.cpus = 1
params {
    IL_equivalent = false
    decoy_string = 'rev'
    min_peptide_length = 7
    max_peptide_length = 40
    allowed_missed_cleavages = 2
    num_hits = 1
    min_precursor_charge = 2
    max_precursor_charge = 4
    min_peaks = 1
    max_mods = 2
    isotope_error_range = '-1,3'
    unmatched_action = 'warn'
    db_debug = 0
}
''')
            (root / "main.nf").write_text(
                "include { SAGE } from " + json.dumps(str(module)) + "\n" + '''
workflow {
    batches = Channel.of((1..9).collect { "sample_fr${it}" } + ['bruker_890.d'], ['single'], ['bruker_single.d'])
        .map { ids ->
            def metas = ids.collect { id ->
                [mzml_id: id, enzyme: 'Trypsin', precursormasstolerance: 10,
                 precursormasstoleranceunit: 'ppm', fragmentmasstolerance: 0.02,
                 fragmentmasstoleranceunit: 'Da', fixedmodifications: '',
                 variablemodifications: 'Oxidation (M)']
            }
            tuple('settings', ids[0], metas, ids.collect { file("${it}.mzML") }, file('search.fasta'))
        }
    SAGE(batches)
    SAGE.out.id_files_sage.transpose()
        .map { meta, result -> "${meta.mzml_id}\\t${result.name}\\n" }
        .collectFile(name: 'pairs.tsv', storeDir: projectDir, sort: true)
}
''')
            env = os.environ.copy()
            env["NXF_OFFLINE"] = "true"
            env["NXF_OPTS"] = env.get("NXF_OPTS", "") + " -Xms128m -Xmx512m"
            result = subprocess.run(
                ["nextflow", "run", "main.nf", "-ansi-log", "false"],
                cwd=root, env=env, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, timeout=120,
            )
            self.assertEqual(result.returncode, 0, result.stdout)
            pairs = [line.split("\t") for line in (root / "pairs.tsv").read_text().splitlines()]
            expected = [
                [run, f"{run[:-2] if run.endswith('.d') else run}_sage.idparquet"]
                for run in runs
            ]
            self.assertCountEqual(pairs, expected)


if __name__ == "__main__":
    unittest.main()
