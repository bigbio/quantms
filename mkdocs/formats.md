# File Formats

This page describes the file formats used as input to and output from quantms.

---

## SDRF — Sample and Data Relationship Format

The [SDRF-Proteomics](https://github.com/bigbio/proteomics-sample-metadata) format is the recommended input for quantms. It is a tab-delimited file that encodes both sample metadata and search parameters in a single table, making experiments fully self-describing and reproducible.

### Column Conventions

- Column names follow a controlled vocabulary: `source name`, `comment[...]`, `characteristics[...]`, `factor value[...]`
- One row per raw file (or per channel for isobaric experiments)
- File URIs in `comment[file uri]` support local paths (`file:///`) and remote URIs (`s3://`, `https://`)

### Required Columns

| Column | Description | Example |
|--------|-------------|---------|
| `source name` | Unique sample identifier | `ctrl_1` |
| `comment[file uri]` | URI of the spectra file | `file:///data/run1.mzML` |
| `comment[label]` | Labeling type and channel | `label free sample` or `TMT10plex-126` |
| `comment[fraction identifier]` | Fraction number for fractionated samples | `1` |
| `comment[data file]` | Raw file name | `run1.raw` |
| `characteristics[organism]` | Species | `Homo sapiens` |

### Common Optional Columns

| Column | Description |
|--------|-------------|
| `comment[cleavage agent details]` | Enzyme (PSI-MS CV term, e.g. `MS:1001251` for Trypsin) |
| `comment[modification parameters]` | Fixed and variable modifications (PSI-MS CV terms) |
| `comment[precursor mass tolerance]` | e.g. `10 ppm` |
| `comment[fragment mass tolerance]` | e.g. `0.02 Da` |
| `comment[dissociation method]` | `HCD`, `CID`, `ETD` |
| `factor value[disease]` | Experimental condition for DE analysis |
| `characteristics[pooled sample]` | Marks a reference channel in TMT experiments |

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

## mzTab — Primary Result Format

[mzTab](https://github.com/HUPO-PSI/mzTab) is the HUPO-PSI standard for reporting mass spectrometry-based proteomics and metabolomics results. quantms produces mzTab as the primary output for both LFQ and TMT/iTRAQ workflows.

mzTab is a multi-section tab-delimited text file. Each line begins with a row type prefix:

| Prefix | Section |
|--------|---------|
| `MTD` | Metadata (software versions, study variables, assay definitions) |
| `PRH` | Protein table header |
| `PRT` | Protein row |
| `PEH` | Peptide table header |
| `PEP` | Peptide row |
| `PSH` | PSM table header |
| `PSM` | PSM row |

The protein section contains per-study-variable abundance values. The PSM section contains one row per identified spectrum with scores, FDR, and modified sequences.

mzTab files produced by quantms are suitable for:

- Submission to [PRIDE](https://www.ebi.ac.uk/pride/) (EBI ProteomeXchange repository)
- Direct loading into [mokume](https://mokume.quantms.org) for protein quantification
- Conversion to other formats with [qpx](https://qpx.quantms.org)

---

## MSstats CSV — Differential Expression Input

The MSstats CSV (also called `msstats_in.csv`) is a long-format table compatible with the `OpenMStoMSstats()` function in the [MSstats](https://msstats.org/) R package.

### Column Structure

| Column | Description |
|--------|-------------|
| `ProteinName` | Protein accession |
| `PeptideSequence` | Peptide sequence (with modifications) |
| `PrecursorCharge` | Precursor charge state |
| `FragmentIon` | Fragment ion identifier (LFQ) or channel (TMT) |
| `ProductCharge` | Product ion charge |
| `IsotopeLabelType` | `L` (light/LFQ) or `H` (heavy/reference) |
| `Condition` | Experimental condition |
| `BioReplicate` | Biological replicate identifier |
| `Run` | Raw file or run identifier |
| `Intensity` | Measured intensity (MS1 feature or reporter ion) |

This format is exported by quantms as input for downstream statistical analysis with the MSstats R package. quantms does not run MSstats — it produces the input file.

---

## Raw File Formats

quantms natively supports the following spectra file formats:

| Format | Extension | Notes |
|--------|-----------|-------|
| mzML | `.mzML` | Open standard; preferred input; used directly without conversion |
| Thermo RAW | `.raw` | Auto-converted to mzML via ThermoRawFileParser |
| Bruker timsTOF | `.d` | Converted when `--convert_dotd true` |

Compressed variants of all formats are accepted:

| Compression | Extension |
|-------------|-----------|
| gzip | `.gz` |
| tar | `.tar` |
| tar + gzip | `.tar.gz`, `.tgz` |
| zip | `.zip` |

Files are decompressed automatically before processing. Remote files are supported via URI in the SDRF `comment[file uri]` column: `file:///`, `s3://`, `gs://`, `https://`.

---

## QPX Parquet Format

When running the identification-only subworkflow, quantms writes PSM results in the [QPX parquet format](https://github.com/bigbio/quantms.io). QPX is a columnar binary format designed for efficient storage and querying of large-scale proteomics datasets.

QPX files are stored under `psm_tables/` in the output directory. They can be loaded with:

- **Python / pandas**: `pd.read_parquet("psm_tables/psms.parquet")`
- **DuckDB**: `SELECT * FROM read_parquet('psm_tables/*.parquet')`
- **qpx CLI**: `qpx convert --input psms.parquet --output out.mzTab`

The QPX format is the native input format for [mokume](https://mokume.quantms.org) and [qpx](https://qpx.quantms.org). For full column definitions and the QPX specification, see the [quantms.io documentation](https://github.com/bigbio/quantms.io/blob/dev/docs/psm.rst).

---

## Protein FASTA

Standard FASTA format. Decoy sequences are generated automatically by the pipeline unless `--add_decoys false` is set. Remove stop-codon characters (`*`) before use, as different search engines handle them differently.

```bash
--database /path/to/proteome.fasta
--add_decoys true     # default
```
