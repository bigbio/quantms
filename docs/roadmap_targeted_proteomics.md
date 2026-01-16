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
