# Output

quantms produces standardized output files organized into predictable directories under `--outdir`. All primary result files follow open HUPO-PSI standards.

> **DIA users:** DIA output files and structure are described in the [quantmsdiann documentation](https://quantmsdiann.quantms.org).

---

## Output Structure

### DDA-LFQ Output

```
results_lfq/
├── pipeline_info/             # Nextflow execution reports and software versions
├── sdrf/                      # SDRF files and OpenMS config files used
├── spectra/                   # Spectra-related data (when --mzml_features is enabled)
│   └── mzml_statistics/       # Per-run mzML statistics
├── quant_tables/              # All quantification results
│   ├── out.mzTab              # mzTab with identifications and quantities
│   ├── msstats_in.csv         # MSstats-ready long-format table
│   └── out.consensusXML       # OpenMS internal format (debugging/downstream)
├── msstats/                   # MSstats-processed results
│   └── out_msstats.mzTab      # mzTab with MSstats input format (for downstream analysis)
└── pmultiqc/                  # Interactive QC report
    ├── multiqc_report.html
    ├── multiqc_data/
    └── multiqc_plots/
        ├── png/
        ├── svg/
        └── pdf/
```

### DDA-ISO Output (TMT / iTRAQ)

```
results_iso/
├── pipeline_info/
├── sdrf/
├── quant_tables/
│   ├── out.mzTab              # mzTab with channel intensities and identifications
│   ├── peptide_out.csv        # Peptide-level quantities per channel
│   ├── protein_out.csv        # Protein-level quantities per channel
│   └── out_msstats_in.csv     # MSstats-ready table
├── msstats/
│   └── out_msstats.mzTab
└── pmultiqc/
    ├── multiqc_report.html
    └── ...
```

### Verbose Output

For debugging or detailed intermediate-file inspection, run with `-c verbose_modules`:

```bash
nextflow run bigbio/quantms -profile docker -c verbose_modules -params-file params.yaml
```

The verbose structure exposes all intermediate steps:

```
results/
├── pipeline_info/
├── sdrf/
├── spectra/
│   ├── mzml_indexing/
│   └── mzml_statistics/
├── peptide_identification/
│   ├── comet/
│   ├── msgf/
│   └── sage/
├── peptide_postprocessing/
│   ├── psm_features/
│   ├── psm_clean/
│   ├── percolator/
│   ├── consensusid/
│   ├── fdr_consensusid/
│   └── id_filter/
├── quant_tables/
├── msstats/
└── pmultiqc/
```

---

## Key Output Files

### mzTab

The primary result file. Generated for both DDA-LFQ and DDA-ISO workflows.

- **Location:** `quant_tables/out.mzTab`
- **Standard:** [HUPO-PSI mzTab](https://github.com/HUPO-PSI/mzTab)
- **Suitable for:** PRIDE submission, downstream quantification tools (mokume, qpx)

mzTab is a multi-section TSV file. Each line starts with a section identifier:

| Prefix | Section |
|--------|---------|
| `MTD` | Metadata |
| `PRH/PRT` | Protein header / entry |
| `PEH/PEP` | Peptide header / entry |
| `PSH/PSM` | PSM header / entry |

**Notable optional columns in the PRT section:**

- `opt_global_Posterior_Probability_score` — Posterior probability from protein inference
- `opt_global_nr_found_peptides` — Number of identified peptides per protein
- `opt_global_result_type` — `single_protein`, `indistinguishable_protein_group`, or `protein_details`

**Notable optional columns in the PEP section:**

- `opt_global_cv_MS:1000889_peptidoform_sequence` — Sequence with modifications
- `opt_global_q-value` — Experiment-wide q-value
- `opt_global_mass_to_charge_study_variable[n]` — Precursor m/z in sample n

**Notable optional columns in the PSM section:**

- `opt_global_cv_MS:1000889_peptidoform_sequence` — Modified sequence for this match
- `opt_global_SpecEValue_score` — Spectral E-value (MS-GF+ engine)
- `opt_global_q-value` — Experiment-wide q-value

Score columns vary depending on which search engines and rescoring tools were used; consult their individual documentation for definitions.

### MSstats Input Table

- **Location:** `quant_tables/msstats_in.csv` (LFQ) or `quant_tables/out_msstats_in.csv` (ISO)
- **Format:** Long-format CSV compatible with the `OpenMStoMSstats()` function in the MSstats R package
- **Use:** Statistical modeling of differential expression

### MSstats Input Export

- **Location:** `msstats/out_msstats.mzTab`
- **Contains:** MSstats-compatible CSV exported for downstream statistical analysis with the MSstats R package

### Parquet PSM Tables

When running the identification-only subworkflow, PSM results are written in [quantms.io parquet format](https://github.com/bigbio/quantms.io/blob/dev/docs/psm.rst):

- **Location:** `psm_tables/`
- **Use:** Efficient downstream processing with pandas, DuckDB, or qpx

### OpenMS Formats (LFQ only)

- `quant_tables/out.consensusXML` — ConsensusXML with linked features across runs. Useful for debugging and OpenMS-based downstream analysis.
- `quant_tables/peptide_out.tsv` — Peptide-level quantities from ProteinQuantifier
- `quant_tables/protein_out.tsv` — Protein-level quantities from ProteinQuantifier

---

## pmultiqc QC Report

- **Location:** `pmultiqc/multiqc_report.html`
- **Open in any web browser** — no installation required

The [pmultiqc](https://github.com/bigbio/pmultiqc) plugin generates an interactive HTML report summarizing:

- Peptide and protein identification counts per run
- FDR distributions
- Charge state distributions
- Missed cleavage rates
- Precursor mass error distributions
- Quantification intensity distributions
- TMT channel balance (isobaric workflows)
- Software versions used

Plots are also exported as static images under `pmultiqc/multiqc_plots/` in PNG, SVG, and PDF formats.

---

## Pipeline Info

- **Location:** `pipeline_info/`
- **Contents:**
  - `execution_report.html` — Interactive Nextflow execution report
  - `execution_timeline.html` — Per-process timing
  - `execution_trace.txt` — Detailed resource usage per task
  - `pipeline_dag.svg` — Workflow directed acyclic graph
  - `software_versions.yml` — Exact versions of all tools used
  - `params_<timestamp>.json` — Full parameter set used for the run

---

## SDRF-Driven Parameter Precedence

When an SDRF file is used as input, the following parameters are read from the SDRF and override any values provided on the command line:

- `labelling_type`
- `dissociationmethod`
- `fixedmodifications`
- `variablemodifications`
- `precursormasstolerance` / `precursormasstoleranceunit`
- `fragmentmasstolerance` / `fragmentmasstoleranceunit`
- `enzyme`
- `acquisition_method`

---

## Input File Types (Reference)

### Spectra

quantms natively supports:

- `.mzML` — Open standard (preferred)
- `.raw` — Thermo Fisher RAW files (auto-converted via ThermoRawFileParser)
- `.d` — Bruker timsTOF (converted when `--convert_dotd` is set)

Compressed variants (`.gz`, `.tar`, `.tar.gz`, `.zip`) are also accepted.

### Protein Database

Standard FASTA format. Remove stop-codon characters (`*`) before use. Decoys are added automatically by the pipeline when `--add_decoys true` (default).
