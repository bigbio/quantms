# Label-Free Quantification (LFQ)

Label-free quantification estimates protein abundance directly from MS1 ion intensities, without chemical labeling. quantms implements LFQ through OpenMS ProteomicsLFQ, which handles chromatographic feature detection, cross-run alignment, match-between-runs (MBR), and protein-level aggregation in a single step.

---

## How LFQ Works in quantms

1. **Database search** — Raw spectra are searched against a protein FASTA database (Comet, MS-GF+, or Sage)
2. **PSM rescoring** — MS2PIP + DeepLC + Percolator improve identification rates by 10–30%
3. **Feature detection** — Chromatographic features (MS1 isotope patterns) are detected per run using the OpenMS `FeatureFinderIdentificationBased` algorithm
4. **Feature alignment** — Features are aligned across runs using retention time correction to account for LC variation
5. **Match-between-runs** — Peptides identified in one run are transferred to runs where the same feature is detected but not identified, reducing missing values
6. **Protein quantification** — Peptide intensities are aggregated to the protein level (MaxLFQ algorithm by default)

---

## Feature Detection and Alignment

quantms uses identification-guided feature detection: chromatographic features are seeded by confident PSMs rather than relying on de novo peak picking across the full mass range. This improves sensitivity in complex samples.

Feature alignment uses a map-aligner to correct systematic RT shifts. With `--targeted_only false` (default), all high-confidence features are used for alignment. For targeted workflows where you want to restrict quantification to peptides with direct identifications, set `--targeted_only true`.

---

## When to Use LFQ vs TMT

| Aspect | LFQ | TMT/iTRAQ |
|--------|-----|-----------|
| Multiplexing | One sample per raw file | 6–18 samples per raw file |
| Dynamic range | Higher (no ratio compression) | Moderate (ratio compression at MS2) |
| Missing values | More frequent across runs | Fewer (within-plex MS2 always present) |
| Throughput | Lower (more instrument time) | Higher (many samples per run) |
| Best for | Discovery, large clinical cohorts, plasma | Precise quantification, time-course, paired designs |
| Cost | Lower reagent cost | Reagent cost + complexity |

Use LFQ when you have many samples to profile at discovery scale and can tolerate more missing values. Use TMT/iTRAQ when you need precise ratios, have many replicates to pack into a single run, or are designing phosphoproteomics studies.

---

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--protein_quant` | `true` | Run protein quantification (ProteomicsLFQ) |
| `--targeted_only` | `false` | Restrict quantification to directly identified features |
| `--mass_recalibration` | `false` | Perform m/z recalibration before feature detection |
| `--add_triqler_output` | `false` | Generate Triqler-format output for Bayesian protein quantification |
| `--quantification_method` | `feature_intensity` | `feature_intensity` or `spectral_counting` |
| `--protein_inference_method` | `aggregation` | Protein grouping: `aggregation` or `bayesian` |
| `--protein_level_fdr_cutoff` | `0.05` | Protein-level FDR threshold |
| `--psm_pep_fdr_cutoff` | `0.05` | PSM/peptide FDR before quantification |

### Example Run

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input experiment.sdrf.tsv \
    --database uniprot_human.fasta \
    --search_engines "comet msgf" \
    --use_ms2pip true \
    --use_deeplc true \
    --protein_quant true \
    --targeted_only false \
    --protein_level_fdr_cutoff 0.01 \
    --outdir results_lfq/
```

---

## Expected Output Files

| File | Location | Description |
|------|----------|-------------|
| `out.mzTab` | `quant_tables/` | Primary result: PSMs, peptides, and protein quantities |
| `msstats_in.csv` | `quant_tables/` | Long-format table for MSstats differential expression |
| `out_msstats.mzTab` | `msstats/` | mzTab with MSstats input format |
| `peptide_out.tsv` | `quant_tables/` | Peptide-level quantities from ProteinQuantifier |
| `protein_out.tsv` | `quant_tables/` | Protein-level quantities from ProteinQuantifier |
| `out.consensusXML` | `quant_tables/` | OpenMS ConsensusXML (for debugging or OpenMS tools) |
| `multiqc_report.html` | `pmultiqc/` | Interactive QC report |

See [Output](output.md) for a full description of each file.

---

## Tips for Large Cohorts

- **Use SDRF input** — SDRF encodes all search parameters in a single file, preventing parameter mismatches across large studies.
- **Split into batches** — For datasets with hundreds of raw files, consider batching by fractionation or plate to keep alignment tractable.
- **Set `--targeted_only true`** for strictly identified-only results if you need to minimize false features in very large cohorts.
- **Enable rescoring** — ML rescoring (`--use_ms2pip true --use_deeplc true`) is especially valuable when sample quality varies across a cohort, as it adapts to each run's RT and fragmentation characteristics.
- **Use Singularity on HPC** — Replace `-profile docker` with `-profile singularity` for cluster execution. Use `-resume` to restart failed runs without recomputing completed tasks.
- **Increase resources** — For runs with >100 files, increase memory limits: `--max_memory 128.GB --max_cpus 32`.
- **Reference retention time alignment** — If RT alignment is poor (check the pmultiqc report), verify that the same LC gradient was used across all runs.
