# PSM Rescoring

PSM rescoring re-ranks peptide-spectrum matches (PSMs) after the initial database search using machine-learning features beyond the native search engine score. In quantms, rescoring combines fragment ion intensity predictions (MS2PIP), retention time predictions (DeepLC), and a semi-supervised discriminative model (Percolator) to achieve 10–30% more identifications at the same FDR compared to search engine scores alone.

Rescoring is enabled by default when running with Docker or Singularity containers.

---

## Why Rescoring Improves Results

Database search engines score spectra using relatively simple features (e.g., Xcorr, E-value, hyperscore). Many correct PSMs score poorly because they come from low-abundance peptides or unusual fragmentation patterns. Rescoring adds orthogonal information:

- **Predicted fragment intensities** distinguish true matches from false ones based on how well the observed spectrum matches a physics-based model of the expected spectrum
- **Predicted retention time** catches decoys that have the right mass but would never elute at that position on the LC column
- Together, these features dramatically separate the score distributions of correct and incorrect PSMs, giving Percolator more power to push the FDR boundary

Typical gains: **10–30% more peptide identifications** at 1% FDR, with larger gains on complex samples and lower-abundance fractions.

---

## MS2PIP — Fragment Ion Intensity Prediction

[MS2PIP](https://github.com/compomics/ms2pip) predicts the expected fragment ion spectrum (b- and y-ion intensities) for any peptide sequence using a gradient boosting model trained on millions of experimental spectra.

For each PSM, quantms computes the Pearson correlation and other spectral similarity metrics between the observed spectrum and the MS2PIP prediction. These features are passed to Percolator as rescoring inputs.

### Selecting the MS2PIP Model

Choose the model matching your fragmentation method and sample type:

| Model | Fragmentation | Notes |
|-------|--------------|-------|
| `HCD2021` | HCD | Default; most Orbitrap datasets |
| `CID` | CID | Older instruments, ion trap MS2 |
| `TMT` | HCD + TMT | TMT-labeled peptides |
| `phospho` | HCD | Phosphopeptide-optimized |

```bash
--ms2pip_model HCD2021    # default
--ms2pip_model TMT        # for isobaric experiments
```

---

## DeepLC — Retention Time Prediction

[DeepLC](https://github.com/compomics/DeepLC) predicts peptide retention times on reversed-phase LC using a deep learning model based on peptide physicochemical properties.

Predicted vs. observed RT differences are computed for each PSM and used as a rescoring feature. The model is calibrated automatically using a set of high-confidence PSMs from each run, making it robust to different LC gradients and column types.

DeepLC is particularly effective at removing false positives from short peptides that happen to match a spectrum but would never be retained at that RT on a C18 column.

```bash
--use_deeplc true    # enabled by default
```

---

## Percolator — FDR Control

[Percolator](https://github.com/percolator/percolator) is a semi-supervised support vector machine that learns to separate target from decoy PSMs using a vector of features including:

- Search engine score (Xcorr, E-value, hyperscore, etc.)
- MS2PIP spectral angle and Pearson correlation
- DeepLC RT prediction error
- Charge state, peptide length, missed cleavages
- Delta scores between top and second-ranked PSMs

Percolator re-scores all PSMs, computes q-values using target-decoy competition, and applies the FDR threshold (`--fdr_threshold`, default 0.01). It always runs as the final step in the rescoring chain when MS2PIP or DeepLC is enabled.

---

## AlphaPeptDeep Integration

[AlphaPeptDeep](https://github.com/MannLabs/alphapeptdeep) is an alternative deep-learning framework for peptide property prediction developed by the Mann lab. It can predict fragment intensities and retention times, similar to MS2PIP + DeepLC, but uses a unified transformer-based architecture.

AlphaPeptDeep is available as an alternative to MS2PIP in quantms. It is particularly useful for:

- Non-tryptic peptides (limited MS2PIP model coverage)
- Unusual modifications not covered by the standard MS2PIP models
- Experiments where the AlphaPeptDeep model transfer-learning API can be used with project-specific training data

To use AlphaPeptDeep, set:

```bash
--use_ms2pip false
--use_alpha_pept_deep true
```

---

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--use_ms2pip` | `true` | Enable MS2PIP fragment intensity prediction |
| `--use_deeplc` | `true` | Enable DeepLC retention time prediction |
| `--ms2pip_model` | `HCD2021` | MS2PIP prediction model |
| `--deeplc_calibration_set_size` | `0.15` | Fraction of PSMs used for RT calibration |
| `--use_alpha_pept_deep` | `false` | Use AlphaPeptDeep instead of MS2PIP |
| `--fdr_threshold` | `0.01` | PSM/peptide FDR threshold after rescoring |

---

## Performance Impact

| Scenario | Typical gain |
|----------|-------------|
| HCD data, Orbitrap, standard proteome | +15–25% peptide IDs at 1% FDR |
| Complex samples (plasma, tissue) | +20–30% |
| Simple samples (cell culture, purified) | +10–15% |
| Phosphoproteomics | +15–20% with `--ms2pip_model phospho` |
| TMT experiments | +10–20% with `--ms2pip_model TMT` |

Rescoring adds computation time (roughly 20–40% longer wall-clock time depending on dataset size), but the identification gain is almost always worth the cost for downstream quantification quality.

---

## Disabling Rescoring

For rapid exploratory runs or when container access is not available:

```bash
--use_ms2pip false
--use_deeplc false
```

Without rescoring, Percolator still runs using only the native search engine features, which still improves over the raw engine score but without the spectral and RT similarity features.
