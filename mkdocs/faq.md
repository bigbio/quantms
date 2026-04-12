# Frequently Asked Questions

---

## What search engines does quantms support?

quantms supports three peptide database search engines:

| Engine | Flag | Notes |
|--------|------|-------|
| [Comet](https://comet-ms.sourceforge.net/) | `--search_engines comet` | Default; robust, widely used |
| [MS-GF+](https://msgfplus.github.io/) | `--search_engines msgf` | Excellent for high-res MS2 |
| [Sage](https://github.com/lazear/sage) | `--search_engines sage` | Fast Rust-based engine |

You can run multiple engines simultaneously — results are merged using OpenMS ConsensusID, which typically improves sensitivity compared to any single engine alone:

```bash
--search_engines "comet msgf"
```

The search engines are distributed as Docker/Singularity containers, so no separate installation is required.

---

## Can I use quantms for DIA data?

No. quantms is designed exclusively for DDA (Data-Dependent Acquisition) proteomics. For DIA (Data-Independent Acquisition) experiments — including SWATH-MS and methods acquired with Spectronaut or Skyline — use the companion pipeline **quantmsdiann**, which is powered by DIA-NN:

```bash
nextflow run bigbio/quantmsdiann \
    -profile docker \
    --input samplesheet.csv \
    --database uniprot_human.fasta \
    --outdir results/
```

See the [quantmsdiann documentation](https://github.com/bigbio/quantmsdiann) for details. If you are unsure whether your data is DDA or DIA, check the acquisition method in the instrument software or look at the MS2 scan pattern: DDA has variable numbers of MS2 scans between MS1 scans, while DIA has a fixed, repeating isolation window pattern.

---

## What is the recommended FDR threshold?

The widely accepted standard in proteomics is **1% FDR** at both the PSM/peptide level and the protein level. This is the default in quantms:

```bash
--fdr_threshold 0.01             # PSM/peptide-level FDR (1%)
--protein_level_fdr_cutoff 0.01  # Protein-level FDR (1%)
```

For highly confident datasets (large cohorts, high-quality spectra), a stricter threshold of 0.1% can be used. For very small datasets (fewer than ~500 identified peptides), the target-decoy FDR estimate becomes unreliable and results should be interpreted cautiously regardless of threshold.

Do not increase the FDR above 1% to artificially inflate protein counts — the increase in false positives can distort downstream quantification and differential expression results.

!!! tip "Protein FDR vs. PSM FDR"
    Applying FDR filtering at the PSM level alone is not sufficient. A protein can be reported with high confidence (low PSM FDR) while still being a false positive at the protein level, because many false-positive PSMs may map to different proteins. Always apply protein-level FDR filtering.

---

## How do I process phosphoproteomics data?

Phosphoproteomics requires two additions relative to a standard run: (1) adding phosphorylation as a variable modification, and (2) enabling PTM site localization to determine which serine, threonine, or tyrosine residue carries the phosphate group.

```bash
nextflow run bigbio/quantms -r 1.3.0 \
    -profile singularity \
    --input phospho_experiment.sdrf.tsv \
    --database uniprot_human.fasta \
    --variable_mods "Oxidation (M),Phospho (STY)" \
    --onsite_algorithm phosphors \
    --onsite_fragment_method HCD \
    --outdir results/
```

In the SDRF file, add phosphorylation as a variable modification:

```tsv
comment[modification parameters]    NT=Phospho;TA=S,T,Y;MT=variable;AC=MOD:00696
```

quantms supports three PTM localization algorithms: `lucxor` (default), `ascore`, and `phosphors`. PhosphoRS (`phosphors`) is generally recommended for phosphoproteomics. The localization probability for each site is reported in the output mzTab file.

---

## Can I run quantms on a laptop?

Yes, for small datasets. The test profile is specifically designed for local execution:

```bash
nextflow run bigbio/quantms -profile test,docker
```

For real experiments, the practical minimum for running a small LFQ study (5–10 samples, standard human proteome) is approximately:

- **RAM:** 16 GB (32 GB recommended)
- **CPU:** 4 cores (8 recommended)
- **Disk:** 50–100 GB free space for temporary work files

Large studies (50+ samples, multi-enzyme, multi-engine) will be very slow on a laptop and are better run on an HPC cluster or cloud. The pipeline will still work — it will just queue tasks sequentially due to CPU/memory limits.

!!! tip "Limit resources on a laptop"
    Add `--max_cpus 4 --max_memory 12.GB` to prevent quantms from overwhelming your machine. Nextflow will respect these limits when scheduling tasks.

---

## How much disk space and memory do I need?

Resource requirements scale with the number of samples and the complexity of the search:

| Scale | Samples | RAM | Disk |
|-------|---------|-----|------|
| Small | 1–10 | 16–32 GB | 50–200 GB |
| Medium | 10–50 | 32–64 GB | 200 GB – 1 TB |
| Large | 50–200+ | 64–256 GB | 1–5 TB |

Disk usage is dominated by the Nextflow work directory, which stores intermediate files for every task. After a successful run you can safely delete `work/` to reclaim space:

```bash
nextflow clean -f   # removes work directories for all completed runs
```

The mzML spectra files themselves are typically 1–5 GB each after conversion from raw format. Budget at least 3–5× the raw data size for intermediate files.

---

## What is the difference between quantms, MaxQuant, and FragPipe?

All three tools perform DDA proteomics analysis, but they differ in architecture, flexibility, and intended use:

| Feature | quantms | MaxQuant | FragPipe |
|---------|---------|----------|----------|
| Architecture | Nextflow pipeline (modular) | Monolithic GUI application | GUI + command-line |
| Cloud/HPC ready | Yes (natively) | No (manual setup) | Partial |
| Search engines | Comet, MS-GF+, Sage | Andromeda (built-in) | MSFragger |
| ML rescoring | MS2PIP + DeepLC + Percolator | Partially (built-in) | Percolator (optional) |
| LFQ | Yes (OpenMS ProteomicsLFQ) | Yes (MaxLFQ) | Yes |
| TMT/iTRAQ | Yes | Yes | Yes (TMT-Integrator) |
| Metadata standard | SDRF | None | None |
| Output | mzTab, QPX | txt tables | tsv tables |
| License | MIT (open source) | Academic only | Academic only |

quantms is designed for reproducible, large-scale, automated analysis — especially on public data from PRIDE. MaxQuant and FragPipe are better suited for interactive, single-dataset analysis in a laboratory setting.

---

## How do I cite quantms?

If you use quantms in your research, please cite:

> Dai C, Pfeuffer J, Wang H, et al. **quantms: a cloud-based pipeline for quantitative proteomics enables the reanalysis of public proteomics data.** *Nature Methods.* 2024;21:1603–1607. [DOI: 10.1038/s41592-024-02343-1](https://doi.org/10.1038/s41592-024-02343-1)

If you use PSM rescoring (MS2PIP, DeepLC, Percolator), please also cite those tools separately — see the [Publications](publications.md) page for the full list of tool citations.

---

## Where are the results files?

All output files are written to the directory specified by `--outdir`. The key results files are:

```
results/
├── proteomics_lfq/           # LFQ workflow outputs
│   ├── *.mzTab               # Full identification + quantification results
│   ├── *_out.csv             # Simplified protein intensity matrix
│   └── *.qpx/                # QPX parquet format (if enabled)
├── proteomics_iso/           # Isobaric workflow outputs
│   ├── *.mzTab
│   └── *_out.csv
├── multiqc/
│   └── multiqc_report.html   # Interactive QC dashboard (open in browser)
└── pipeline_info/
    ├── execution_report.html # Nextflow resource usage report
    └── execution_trace.txt   # Per-task timing and memory usage
```

The mzTab file contains the complete results including protein accessions, identification scores, and quantification values for all samples. The CSV matrix is a simplified, wide-format table with one row per protein and one column per sample — useful for direct import into R or Python.

See [Output](output.md) for a detailed description of all output files and their formats.

---

## Can I use a custom modification?

Yes. Any modification can be specified as long as it has a PSI-MS ontology accession or can be defined by its mass shift. Pass modifications using the standard OpenMS modification name format:

```bash
# Variable modification by name (must be in OpenMS modification database)
--variable_mods "Oxidation (M),Acetyl (N-term)"

# In SDRF — use PSI-MOD or UNIMOD accessions
comment[modification parameters]    NT=Acetylation;TA=K;MT=variable;AC=UNIMOD:1
comment[modification parameters]    NT=MyCustomMod;TA=C;MT=fixed;MM=57.021464
```

For completely novel modifications not in any database, use `MM=` (monoisotopic mass shift) in the SDRF modification parameters column. The modification name (`NT=`) is used for display purposes only in this case.

!!! tip "Check the OpenMS modification list"
    Run `ModificationsDB` (available in the OpenMS Docker container) to list all built-in modification names. Most common PTMs (phosphorylation, acetylation, ubiquitination, methylation, etc.) are already included and can be referenced by their common names.
