# Workflows

quantms supports two DDA proteomics workflows. Choose based on your experimental design.

## DDA-LFQ (Label-Free Quantification)

For experiments without chemical labeling. Protein abundance is estimated from peptide ion intensities.

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input samplesheet.csv \
    --database uniprot_human.fasta \
    --outdir results/
```

### Pipeline Steps

1. **File conversion** — Raw files converted to mzML (ThermoRawFileParser)
2. **Database search** — Peptide identification with Comet and/or MS-GF+
3. **PSM rescoring** — ML-based rescoring with MS2PIP + DeepLC + Percolator
4. **Peptide indexing** — FDR filtering and protein inference
5. **Feature detection** — Chromatographic feature finding (OpenMS)
6. **Feature linking** — Align and match features across runs
7. **Protein quantification** — Aggregate peptide intensities to protein level
8. **Quality control** — Generate pmultiqc interactive QC report

### Input Requirements

- Raw files: `.mzML`, `.raw` (Thermo), or `.d` (Bruker)
- FASTA database: protein sequences for search
- Sample sheet: CSV mapping files to samples and conditions

### Sample Sheet Format

```csv
sample,spectra_file,sdrf_file,condition
sample1,/path/to/sample1.mzML,experiment.sdrf.tsv,control
sample2,/path/to/sample2.mzML,experiment.sdrf.tsv,treatment
```

## DDA-ISO (Isobaric Labeling: TMT/iTRAQ)

For multiplexed experiments using TMT or iTRAQ chemical labels.

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input samplesheet.csv \
    --database uniprot_human.fasta \
    --labelling_type isobaric \
    --outdir results/
```

### Pipeline Steps

1. **File conversion** — Raw to mzML
2. **Database search** — With reporter ion extraction
3. **PSM rescoring** — ML rescoring + FDR control
4. **Reporter ion quantification** — Extract TMT/iTRAQ channel intensities
5. **Protein summarization** — Aggregate to protein level per channel
6. **Normalization** — Median normalization across channels
7. **Quality control** — pmultiqc report with TMT-specific plots

### Supported Labels

| Label | Plex | Flag |
|-------|------|------|
| TMT6 | 6-plex | `--label_type TMT6plex` |
| TMT10 | 10-plex | `--label_type TMT10plex` |
| TMT11 | 11-plex | `--label_type TMT11plex` |
| TMT16 | 16-plex | `--label_type TMT16plex` |
| TMT18 | 18-plex | `--label_type TMT18plex` |
| iTRAQ4 | 4-plex | `--label_type iTRAQ4plex` |
| iTRAQ8 | 8-plex | `--label_type iTRAQ8plex` |

## Choosing a Workflow

| Feature | DDA-LFQ | DDA-ISO |
|---------|---------|---------|
| Labeling | None | TMT or iTRAQ |
| Multiplexing | No (1 sample per file) | Yes (6-18 samples per file) |
| Dynamic range | Higher | Ratio compression |
| Missing values | More frequent | Fewer (within plex) |
| Best for | Discovery, large cohorts | Precise quantification, time-course |

## DIA Workflow

For DIA (Data-Independent Acquisition) experiments, use the dedicated **quantmsdiann** pipeline:

```bash
nextflow run bigbio/quantmsdiann \
    -profile docker \
    --input samplesheet.csv \
    --database uniprot_human.fasta \
    --outdir results/
```

See [quantmsdiann documentation](https://github.com/bigbio/quantmsdiann) for details.
