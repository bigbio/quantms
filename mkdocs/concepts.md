# Key Concepts

This page explains the core concepts behind quantms and quantitative proteomics for users who are new to the field. Each section gives a plain-language overview followed by practical notes about how the concept applies inside the pipeline.

---

## Data-Dependent Acquisition (DDA)

Data-Dependent Acquisition is the most widely used mass spectrometry strategy for proteomics. The instrument first scans a wide mass range to detect all peptide ions present in the sample (the MS1 scan). It then automatically selects the most intense ions — typically the top 10-20 — and fragments each one to produce a spectrum of smaller pieces (the MS2 scan). This fragmentation fingerprint is what gets matched against a protein database to identify the peptide.

The "data-dependent" part means the instrument decides on the fly which ions to fragment, based on their abundance. This makes DDA excellent for discovery proteomics: you find whatever is most abundant. The trade-off is that low-abundance peptides may be missed entirely if they compete with more abundant species in a complex sample.

quantms is purpose-built for DDA experiments. For DIA (Data-Independent Acquisition), where all ions in a window are fragmented simultaneously, use the companion [quantmsdiann](https://github.com/bigbio/quantmsdiann) pipeline instead.

!!! tip "DDA vs. DIA"
    DDA is generally easier to set up and analyze, and is the right choice for most discovery proteomics experiments. DIA offers more complete quantification across runs but requires spectral libraries and different analysis tools.

---

## Label-Free Quantification (LFQ)

Label-Free Quantification estimates the relative abundance of proteins across samples without any chemical modification of the peptides. Each sample is processed and analyzed in a separate LC-MS/MS run. Protein abundance is inferred from the intensity of the chromatographic peaks (MS1 features) detected for the peptides assigned to that protein.

The key challenge in LFQ is aligning and comparing features across runs, because retention times and instrument sensitivity drift between injections. quantms uses the OpenMS ProteomicsLFQ workflow for feature detection, cross-run alignment, and protein-level aggregation. The result is a matrix of protein intensities with one column per sample.

LFQ is the default quantification mode in quantms. Use it when your experiment has no chemical labels — for example, a cohort of patient samples run one at a time.

!!! tip "When to choose LFQ"
    LFQ works best for large sample cohorts (tens to hundreds of samples) where multiplexing is impractical. It has a wider linear dynamic range than isobaric labeling but is more sensitive to run-to-run technical variability.

---

## Isobaric Labeling: TMT and iTRAQ

Isobaric labeling uses chemical tags (TMT — Tandem Mass Tags, or iTRAQ — Isobaric Tags for Relative and Absolute Quantification) to label peptides from different samples before mixing them together. All labeled versions of the same peptide have the same nominal mass and co-elute as a single chromatographic peak. When the peptide is fragmented in the mass spectrometer, the tags break apart at specific mass-to-charge ratios (reporter ions) that are unique to each channel, allowing the instrument to measure the abundance of each sample simultaneously.

TMT currently supports up to 18-plex multiplexing (TMT18), meaning up to 18 samples can be measured in a single experiment. iTRAQ comes in 4-plex and 8-plex formats. Multiplexing reduces between-run variability dramatically compared to LFQ because all samples are analyzed together. The trade-off is ratio compression — very large fold changes can appear smaller than they really are due to co-isolation of interfering ions.

In quantms, the isobaric workflow is selected by setting `--labelling_type isobaric` and specifying `--label_type` (e.g. `TMT10plex`).

| Label | Channels | Typical Use |
|-------|----------|-------------|
| TMT6 | 6 | Small comparative studies |
| TMT10 / TMT11 | 10–11 | Standard discovery proteomics |
| TMT16 / TMT18 | 16–18 | Large-scale clinical studies |
| iTRAQ4 | 4 | Legacy experiments |
| iTRAQ8 | 8 | Medium-scale studies |

!!! tip "Plex design tip"
    Always include a pooled reference channel (all samples mixed) across plexes. This enables IRS (Internal Reference Scaling) normalization to remove between-plex batch effects.

---

## PSM Rescoring

After a database search, each spectrum is assigned a peptide-spectrum match (PSM) with a score representing how well the experimental spectrum matches the predicted spectrum for the candidate peptide. Traditional scoring functions use relatively simple heuristics. PSM rescoring uses machine learning to assign better scores, improving the number of peptides identified at a given false discovery rate.

quantms uses three tools in sequence:

- **MS2PIP** — Predicts the theoretical fragment ion intensities for each candidate peptide using a deep learning model trained on millions of spectra. The agreement between predicted and observed intensities becomes a powerful feature for rescoring.
- **DeepLC** — Predicts the liquid chromatography retention time for each peptide. A large deviation between predicted and observed retention time is evidence that a PSM is incorrect.
- **Percolator** — Takes the features from MS2PIP, DeepLC, and the original search engine score and trains a semi-supervised SVM classifier to distinguish correct from incorrect PSMs. This typically improves identification rates by 10–30%.

Rescoring is enabled by default when running with Docker or Singularity. It can be disabled with `--use_ms2pip false --use_deeplc false` for faster runs.

!!! tip "Use rescoring for challenging samples"
    Rescoring has the largest impact on samples with complex backgrounds, post-translational modifications, or unusual peptide properties (non-tryptic cleavage, cross-linking). For routine high-quality data it still provides a measurable improvement.

---

## SDRF — Sample and Data Relationship Format

SDRF is a tab-delimited spreadsheet format that captures both the experimental design (sample groups, conditions, biological replicates) and the computational parameters (search engine settings, modifications, tolerances) in a single file. It was developed by the PRIDE team at EMBL-EBI and is now the recommended metadata standard for public proteomics data submissions.

In quantms, the SDRF file serves as the primary input. It tells the pipeline which spectra files belong to which samples, how the samples are labeled, what enzyme was used, and what modifications to consider. Using an SDRF file avoids the need to specify dozens of command-line parameters and makes the analysis fully reproducible and shareable.

!!! tip "Start from a template"
    The [PRIDE SDRF templates](https://github.com/bigbio/sdrf-templates) repository provides ready-to-use SDRF files for common experimental designs (LFQ, TMT, phosphoproteomics). The online [SDRFEdit](https://www.ebi.ac.uk/pride/markdownpage/sdrfedit) tool lets you build and validate SDRF files without writing code.

See [Input Files](input.md) for the full list of required and optional SDRF columns.

---

## False Discovery Rate (FDR)

When you search a mass spectrum against a protein database, some fraction of the matches will be wrong — incorrect peptides that happen to score well by chance. The False Discovery Rate is the estimated proportion of incorrect identifications among all identifications above a given score threshold. An FDR of 1% means roughly 1 in 100 reported identifications is expected to be wrong.

FDR in proteomics is typically estimated using the target-decoy approach: a "decoy" database is searched alongside the real (target) database. Decoys are reversed or shuffled versions of the protein sequences that cannot be correct matches. The number of decoy hits that pass the threshold is used to estimate the number of false positives among the target hits. quantms generates decoys automatically (`--add_decoys true` by default) and applies FDR filtering at both the PSM/peptide level (`--fdr_threshold`) and the protein level (`--protein_level_fdr_cutoff`).

The standard FDR threshold in proteomics is 1% (0.01). Stricter thresholds (e.g., 0.001) reduce false positives but also reduce the number of identifications.

!!! tip "FDR is not per-PSM probability"
    A 1% FDR does not mean each individual identification has a 99% chance of being correct. It is a population-level estimate. If you identify 1000 proteins at 1% FDR, roughly 10 of them are expected to be false positives.

---

## mzTab Format

mzTab is an open, tab-delimited file format defined by the HUPO-PSI (Proteomics Standards Initiative) for reporting peptide and protein identifications and quantification values from proteomics experiments. It is the final output format produced by quantms after protein quantification and is required for data submission to public repositories such as PRIDE.

An mzTab file contains three main sections: metadata (MTD), protein-level results (PRH/PRT), peptide-level results (PEH/PEP), and PSM-level results (PSH/PSM). Each row in the protein section contains the protein accession, identification scores, and the quantified intensity or ratio for each sample. mzTab files can be read by most downstream analysis tools, including the [mokume](https://mokume.quantms.org) library.

quantms produces both the full mzTab file (`*_out.mzTab`) and a simplified quantification table for convenience.

!!! tip "Downstream analysis"
    The [mokume](https://github.com/bigbio/mokume) library can read mzTab files and QPX parquet files for further normalization, differential expression analysis, and visualization.

---

## QPX Format

QPX (Quantitative Proteomics Exchange) is a parquet-based file format introduced in the quantms ecosystem as a more efficient alternative to mzTab for large-scale studies. Parquet is a columnar binary format that supports compression and fast column-level access, making it well-suited for large datasets with thousands of samples or millions of PSMs.

A QPX dataset is a directory containing one parquet file per data level (PSMs, features, peptides, proteins) plus a metadata JSON file. The format is read natively by the [mokume](https://github.com/bigbio/mokume) and [qpx](https://github.com/bigbio/qpx) libraries. QPX files are significantly smaller than equivalent mzTab files and load much faster in Python.

!!! tip "Converting between formats"
    The [qpx](https://github.com/bigbio/qpx) command-line tool converts between mzTab, QPX, and other formats. Use `qpx convert --from mztab --to qpx input.mzTab output_dir/` to convert pipeline outputs for use with mokume.
