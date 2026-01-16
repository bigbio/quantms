# Roadmap: Targeted Proteomics Support in quantms

**Issue Reference:** [#648 - Discuss: Targeted proteomics SDRF possibility](https://github.com/bigbio/quantms/issues/648)

**Date:** January 2026

---

## Executive Summary

This roadmap addresses the request to support **targeted proteomics workflows** (SRM/MRM/PRM) in quantms, including the development of standardized metadata conventions (SDRF) for this acquisition method. The request originates from users performing absolute protein quantification using stable isotope standards spiked into human plasma, currently analyzed with Skyline software.

---

## Current State Analysis

### What quantms Currently Supports

| Acquisition Method | Quantification Type | Workflow File | Status |
|-------------------|---------------------|---------------|--------|
| DDA (Data-Dependent) | Label-Free (LFQ) | `workflows/lfq.nf` | Supported |
| DDA (Data-Dependent) | Isobaric (TMT/iTRAQ) | `workflows/tmt.nf` | Supported |
| DIA (Data-Independent) | Label-Free | `workflows/dia.nf` | Supported |
| **Targeted (SRM/MRM/PRM)** | **Absolute Quantification** | - | **Not Supported** |

### Current SDRF Acquisition Method Handling

The pipeline currently branches based on two key metadata fields (`subworkflows/local/create_input_channel/main.nf:147-151`):

```groovy
.branch {
    ch_meta_config_dia: it[0].acquisition_method.contains("dia")
    ch_meta_config_iso: it[0].labelling_type.contains("tmt") || it[0].labelling_type.contains("itraq")
    ch_meta_config_lfq: it[0].labelling_type.contains("label free")
}
```

**Gap:** No branch exists for `targeted`, `srm`, `mrm`, or `prm` acquisition methods.

### Ecosystem Landscape

| Tool/Standard | Targeted Support | Notes |
|---------------|------------------|-------|
| **Skyline** | Primary tool | Uses proprietary `.sky` format; dominant in the field |
| **OpenSWATH** | Yes | OpenMS-based; supports mzML input |
| **SDRF-Proteomics** | No | No formal definition for targeted methods |
| **mzQuantML** | Partial | Updated for SRM/PRM but limited adoption |
| **TraML** | Designed for it | Transition lists; low adoption vs Skyline |

---

## Proposed Roadmap

### Phase 1: Standards & Specification Development

**Goal:** Establish community-agreed metadata standards for targeted proteomics

#### 1.1 SDRF Extension Proposal

Create a formal proposal for the [bigbio/proteomics-metadata-standard](https://github.com/bigbio/proteomics-metadata-standard) repository:

**New Required Fields for Targeted Proteomics:**

| Field | Example Values | Description |
|-------|----------------|-------------|
| `comment[proteomics data acquisition method]` | `targeted`, `selected reaction monitoring`, `multiple reaction monitoring`, `parallel reaction monitoring` | Acquisition type (CV terms from PSI-MS) |
| `comment[transition list file]` | `method.sky`, `transitions.csv` | Reference to transition/method file |
| `comment[quantification method]` | `absolute quantification`, `relative quantification` | Type of quantification |
| `comment[internal standard type]` | `SIL peptide`, `SIL protein`, `QconCAT`, `PSAQ` | Type of isotope-labeled standard |
| `comment[standard concentration]` | `10 fmol/uL` | Concentration of spiked standards |
| `comment[standard protein]` | `P02768` | UniProt accession of standard protein |

**New Optional Fields:**

| Field | Example Values | Description |
|-------|----------------|-------------|
| `comment[dwell time]` | `20 ms` | SRM dwell time per transition |
| `comment[collision energy]` | `25 eV` | Collision energy (or `optimized`) |
| `comment[retention time window]` | `2 min` | Scheduling window |
| `comment[quantifier transition]` | `y7` | Primary quantifier ion |
| `comment[qualifier transitions]` | `y6,y5,b3` | Qualifier ions for confirmation |

**Deliverables:**
- [ ] Draft specification document (AsciiDoc format)
- [ ] Example SDRF files for common targeted proteomics scenarios
- [ ] Pull request to proteomics-metadata-standard repository
- [ ] Community review and feedback period

#### 1.2 Controlled Vocabulary Terms

Ensure proper CV terms exist in PSI-MS ontology:

```
MS:1000617 - selected reaction monitoring
MS:1000618 - multiple reaction monitoring
MS:1001838 - parallel reaction monitoring
MS:1002813 - absolute quantification
```

**Deliverable:**
- [ ] Gap analysis of missing CV terms
- [ ] Proposals to PSI-MS if needed

---

### Phase 2: Input Format Support

**Goal:** Accept diverse targeted proteomics input formats

#### 2.1 Skyline Integration

Skyline is the dominant tool; integration is essential.

**Input Options:**

| Format | Source | Priority | Complexity |
|--------|--------|----------|------------|
| Skyline exported CSV/TSV | Skyline "Export Report" | High | Low |
| `.sky` document | Native Skyline | Medium | High (needs parsing) |
| mzML + transition list | Generic | High | Medium |

**Recommended Approach:**
1. **Primary:** Accept Skyline's tabular exports (quantification reports)
2. **Secondary:** Support `.sky.zip` with bundled mzML references
3. **Alternative:** Accept mzML + TraML/CSV transition lists for non-Skyline users

**New Module: `skyline_import`**

```groovy
process SKYLINE_IMPORT {
    input:
    path skyline_report      // Skyline exported quantification report
    path transition_list     // Optional: transition definitions

    output:
    path "*.mztab", emit: mztab
    path "*.csv", emit: quantification
}
```

#### 2.2 Transition List Support

Support common transition list formats:

| Format | Tool Origin | Fields |
|--------|-------------|--------|
| Skyline CSV | Skyline | Precursor, Product m/z, CE, RT |
| TraML | PSI Standard | Full XML specification |
| PRM List | Various | Precursor m/z, charge, RT window |

**New Module: `parse_transition_list`**

#### 2.3 SDRF Parser Extension

Update `sdrf-pipelines` to handle targeted proteomics fields:

**File:** External dependency `biocontainers/sdrf-pipelines`

**Changes needed:**
- Recognize new acquisition method values
- Parse targeted-specific comment fields
- Generate appropriate configuration files

---

### Phase 3: Workflow Development

**Goal:** Create a dedicated targeted proteomics workflow

#### 3.1 New Workflow: `workflows/targeted.nf`

**Architecture:**

```
Input SDRF + Raw Files + Transition List
         │
         ▼
    ┌─────────────────┐
    │  INPUT_CHECK    │ (extended for targeted)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │FILE_PREPARATION │ (mzML conversion)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────────────────────┐
    │     TARGETED_EXTRACTION             │
    │  ┌─────────────────────────────┐   │
    │  │ Option A: OpenSWATH         │   │
    │  │ Option B: Skyline CLI       │   │
    │  │ Option C: DIAlignR/pyprophet│   │
    │  └─────────────────────────────┘   │
    └────────┬────────────────────────────┘
             │
             ▼
    ┌─────────────────┐
    │  PEAK_PICKING   │ (chromatogram extraction)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ QUANT_NORMALIZATION │ (IS-based normalization)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ABSOLUTE_QUANT   │ (calibration curves)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   MSSTATS_TMP   │ (statistical analysis)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │    PMULTIQC     │ (QC report)
    └─────────────────┘
```

#### 3.2 Core Analysis Modules

**Module 1: `TARGETED_EXTRACTION`**

Uses OpenSWATH or similar for chromatogram extraction:

```groovy
process OPENSWATH_EXTRACTION {
    container 'biocontainers/openms:3.0.0'

    input:
    tuple val(meta), path(mzml)
    path transition_library  // TraML or TSV format

    output:
    tuple val(meta), path("*.chrom.mzML"), emit: chromatograms
    tuple val(meta), path("*.osw"), emit: results
}
```

**Module 2: `PEAK_INTEGRATION`**

```groovy
process PEAK_INTEGRATION {
    // Integrate chromatographic peaks
    // Apply peak boundaries from Skyline or auto-detect
    // Calculate peak areas with proper IS normalization
}
```

**Module 3: `ABSOLUTE_QUANTIFICATION`**

```groovy
process ABSOLUTE_QUANTIFICATION {
    input:
    path peak_areas
    path standard_concentrations  // From SDRF or separate file

    output:
    path "calibration_curves.pdf", emit: curves
    path "absolute_concentrations.csv", emit: concentrations

    script:
    """
    # Fit calibration curves (linear, quadratic, etc.)
    # Calculate absolute concentrations
    # Report LOD/LOQ statistics
    """
}
```

#### 3.3 Main Workflow Integration

Update `workflows/quantms.nf` to include targeted branch:

```groovy
// Line ~70-76, add new branch:
FILE_PREPARATION.out.results
    .branch {
        dia: it[0].acquisition_method.contains("dia")
        targeted: it[0].acquisition_method.contains("targeted") ||
                  it[0].acquisition_method.contains("srm") ||
                  it[0].acquisition_method.contains("mrm") ||
                  it[0].acquisition_method.contains("prm")
        iso: it[0].labelling_type.contains("tmt") || it[0].labelling_type.contains("itraq")
        lfq: it[0].labelling_type.contains("label free")
    }
    .set { ch_fileprep_result }

// Add targeted workflow call:
TARGETED(
    ch_fileprep_result.targeted,
    CREATE_INPUT_CHANNEL.out.ch_expdesign,
    CREATE_INPUT_CHANNEL.out.ch_transition_list,  // New channel
)
```

---

### Phase 4: Statistical Analysis Adaptation

**Goal:** Provide appropriate statistical analysis for targeted data

#### 4.1 MSstatsTMT/MSstats Extension

MSstats already has support for SRM data via `dataProcess()` with appropriate feature-level input.

**Required adaptations:**
- Input converter for targeted quantification results
- IS-normalized abundance handling
- Calibration curve integration
- Absolute concentration statistics

**New Module: `MSSTATS_TARGETED`**

```groovy
process MSSTATS_TARGETED {
    container 'biocontainers/msstats:4.x'

    input:
    path quant_results
    path annotation_file

    output:
    path "*.csv", emit: results
    path "*.pdf", emit: plots
}
```

#### 4.2 Quality Metrics

Add targeted-specific QC metrics to pMultiQC:

| Metric | Description | Threshold |
|--------|-------------|-----------|
| CV% of IS | Coefficient of variation of internal standards | < 20% |
| Calibration R² | Linearity of calibration curve | > 0.99 |
| Recovery % | Spike recovery for QC samples | 80-120% |
| LOD/LOQ | Detection and quantification limits | Per analyte |
| Retention time stability | RT drift across runs | < 1 min |

---

### Phase 5: Output Standardization

**Goal:** Produce standardized, interoperable output formats

#### 5.1 Output Files

| File | Format | Content |
|------|--------|---------|
| `quantification_report.mzTab` | mzTab 1.0 | Standard proteomics format |
| `absolute_concentrations.csv` | CSV | Protein concentrations with units |
| `calibration_curves.pdf` | PDF | Visual QC of standard curves |
| `peak_areas.csv` | CSV | Raw and normalized peak areas |
| `qc_report.html` | HTML | pMultiQC report with targeted metrics |

#### 5.2 mzTab Extensions

Ensure mzTab output properly represents:
- Absolute quantities with units (fmol, ng, copies/cell)
- IS normalization factors
- Calibration curve parameters
- CV% and other precision metrics

---

### Phase 6: Documentation & Community

**Goal:** Enable adoption and gather feedback

#### 6.1 Documentation

- [ ] User guide: "Running targeted proteomics with quantms"
- [ ] Example datasets and SDRF files
- [ ] Troubleshooting guide for common issues
- [ ] Best practices for absolute quantification

#### 6.2 Test Datasets

Create test configurations similar to existing:
- `conf/tests/test_targeted_srm.config`
- `conf/tests/test_targeted_prm.config`
- `conf/tests/test_absolute_quant.config`

#### 6.3 Community Engagement

- [ ] Present proposal at HUPO-PSI meeting
- [ ] Coordinate with Skyline team for format compatibility
- [ ] Engage CPTAC/SRM Atlas communities for validation
- [ ] Publish methods paper upon completion

---

## Implementation Priority

| Phase | Priority | Dependencies | Estimated Complexity |
|-------|----------|--------------|---------------------|
| Phase 1: Standards | **Critical** | None | Medium |
| Phase 2: Input Formats | **High** | Phase 1 | Medium |
| Phase 3: Workflow | **High** | Phase 1, 2 | High |
| Phase 4: Statistics | Medium | Phase 3 | Medium |
| Phase 5: Outputs | Medium | Phase 3 | Low |
| Phase 6: Documentation | Medium | All phases | Low |

---

## Key Decisions Needed

### Decision 1: Primary Analysis Engine

| Option | Pros | Cons |
|--------|------|------|
| **OpenSWATH** | OpenMS ecosystem, well-documented | Designed for DIA-SWATH, may need adaptation |
| **Skyline CLI** | Industry standard, feature-rich | Windows-only CLI, licensing considerations |
| **Custom Python** | Full control, lightweight | Maintenance burden, validation needed |

**Recommendation:** Start with OpenSWATH for open-source compatibility, with Skyline CSV import as primary user interface.

### Decision 2: Skyline Integration Depth

| Option | Description | Effort |
|--------|-------------|--------|
| **Minimal** | Accept pre-processed Skyline exports only | Low |
| **Moderate** | Import `.sky` documents, extract data | Medium |
| **Full** | Invoke Skyline CLI for processing | High |

**Recommendation:** Start with minimal (CSV exports), expand based on user demand.

### Decision 3: Absolute Quantification Scope

| Option | Description |
|--------|-------------|
| **Relative only** | IS-normalized ratios, no absolute values |
| **Single-point** | One calibration point per standard |
| **Full calibration** | Multi-point calibration curves with LOD/LOQ |

**Recommendation:** Support full calibration curves for true absolute quantification.

---

## Technical Specifications

### New Parameters (`nextflow_schema.json`)

```json
{
  "targeted_options": {
    "title": "Targeted Proteomics Options",
    "properties": {
      "transition_list": {
        "type": "string",
        "description": "Path to transition list file (TraML, CSV, or Skyline format)"
      },
      "internal_standard_file": {
        "type": "string",
        "description": "File mapping internal standards to analytes"
      },
      "calibration_curve_points": {
        "type": "integer",
        "default": 6,
        "description": "Number of calibration points for absolute quantification"
      },
      "quantification_type": {
        "type": "string",
        "enum": ["relative", "absolute"],
        "default": "relative"
      },
      "peak_integration_method": {
        "type": "string",
        "enum": ["skyline", "openswath", "manual"],
        "default": "skyline"
      }
    }
  }
}
```

### New File Structure

```
quantms/
├── workflows/
│   └── targeted.nf              # New workflow
├── subworkflows/local/
│   ├── targeted_extraction/     # Chromatogram extraction
│   ├── peak_integration/        # Peak area calculation
│   └── absolute_quant/          # Calibration & quantification
├── modules/local/
│   ├── skyline/
│   │   ├── import_report/       # Import Skyline exports
│   │   └── parse_sky/           # Parse .sky documents
│   ├── openswath/
│   │   ├── workflow/            # OpenSWATH analysis
│   │   └── pyprophet/           # Scoring
│   └── targeted/
│       ├── calibration/         # Curve fitting
│       └── normalization/       # IS normalization
└── conf/tests/
    ├── test_targeted_srm.config
    └── test_targeted_prm.config
```

---

## Success Criteria

1. **Standards Adoption:** SDRF extension accepted by proteomics-metadata-standard
2. **User Adoption:** Successfully process 3+ real-world targeted datasets
3. **Accuracy:** Absolute quantification within 20% of Skyline results
4. **Performance:** Process 100-sample study within 2 hours
5. **Documentation:** Complete user guide and example datasets available

---

## Deep Dive: Tool Combinations for SRM/PRM Analysis

This section provides a detailed technical analysis of how existing tools can be combined to build the targeted proteomics workflow.

### Available Tools Analysis

#### 1. OpenMS/pyOpenMS Tools for Targeted Analysis

OpenMS provides the **OpenSWATH suite** which, despite being designed for DIA/SWATH, contains tools directly applicable to SRM/MRM/PRM:

| Tool | Function | Applicability |
|------|----------|---------------|
| **OpenSwathWorkflow** | Complete DIA analysis | Can process SRM-like data with adaptation |
| **MRMFeatureFinderScoring** | Peak detection in MRM chromatograms | **Directly applicable** to SRM/MRM |
| **OpenSwathChromatogramExtractor** | Extract XICs from mzML | **Directly applicable** |
| **OpenSwathAnalyzer** | Analyze transition groups | **Directly applicable** |
| **TargetedFileConverter** | Convert transition formats | TraML ↔ TSV conversion |

**pyOpenMS API (from [pyOpenMS documentation](https://pyopenms.readthedocs.io/en/latest/user_guide/chromatographic_analysis.html)):**

```python
from pyopenms import *

# Load SRM/MRM data
exp = MSExperiment()
MzMLFile().load("srm_data.mzML", exp)

# Load transition library
targeted_exp = TargetedExperiment()
TraMLFile().load("transitions.TraML", targeted_exp)

# Smooth chromatograms
smoother = SavitzkyGolayFilter()
smoother.filterExperiment(exp)

# Find and score features
ff = MRMFeatureFinderScoring()
feature_map = FeatureMap()
ff.pickExperiment(exp, feature_map, targeted_exp, TransformationDescription(), TransformationDescription())

# Score includes: var_library_dotprod (spectral similarity)
```

#### 2. pyprophet/mProphet for Statistical Scoring

[pyprophet](https://github.com/PyProphet/pyprophet) implements semi-supervised learning for FDR control:

| Feature | Description |
|---------|-------------|
| **Algorithm** | mProphet - separates true signal from decoy noise |
| **Input** | OpenSWATH `.osw` files (SQLite format) |
| **Output** | q-values for peptide-level FDR control |
| **Applicability** | Originally for SRM, now optimized for DIA |

**Integration approach:**
```bash
# After OpenSWATH extraction
pyprophet score --in=results.osw --level=ms2
pyprophet peptide --in=results.osw --context=run-specific
pyprophet protein --in=results.osw --context=global
```

#### 3. MSstats for Statistical Analysis

[MSstats](https://msstats.org/) (already in quantms) natively supports SRM:

**Existing quantms integration** (`bin/msstats_plfq.R:199`):
```r
# Current LFQ approach - adaptable for SRM
quant <- OpenMStoMSstatsFormat(data, removeProtein_with1Feature = removeOneFeatProts)
processed.quant <- dataProcess(quant, censoredInt = 'NA', featureSubset = 'top3')
```

**SRM-specific MSstats input format:**
| Column | Description | Example |
|--------|-------------|---------|
| ProteinName | Protein ID | P02768 |
| PeptideSequence | Peptide sequence | LVNEVTEFAK |
| PrecursorCharge | Precursor charge | 2 |
| FragmentIon | Transition ID | y7 |
| ProductCharge | Product charge | 1 |
| **IsotopeLabelType** | Heavy/Light | L or H |
| Condition | Sample group | Control |
| BioReplicate | Sample number | 1 |
| Run | MS run | Run_01 |
| Intensity | Peak area | 1234567 |

**Key advantage:** MSstats handles heavy/light ratios via `IsotopeLabelType` column.

#### 4. Skyline Integration Options

**Option A: Skyline Exported Reports (Recommended)**

Skyline's "Export Report" can output MSstats-compatible format directly:

```
Skyline → File → Export → Report → "MSstats Input"
```

Output columns match MSstats requirements exactly.

**Option B: SkylineRunner/SkylineCmd CLI**

Available via [Skyline Batch](https://skyline.ms/wiki/home/software/Skyline/page.view?name=documentation):
```bash
# Windows-only, but can run via Wine in containers
SkylineCmd --in=document.sky \
           --import-file=sample.raw \
           --report-name="MSstats Input" \
           --report-file=output.csv
```

**Option C: Direct .sky parsing**

The `.sky` format is XML-based and parseable:
```xml
<SrmDocument>
  <PeptideList>
    <Peptide sequence="LVNEVTEFAK">
      <Precursor charge="2">
        <Transition fragment="y7" charge="1">
          <Results>
            <TransitionPeak area="1234567" />
          </Results>
        </Transition>
      </Precursor>
    </Peptide>
  </PeptideList>
</SrmDocument>
```

#### 5. ProteoWizard msconvert

[msconvert](https://proteowizard.sourceforge.io/) handles SRM/MRM data conversion:

```bash
msconvert sample.raw \
    --mzML \
    --filter "peakPicking vendor" \
    --srmAsSpectra  # Important: treats SRM transitions as spectra
```

**Container:** Already available in quantms via `thermorawfileparser` module, but msconvert offers better SRM support.

---

### Recommended Tool Combination Strategy

Based on the analysis, here's the optimal architecture:

```
┌─────────────────────────────────────────────────────────────────────┐
│                     WORKFLOW ENTRY POINTS                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  PATH A: Raw Data Processing          PATH B: Pre-processed Data   │
│  (Full pipeline)                      (Skyline exports)            │
│                                                                     │
│  ┌──────────────┐                     ┌──────────────┐             │
│  │ Raw Files    │                     │ Skyline CSV  │             │
│  │ (.raw, .d)   │                     │ (MSstats fmt)│             │
│  └──────┬───────┘                     └──────┬───────┘             │
│         │                                    │                      │
│         ▼                                    │                      │
│  ┌──────────────┐                            │                      │
│  │  msconvert   │                            │                      │
│  │ (ProteoWiz)  │                            │                      │
│  └──────┬───────┘                            │                      │
│         │                                    │                      │
│         ▼                                    │                      │
│  ┌──────────────┐    ┌──────────────┐        │                      │
│  │    mzML      │◄───│   TraML      │        │                      │
│  │   (SRM data) │    │ (transitions)│        │                      │
│  └──────┬───────┘    └──────────────┘        │                      │
│         │                                    │                      │
│         ▼                                    │                      │
│  ┌────────────────────────┐                  │                      │
│  │  OpenMS MRM Tools      │                  │                      │
│  │  ┌──────────────────┐  │                  │                      │
│  │  │ChromatogramExtract│  │                  │                      │
│  │  │MRMFeatureScoring │  │                  │                      │
│  │  └──────────────────┘  │                  │                      │
│  └──────────┬─────────────┘                  │                      │
│             │                                │                      │
│             ▼                                │                      │
│  ┌──────────────────┐                        │                      │
│  │    pyprophet     │                        │                      │
│  │  (FDR scoring)   │                        │                      │
│  └──────────┬───────┘                        │                      │
│             │                                │                      │
│             ▼                                ▼                      │
│  ┌─────────────────────────────────────────────┐                   │
│  │         MERGE POINT: MSstats Format         │                   │
│  │  (ProteinName, Peptide, Transition, etc.)   │                   │
│  └──────────────────────┬──────────────────────┘                   │
│                         │                                           │
│                         ▼                                           │
│  ┌─────────────────────────────────────────────┐                   │
│  │         QUANTIFICATION MODULE               │                   │
│  │  ┌─────────────────────────────────────┐   │                   │
│  │  │ Heavy/Light Ratio Calculation       │   │                   │
│  │  │ IS Normalization                    │   │                   │
│  │  │ Calibration Curve Fitting           │   │                   │
│  │  └─────────────────────────────────────┘   │                   │
│  └──────────────────────┬──────────────────────┘                   │
│                         │                                           │
│                         ▼                                           │
│  ┌─────────────────────────────────────────────┐                   │
│  │              MSstats                        │                   │
│  │  (dataProcess → groupComparison)            │                   │
│  └──────────────────────┬──────────────────────┘                   │
│                         │                                           │
│                         ▼                                           │
│  ┌─────────────────────────────────────────────┐                   │
│  │              pMultiQC                       │                   │
│  │  (QC Report with targeted metrics)          │                   │
│  └─────────────────────────────────────────────┘                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Specific Module Implementations

#### Module 1: OPENMS_CHROMATOGRAM_EXTRACTOR

```groovy
process OPENMS_CHROMATOGRAM_EXTRACTOR {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(mzml)
    path transition_library  // TraML format

    output:
    tuple val(meta), path("*.chrom.mzML"), emit: chromatograms
    path "versions.yml", emit: versions

    script:
    """
    OpenSwathChromatogramExtractor \\
        -in ${mzml} \\
        -tr ${transition_library} \\
        -out ${meta.mzml_id}.chrom.mzML \\
        -extract_MS1_traces false \\
        -rt_extraction_window ${params.rt_extraction_window ?: 300} \\
        -mz_extraction_window ${params.mz_extraction_window ?: 0.05} \\
        -threads ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        OpenMS: \$(OpenSwathChromatogramExtractor --version 2>&1 | grep 'Version' | cut -d' ' -f2)
    END_VERSIONS
    """
}
```

#### Module 2: OPENMS_MRM_FEATURE_FINDER

```groovy
process OPENMS_MRM_FEATURE_FINDER {
    tag "$meta.mzml_id"
    label 'process_medium'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(chromatograms)
    path transition_library

    output:
    tuple val(meta), path("*.featureXML"), emit: features
    tuple val(meta), path("*.osw"), emit: osw, optional: true
    path "versions.yml", emit: versions

    script:
    """
    OpenSwathAnalyzer \\
        -in ${chromatograms} \\
        -tr ${transition_library} \\
        -out ${meta.mzml_id}.featureXML \\
        -threads ${task.cpus} \\
        -algorithm:Scores:use_library_dotprod true \\
        -algorithm:stop_report_after_feature ${params.stop_report_after_feature ?: 5}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        OpenMS: \$(OpenSwathAnalyzer --version 2>&1 | grep 'Version' | cut -d' ' -f2)
    END_VERSIONS
    """
}
```

#### Module 3: SKYLINE_REPORT_CONVERTER

```groovy
process SKYLINE_REPORT_CONVERTER {
    tag "$skyline_report.Name"
    label 'process_low'

    container 'biocontainers/python:3.10'

    input:
    path skyline_report
    path experimental_design

    output:
    path "*_msstats_in.csv", emit: msstats_input
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd

    # Load Skyline report (already in MSstats format if exported correctly)
    df = pd.read_csv("${skyline_report}")

    # Required columns mapping
    required_cols = {
        'ProteinName': ['Protein Name', 'ProteinName', 'Protein'],
        'PeptideSequence': ['Peptide Sequence', 'PeptideSequence', 'Peptide Modified Sequence'],
        'PrecursorCharge': ['Precursor Charge', 'PrecursorCharge'],
        'FragmentIon': ['Fragment Ion', 'FragmentIon', 'Transition'],
        'ProductCharge': ['Product Charge', 'ProductCharge'],
        'IsotopeLabelType': ['Isotope Label Type', 'IsotopeLabelType', 'Label'],
        'Condition': ['Condition', 'Sample Group'],
        'BioReplicate': ['BioReplicate', 'Replicate'],
        'Run': ['Run', 'File Name', 'Replicate Name'],
        'Intensity': ['Intensity', 'Area', 'Total Area']
    }

    # Standardize column names
    for std_name, variants in required_cols.items():
        for var in variants:
            if var in df.columns:
                df = df.rename(columns={var: std_name})
                break

    # Write standardized output
    df.to_csv("${skyline_report.baseName}_msstats_in.csv", index=False)

    with open('versions.yml', 'w') as f:
        f.write('"${task.process}":\\n')
        f.write('    python: 3.10\\n')
        f.write('    pandas: ' + pd.__version__ + '\\n')
    """
}
```

#### Module 4: ABSOLUTE_QUANTIFICATION

```groovy
process ABSOLUTE_QUANTIFICATION {
    tag "$input_csv.Name"
    label 'process_medium'

    container 'biocontainers/bioconductor-msstats:4.14.0--r44he5774e6_0'

    input:
    path input_csv
    path standard_concentrations  // CSV: Peptide, Concentration, Unit

    output:
    path "*_absolute_quant.csv", emit: concentrations
    path "*_calibration_curves.pdf", emit: curves
    path "*_qc_metrics.csv", emit: qc_metrics
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env Rscript
    library(dplyr)
    library(ggplot2)

    # Load data
    data <- read.csv("${input_csv}")
    standards <- read.csv("${standard_concentrations}")

    # Calculate heavy/light ratios
    wide_data <- data %>%
        pivot_wider(
            id_cols = c(ProteinName, PeptideSequence, Run, Condition, BioReplicate),
            names_from = IsotopeLabelType,
            values_from = Intensity
        ) %>%
        mutate(ratio = L / H)  # Light (endogenous) / Heavy (IS)

    # Fit calibration curves for each peptide
    calibration_results <- standards %>%
        inner_join(wide_data, by = "PeptideSequence") %>%
        group_by(PeptideSequence) %>%
        do({
            model <- lm(ratio ~ Concentration, data = .)
            data.frame(
                slope = coef(model)[2],
                intercept = coef(model)[1],
                r_squared = summary(model)\$r.squared,
                LOD = 3.3 * sigma(model) / coef(model)[2],
                LOQ = 10 * sigma(model) / coef(model)[2]
            )
        })

    # Calculate absolute concentrations
    results <- wide_data %>%
        left_join(calibration_results, by = "PeptideSequence") %>%
        mutate(
            absolute_concentration = (ratio - intercept) / slope,
            unit = "fmol/uL"
        )

    # Generate calibration curve plots
    pdf("${input_csv.baseName}_calibration_curves.pdf", width = 12, height = 8)
    for (pep in unique(standards\$PeptideSequence)) {
        pep_data <- filter(wide_data, PeptideSequence == pep)
        pep_std <- filter(standards, PeptideSequence == pep)
        p <- ggplot(pep_data, aes(x = Concentration, y = ratio)) +
            geom_point() +
            geom_smooth(method = "lm") +
            labs(title = pep, x = "Concentration", y = "L/H Ratio") +
            theme_minimal()
        print(p)
    }
    dev.off()

    # Write outputs
    write.csv(results, "${input_csv.baseName}_absolute_quant.csv", row.names = FALSE)
    write.csv(calibration_results, "${input_csv.baseName}_qc_metrics.csv", row.names = FALSE)

    writeLines(c(
        '"${task.process}":',
        paste0('    R: ', R.version\$major, '.', R.version\$minor)
    ), 'versions.yml')
    """
}
```

#### Module 5: MSSTATS_SRM (adapted from existing MSSTATS_LFQ)

```groovy
process MSSTATS_SRM {
    tag "$msstats_csv_input.Name"
    label 'process_medium'

    container 'biocontainers/bioconductor-msstats:4.14.0--r44he5774e6_0'

    input:
    path msstats_csv_input

    output:
    path "*.pdf", optional: true
    path "*_comparisons.csv", emit: comparisons
    path "*_quantification.csv", emit: quantification
    path "*.log", emit: log
    path "versions.yml", emit: versions

    script:
    """
    #!/usr/bin/env Rscript
    library(MSstats)

    # Load SRM data (already in MSstats format)
    data <- read.csv("${msstats_csv_input}")

    # SRM-specific: use SRMRawData format if heavy/light pairs present
    has_isotopes <- "IsotopeLabelType" %in% colnames(data) &&
                    length(unique(data\$IsotopeLabelType)) > 1

    if (has_isotopes) {
        # Process with isotope labeling
        processed <- dataProcess(
            data,
            normalization = "globalStandards",  # Use heavy peptides
            nameStandards = unique(data\$ProteinName[data\$IsotopeLabelType == "H"]),
            censoredInt = "NA",
            summaryMethod = "TMP"
        )
    } else {
        # Standard label-free processing
        processed <- dataProcess(
            data,
            normalization = "equalizeMedians",
            censoredInt = "NA",
            summaryMethod = "TMP"
        )
    }

    # Quantification
    quant <- quantification(processed, type = "Sample")
    write.csv(quant, "${msstats_csv_input.baseName}_quantification.csv", row.names = FALSE)

    # Group comparison (if multiple conditions)
    lvls <- levels(as.factor(data\$Condition))
    if (length(lvls) > 1) {
        # Pairwise comparisons
        comparison <- groupComparison(data = processed)
        write.csv(comparison\$ComparisonResult,
                  "${msstats_csv_input.baseName}_comparisons.csv",
                  row.names = FALSE)

        # Visualization
        groupComparisonPlots(data = comparison\$ComparisonResult,
                            type = "VolcanoPlot",
                            width = 10, height = 8)
    }

    writeLines(c(
        '"${task.process}":',
        paste0('    MSstats: ', packageVersion('MSstats'))
    ), 'versions.yml')
    """
}
```

---

### Tool Compatibility Matrix

| Component | SRM | MRM | PRM | Notes |
|-----------|-----|-----|-----|-------|
| **msconvert** | ✅ | ✅ | ✅ | Use `--srmAsSpectra` flag |
| **OpenSwathChromatogramExtractor** | ✅ | ✅ | ✅ | Works with any targeted mzML |
| **MRMFeatureFinderScoring** | ✅ | ✅ | ⚠️ | PRM may need higher resolution settings |
| **pyprophet** | ✅ | ✅ | ✅ | FDR scoring works universally |
| **MSstats** | ✅ | ✅ | ✅ | Native SRM support |
| **Skyline export** | ✅ | ✅ | ✅ | Best interoperability |

---

### Reusable Components from Existing quantms

The following existing modules can be reused with minimal modification:

| Module | Location | Reuse Potential |
|--------|----------|-----------------|
| `FILE_PREPARATION` | `subworkflows/local/file_preparation` | ✅ Direct reuse for raw→mzML |
| `INPUT_CHECK` | `subworkflows/local/input_check` | ⚠️ Extend for targeted SDRF |
| `MSSTATS_LFQ` | `modules/local/msstats/msstats_lfq` | ⚠️ Adapt for SRM data |
| `PMULTIQC` | `modules/local/pmultiqc` | ⚠️ Add targeted QC metrics |
| R utility functions | `bin/msstats_utils.R` | ✅ Reuse contrast handling |

---

## References

- [Skyline Ecosystem Paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC5799042/)
- [OpenSWATH Documentation](http://openswath.org/en/latest/)
- [SDRF-Proteomics Specification](https://github.com/bigbio/proteomics-sample-metadata/blob/master/sdrf-proteomics/README.adoc)
- [PSI-MS Controlled Vocabulary](https://www.ebi.ac.uk/ols/ontologies/ms)
- [MSstats for SRM](https://msstats.org/wp-content/uploads/2020/02/MSstats_v3.18.1_manual.pdf)
- [mzQuantML Specification](http://www.psidev.info/mzquantml)

---

## Appendix: Example SDRF for Targeted Proteomics

```tsv
source name	characteristics[organism]	characteristics[disease]	characteristics[organism part]	assay name	comment[proteomics data acquisition method]	comment[label]	comment[internal standard type]	comment[standard concentration]	comment[transition list file]	comment[quantification method]	comment[instrument]	comment[data file]
Sample_1	Homo sapiens	normal	blood plasma	Run_1	parallel reaction monitoring	label free sample	SIL peptide	10 fmol/uL	transitions.csv	absolute quantification	Q Exactive HF	Sample1.raw
Sample_2	Homo sapiens	normal	blood plasma	Run_2	parallel reaction monitoring	label free sample	SIL peptide	10 fmol/uL	transitions.csv	absolute quantification	Q Exactive HF	Sample2.raw
Calibrator_L1	Homo sapiens	normal	blood plasma	Cal_L1	parallel reaction monitoring	label free sample	SIL peptide	1 fmol/uL	transitions.csv	absolute quantification	Q Exactive HF	Cal_L1.raw
Calibrator_L2	Homo sapiens	normal	blood plasma	Cal_L2	parallel reaction monitoring	label free sample	SIL peptide	5 fmol/uL	transitions.csv	absolute quantification	Q Exactive HF	Cal_L2.raw
```

---

*This roadmap is a living document and should be updated as the implementation progresses and community feedback is incorporated.*
