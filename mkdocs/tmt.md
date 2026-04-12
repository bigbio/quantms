# Isobaric Labeling (TMT / iTRAQ)

Isobaric labeling allows multiple samples to be analyzed in a single mass spectrometry run. Samples are chemically labeled with reagents that share the same nominal mass (isobaric) but fragment into distinguishable reporter ions during MS2. quantms supports TMT and iTRAQ labeling through the DDA-ISO workflow.

---

## How Isobaric Labeling Works

1. Each sample is digested and labeled with a distinct isobaric reagent channel
2. Labeled samples are pooled at equal amounts and analyzed together in a single MS run
3. At the MS1 level, labeled peptides appear as a single precursor (the reporter groups are isobaric)
4. At MS2 level, the reporter ions (low m/z region, ~126–135 Da for TMT) dissociate and provide per-channel intensities
5. Reporter ion intensities are extracted and used as a proxy for relative protein abundance across channels

This design gives fewer missing values within a plex compared to LFQ, but introduces ratio compression because co-isolated precursors contribute background signal to all channels.

---

## Supported Label Types

| Label | Plex | Reporter ions | Flag |
|-------|------|---------------|------|
| TMT6plex | 6 | 126–131 | `--label_type TMT6plex` |
| TMT10plex | 10 | 126–131 | `--label_type TMT10plex` |
| TMT11plex | 11 | 126–131C | `--label_type TMT11plex` |
| TMT16plex (TMTpro) | 16 | 126–134 | `--label_type TMT16plex` |
| TMT18plex (TMTpro) | 18 | 126–134 | `--label_type TMT18plex` |
| iTRAQ4plex | 4 | 114–117 | `--label_type iTRAQ4plex` |
| iTRAQ8plex | 8 | 113–121 | `--label_type iTRAQ8plex` |

Encode the label type in the SDRF `comment[label]` column (e.g., `TMT10plex-126`) to allow the pipeline to automatically determine the label type and channel assignments.

---

## Reporter Ion Extraction

quantms uses the OpenMS `IsobaricAnalyzer` module to extract reporter ion intensities from each MS2 spectrum. Key aspects:

- Reporter ions are extracted within a configurable mass window (default: 0.003 Da for high-resolution MS2)
- Spectra without detectable reporter ions in all channels are flagged and optionally removed
- Channel intensities are extracted as peak areas or peak heights

### Activation Methods

TMT quantification requires high-energy collisional dissociation (HCD) or higher-energy beam-type CID for efficient reporter ion generation. ETD is generally incompatible with reporter ion quantification. The dissociation method is read from the SDRF `comment[dissociation method]` column.

---

## Isotope Correction Matrices

Isobaric reagents are not isotopically pure — each channel contains small amounts of the neighboring isotopes. This causes channel crosstalk that must be corrected. quantms supports isotope correction via an optional correction matrix file.

```bash
--isotope_correction_file /path/to/correction_matrix.tsv
```

The correction matrix follows OpenMS IsobaricAnalyzer convention: one row per channel, columns for the fraction of signal contributed to adjacent channels. Lot-specific correction factors are provided by the reagent manufacturer (e.g., Thermo Fisher TMT Certificate of Analysis).

If no correction file is provided, the pipeline uses default equal-distribution values (no correction applied).

---

## Normalization

Channel-level intensities within a plex are median-normalized by default to correct for unequal mixing of labeled samples. Set `--iso_normalization false` to disable this step.

For multi-plex studies (multiple TMT plexes in the same experiment), inter-plex normalization is critical. Consider including a common reference sample (pooled mixture) in each plex and using IRS (Internal Reference Scaling) normalization in downstream tools such as [mokume](https://mokume.quantms.org).

---

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--labelling_type` | `label_free` | Set to `isobaric` for TMT/iTRAQ experiments |
| `--label_type` | — | Label reagent, e.g., `TMT10plex`, `iTRAQ4plex` |
| `--iso_normalization` | `true` | Median normalization of channel intensities within plex |
| `--isotope_correction_file` | — | Path to isotope correction matrix (optional) |
| `--min_precursor_intensity` | `1.0` | Minimum MS1 precursor intensity to include |
| `--reporter_mass_shift` | `0.003` | Mass window (Da) for reporter ion extraction |

### Example Run

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input experiment_tmt11.sdrf.tsv \
    --database uniprot_human.fasta \
    --labelling_type isobaric \
    --label_type TMT11plex \
    --iso_normalization true \
    --isotope_correction_file correction_tmt11.tsv \
    --use_ms2pip true \
    --use_deeplc true \
    --outdir results_tmt/
```

---

## Expected Output Files

| File | Location | Description |
|------|----------|-------------|
| `out.mzTab` | `quant_tables/` | PSMs, peptides, and per-channel protein quantities |
| `peptide_out.csv` | `quant_tables/` | Peptide-level quantities per channel |
| `protein_out.csv` | `quant_tables/` | Protein-level quantities per channel |
| `out_msstats_in.csv` | `quant_tables/` | MSstats-ready long-format table |
| `out_msstats.mzTab` | `msstats/` | mzTab with MSstats input format |
| `multiqc_report.html` | `pmultiqc/` | Interactive QC report with TMT channel balance plots |

The pmultiqc report includes TMT-specific visualizations: reporter ion intensity distributions per channel, channel balance, and missing value rates across the plex.

---

## Multi-Plex Studies

When combining multiple TMT plexes in a single biological study:

1. Include a **pooled reference sample** in the same channel position in every plex (commonly the last channel)
2. Use the SDRF `characteristics[pooled sample]` column to mark reference channels
3. After running quantms, use [mokume](https://mokume.quantms.org) with IRS normalization to remove inter-plex batch effects before differential expression analysis
