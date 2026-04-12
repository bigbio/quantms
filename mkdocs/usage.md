# Usage

## Running the Pipeline

quantms takes mass spectrometry data (DDA only) and a protein FASTA database as input. The recommended way to describe your experiment is using an SDRF file.

### With SDRF Input (Recommended)

The [Sample and Data Relationship Format (SDRF)](https://pubs.acs.org/doi/abs/10.1021/acs.jproteome.0c00376) is the recommended input format. It encodes both sample metadata and file paths in a single tab-delimited file.

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input /path/to/experiment.sdrf.tsv \
    --database /path/to/proteindatabase.fasta \
    --outdir results/
```

The SDRF file must use a `comment[file uri]` column to reference spectra files. Supported spectra file formats are `.raw`, `.mzML`, and `.d`. SDRF-driven runs automatically configure search engine parameters (enzyme, modifications, tolerances) from the file metadata.

### With a CSV Samplesheet

Alternatively, provide a CSV samplesheet with a `spectra_file` column:

```csv
spectra_file,sample_name,condition,replicate
/data/sample1.mzML,ctrl_1,control,1
/data/sample2.mzML,ctrl_2,control,2
/data/sample3.mzML,treat_1,treatment,1
/data/sample4.mzML,treat_2,treatment,2
```

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input samplesheet.csv \
    --database uniprot_human.fasta \
    --outdir results/
```

### Using a Parameters File

For reproducible runs and easy sharing, store parameters in a YAML file:

```yaml title="params.yaml"
input: /data/experiment.sdrf.tsv
database: /data/uniprot_human.fasta
outdir: results/
search_engines: comet
add_decoys: true
fdr_threshold: 0.01
```

```bash
nextflow run bigbio/quantms -profile docker -params-file params.yaml
```

### Specifying a Pipeline Version

Pin a specific release for reproducibility:

```bash
nextflow run bigbio/quantms -r 1.3.0 -profile docker -params-file params.yaml
```

### Keeping the Pipeline Up to Date

```bash
nextflow pull bigbio/quantms
```

---

## Search Engine Configuration

quantms supports three peptide search engines. They can be run individually or in combination (multi-engine mode triggers ConsensusID for result merging).

### Comet

[Comet](https://comet-ms.sourceforge.net/) is the default engine.

```bash
--search_engines comet
--precursor_mass_tolerance 10
--precursor_mass_tolerance_unit ppm
--fragment_mass_tolerance 0.02
--fragment_mass_tolerance_unit Da
```

### MS-GF+

[MS-GF+](https://msgfplus.github.io/) is particularly well-suited for data from instruments with high-resolution MS2.

```bash
--search_engines msgf
```

### Sage

[Sage](https://github.com/lazear/sage) is a fast, Rust-based search engine well-suited for large datasets.

```bash
--search_engines sage
```

### Multi-Engine Mode

Running two or more engines improves sensitivity. Results are merged with OpenMS ConsensusID.

```bash
--search_engines "comet msgf"
```

### Common Search Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--precursor_mass_tolerance` | `10` | Precursor mass tolerance |
| `--precursor_mass_tolerance_unit` | `ppm` | Unit: `ppm` or `Da` |
| `--fragment_mass_tolerance` | `0.02` | Fragment mass tolerance |
| `--fragment_mass_tolerance_unit` | `Da` | Unit: `Da` or `ppm` |
| `--enzyme` | `Trypsin` | Digest enzyme (e.g. `Trypsin`, `LysC`) |
| `--fixed_mods` | `Carbamidomethyl (C)` | Fixed modifications |
| `--variable_mods` | `Oxidation (M)` | Variable modifications |
| `--num_hits` | `1` | PSMs reported per spectrum |
| `--add_decoys` | `true` | Generate decoys automatically |
| `--fdr_threshold` | `0.01` | PSM/peptide FDR cutoff |

> When running with an SDRF file, search parameters defined in the SDRF take precedence over command-line parameters.

---

## PSM Rescoring

ML-based rescoring with MS2PIP, DeepLC, and Percolator typically improves peptide identification rates by 10-30%. Rescoring is enabled by default when Docker/Singularity is used.

### Enable / Disable Rescoring

```bash
# Rescoring on (default)
--use_ms2pip true
--use_deeplc true

# Skip rescoring
--use_ms2pip false
--use_deeplc false
```

### MS2PIP Model

MS2PIP predicts fragment ion intensities. Specify the model matching your fragmentation method:

```bash
--ms2pip_model HCD2021     # HCD fragmentation (default)
--ms2pip_model CID         # CID fragmentation
--ms2pip_model TMT         # TMT-labeled peptides
```

### DeepLC

DeepLC predicts retention times. Calibration is automatic using high-confidence PSMs.

```bash
--use_deeplc true
```

### Percolator

Percolator re-ranks PSMs using a semi-supervised SVM. It always runs as the final rescoring step when `--use_ms2pip` or `--use_deeplc` is enabled.

---

## Protein Quantification

### Label-Free Quantification (LFQ)

LFQ estimates protein abundance from MS1 feature intensities. ProteomicsLFQ (OpenMS) handles feature detection, alignment, and aggregation.

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input experiment.sdrf.tsv \
    --database uniprot_human.fasta \
    --outdir results/
```

Key LFQ parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--quantification_method` | `feature_intensity` | `feature_intensity` or `spectral_counting` |
| `--protein_inference_method` | `aggregation` | Protein grouping method |
| `--protein_level_fdr_cutoff` | `0.05` | Protein-level FDR |

### Isobaric Labeling (TMT / iTRAQ)

For multiplexed experiments with TMT or iTRAQ labels, set `--labelling_type isobaric` (or encode this in the SDRF).

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input experiment_tmt.sdrf.tsv \
    --database uniprot_human.fasta \
    --labelling_type isobaric \
    --label_type TMT10plex \
    --outdir results/
```

Supported isobaric labels:

| Label | Plex | Flag |
|-------|------|------|
| TMT6 | 6-plex | `--label_type TMT6plex` |
| TMT10 | 10-plex | `--label_type TMT10plex` |
| TMT11 | 11-plex | `--label_type TMT11plex` |
| TMT16 | 16-plex | `--label_type TMT16plex` |
| TMT18 | 18-plex | `--label_type TMT18plex` |
| iTRAQ4 | 4-plex | `--label_type iTRAQ4plex` |
| iTRAQ8 | 8-plex | `--label_type iTRAQ8plex` |

---

## Common Parameter Combinations

### High-sensitivity LFQ run (large cohort)

```bash
nextflow run bigbio/quantms -r 1.3.0 \
    -profile singularity \
    --input cohort.sdrf.tsv \
    --database uniprot_human_reviewed.fasta \
    --search_engines "comet msgf" \
    --use_ms2pip true \
    --use_deeplc true \
    --fdr_threshold 0.01 \
    --protein_level_fdr_cutoff 0.01 \
    --outdir results/
```

### Fast single-engine LFQ run

```bash
nextflow run bigbio/quantms -r 1.3.0 \
    -profile docker \
    --input experiment.sdrf.tsv \
    --database proteome.fasta \
    --search_engines comet \
    --use_ms2pip false \
    --use_deeplc false \
    --outdir results/
```

### TMT11 phosphoproteomics

```bash
nextflow run bigbio/quantms -r 1.3.0 \
    -profile singularity \
    --input phospho_tmt11.sdrf.tsv \
    --database uniprot_human.fasta \
    --labelling_type isobaric \
    --label_type TMT11plex \
    --variable_mods "Oxidation (M),Phospho (STY)" \
    --onsite_algorithm phosphors \
    --outdir results/
```

---

## PTM Localization

When phosphorylation or other site-specific PTMs are of interest, enable PTM localization with the `onsite` module.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--onsite_algorithm` | `lucxor` | `lucxor`, `ascore`, or `phosphors` |
| `--onsite_fragment_method` | `CID` | `CID` or `HCD` |
| `--onsite_fragment_tolerance` | `0.5` | Fragment mass tolerance |
| `--onsite_fragment_error_units` | `Da` | `Da` or `ppm` |

---

## Nextflow Execution Options

### Compute Profiles

| Profile | Flag | Notes |
|---------|------|-------|
| Docker | `-profile docker` | Recommended for local use |
| Singularity | `-profile singularity` | Recommended for HPC |
| Podman | `-profile podman` | Alternative container runtime |
| Conda | `-profile conda` | Fallback when containers unavailable |
| Test | `-profile test,docker` | Runs a built-in small dataset |

Multiple profiles can be combined: `-profile test,docker`

### Resume a Run

```bash
nextflow run bigbio/quantms -resume -profile docker -params-file params.yaml
```

Nextflow reuses cached results for steps whose inputs have not changed.

### Resource Limits

```bash
--max_cpus 16
--max_memory 128.GB
--max_time 24.h
```

### Running in the Background

```bash
nextflow run bigbio/quantms -bg -profile docker -params-file params.yaml
```

Or use `screen` / `tmux` for interactive sessions.

### Limit JVM Memory (Nextflow)

Add to `~/.bashrc` or `~/.bash_profile` to cap Nextflow's own Java process:

```bash
export NXF_OPTS='-Xms1g -Xmx4g'
```

---

## Cloud Execution

quantms runs on any cloud backend supported by Nextflow.

### AWS Batch

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input s3://bucket/experiment.sdrf.tsv \
    --database s3://bucket/uniprot.fasta \
    --outdir s3://bucket/results/ \
    -work-dir s3://bucket/work/
```

### Google Cloud Life Sciences

```bash
nextflow run bigbio/quantms \
    -profile docker \
    --input gs://bucket/experiment.sdrf.tsv \
    --outdir gs://bucket/results/ \
    -work-dir gs://bucket/work/
```

### Azure Batch

```bash
nextflow run bigbio/quantms \
    -profile azurebatch \
    --input az://container/experiment.sdrf.tsv \
    --outdir az://container/results/ \
    -work-dir az://container/work/
```

---

## Custom Container Versions

Override the container for a specific process using a custom Nextflow config:

```nextflow title="custom.config"
process {
    withName: 'COMET' {
        container = 'quay.io/biocontainers/comet-ms:2024.01.0--h4ac6f70_0'
    }
}
```

```bash
nextflow run bigbio/quantms -profile docker -c custom.config -params-file params.yaml
```

> Use `-c` only for process resource overrides or container replacements — do not use `-c` to pass pipeline parameters.
