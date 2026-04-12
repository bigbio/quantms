# Input Files

quantms accepts three types of input: an SDRF metadata file (recommended), a CSV samplesheet, and a protein FASTA database. Optionally, an isotope correction matrix can be provided for isobaric experiments.

---

## SDRF File (Recommended)

The [Sample and Data Relationship Format (SDRF)](https://pubs.acs.org/doi/abs/10.1021/acs.jproteome.0c00376) is a tab-delimited metadata format that encodes both experimental design and file references in one file. It is the recommended input for quantms because it fully specifies all search parameters, avoiding the need to pass them individually on the command line.

```bash
--input /path/to/experiment.sdrf.tsv
```

### Required SDRF Columns

| Column | Description | Example |
|--------|-------------|---------|
| `source name` | Unique sample identifier | `sample1` |
| `comment[file uri]` | Path or URI to the spectra file | `file:///data/run1.mzML` |
| `comment[label]` | Labeling type | `label free sample` or `TMT10plex-126` |
| `comment[fraction identifier]` | Fraction number | `1` |
| `comment[data file]` | Raw file name | `run1.raw` |
| `characteristics[organism]` | Species | `Homo sapiens` |

### Common Optional SDRF Columns

| Column | Description |
|--------|-------------|
| `comment[cleavage agent details]` | Enzyme (e.g. `MS:1001251` for Trypsin) |
| `comment[modification parameters]` | Fixed and variable modifications |
| `comment[precursor mass tolerance]` | Precursor tolerance (e.g. `10 ppm`) |
| `comment[fragment mass tolerance]` | Fragment tolerance (e.g. `0.02 Da`) |
| `comment[dissociation method]` | `HCD`, `CID`, `ETD` |
| `factor value[disease]` | Experimental condition for DE analysis |

### SDRF File Extensions

The SDRF file may use any of these extensions: `.sdrf.tsv`, `.sdrf`, `.tsv`, `.csv`

### Example SDRF Fragment

```tsv
source name	comment[file uri]	comment[label]	comment[fraction identifier]	characteristics[organism]	factor value[disease]
ctrl_1	file:///data/ctrl_1.mzML	label free sample	1	Homo sapiens	healthy
ctrl_2	file:///data/ctrl_2.mzML	label free sample	1	Homo sapiens	healthy
case_1	file:///data/case_1.mzML	label free sample	1	Homo sapiens	NASH
case_2	file:///data/case_2.mzML	label free sample	1	Homo sapiens	NASH
```

### SDRF Resources

- [SDRF-Proteomics specification](https://github.com/bigbio/proteomics-sample-metadata)
- [SDRFEdit — visual SDRF editor](https://www.ebi.ac.uk/pride/markdownpage/sdrfedit)
- [PRIDE SDRF templates](https://github.com/bigbio/sdrf-templates)

---

## CSV Samplesheet

A CSV samplesheet is a simpler alternative when you do not need full SDRF metadata. Pass it with `--input`.

### Minimum Required Columns

| Column | Description |
|--------|-------------|
| `spectra_file` | Absolute path or URI to the spectra file |

### Full Example

```csv
spectra_file,sample_name,condition,replicate
/data/sample1.mzML,ctrl_1,control,1
/data/sample2.mzML,ctrl_2,control,2
/data/sample3.mzML,treat_1,treatment,1
/data/sample4.mzML,treat_2,treatment,2
```

When using a CSV samplesheet, specify search parameters (enzyme, modifications, tolerances) directly on the command line or in a params file. See [Usage](usage.md) for details.

---

## Spectra Files

### Supported Formats

| Format | Extension | Notes |
|--------|-----------|-------|
| mzML | `.mzML` | Preferred open standard; used directly |
| Thermo RAW | `.raw` | Auto-converted to mzML via ThermoRawFileParser |
| Bruker timsTOF | `.d` | Converted when `--convert_dotd true` |

### Compressed Variants

Compressed spectra files are accepted for `.raw`, `.mzML`, and `.d`:

- `.gz` — gzip
- `.tar` — tar archive
- `.tar.gz` / `.tgz` — tar + gzip
- `.zip` — zip

Files are automatically decompressed before processing. Decompressed intermediates can be cached locally.

### Remote Files

Files can be referenced by URI in the SDRF `comment[file uri]` column or the CSV `spectra_file` column:

```
# Local
file:///data/run1.mzML

# AWS S3
s3://my-bucket/data/run1.mzML

# HTTP
https://ftp.pride.ebi.ac.uk/pride/data/archive/2023/01/PXD012345/run1.raw
```

---

## Protein FASTA Database

A standard FASTA file containing the protein sequences to search against.

```bash
--database /path/to/proteome.fasta
```

### Recommendations

- Use reviewed UniProt sequences for standard proteomics
- Remove stop-codon characters (`*`) — different search engines handle them differently
- Decoy sequences are added automatically by the pipeline (`--add_decoys true` by default)
- Contaminants (e.g. cRAP) can be appended before running

### Example (downloading from UniProt)

```bash
# Human reviewed proteome
wget "https://rest.uniprot.org/uniprotkb/stream?format=fasta&query=organism_id:9606+AND+reviewed:true" \
    -O uniprot_human_reviewed.fasta
```

---

## TMT / iTRAQ Correction Matrix (Optional)

For isobaric labeling experiments, you can supply an isotope correction matrix to account for isotopic impurities in the reagent lots.

```bash
--isotope_correction_file /path/to/correction_matrix.tsv
```

The correction matrix is a tab-delimited file with one row per TMT/iTRAQ channel. The exact format follows the [OpenMS IsobaricAnalyzer](https://openms.readthedocs.io/en/latest/) convention. Correction matrices are typically provided by reagent manufacturers (e.g., Thermo Fisher TMT lot-specific correction factors).

If no correction matrix is provided, the pipeline uses default values (equal isotope distribution — no correction).

---

## Input Summary Table

| Input | Flag | Required | Format |
|-------|------|----------|--------|
| SDRF or samplesheet | `--input` | Yes | `.sdrf.tsv` or `.csv` |
| Protein database | `--database` | Yes | `.fasta` |
| Spectra files | (referenced from input) | Yes | `.mzML`, `.raw`, `.d` |
| Isotope correction | `--isotope_correction_file` | No | `.tsv` |
