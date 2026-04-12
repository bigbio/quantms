# Search Engines

quantms supports three peptide database search engines: Comet, MS-GF+, and Sage. Each engine takes centroided MS2 spectra and a protein FASTA database as input and produces a list of scored PSMs. The engines can be run individually or in combination, with ConsensusID merging results for improved sensitivity.

---

## Overview

| Engine | Speed | Sensitivity | Best For |
|--------|-------|-------------|----------|
| Comet | Fast | Good | General use, large datasets, default choice |
| MS-GF+ | Moderate | Highest | High-resolution MS2, phosphoproteomics, +15% more PSMs than Comet |
| Sage | Fastest | Good | Very large datasets, cloud-scale, Rust-based |

---

## Comet

[Comet](https://comet-ms.sourceforge.net/) is the default search engine in quantms. It is widely used in the field, well-validated, and fast enough for routine datasets. Comet uses a cross-correlation scoring function (XCorr) originally developed for SEQUEST.

```bash
--search_engines comet
```

### Comet-Specific Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--precursor_mass_tolerance` | `10` | Precursor mass tolerance |
| `--precursor_mass_tolerance_unit` | `ppm` | Unit: `ppm` or `Da` |
| `--fragment_mass_tolerance` | `0.02` | Fragment ion tolerance |
| `--fragment_mass_tolerance_unit` | `Da` | Unit: `Da` or `ppm` |
| `--num_hits` | `1` | Number of PSM candidates reported per spectrum |

Comet is the recommended starting point for most datasets. It handles both high-resolution (Orbitrap) and low-resolution (ion trap) MS2 data effectively.

---

## MS-GF+

[MS-GF+](https://msgfplus.github.io/) uses a probabilistic scoring model based on the generating function of a fragmentation model. It is particularly well-suited for:

- High-resolution MS2 data (Orbitrap, QTOF)
- Unusual proteases (non-tryptic or multienzyme experiments)
- Phosphoproteomics and other PTM-rich datasets

MS-GF+ typically identifies **~15% more PSMs** than Comet on high-resolution MS2 data at the same FDR, making it valuable for sensitive analyses.

```bash
--search_engines msgf
```

MS-GF+ requires centroided spectra. quantms performs centroiding automatically if peak picking has not been applied upstream.

---

## Sage

[Sage](https://github.com/lazear/sage) is a high-performance search engine written in Rust. It is the fastest option in quantms — often 5–10× faster than Comet on the same hardware.

```bash
--search_engines sage
```

Sage uses a k-d tree-based fragment index for rapid spectrum matching and is designed for modern multi-core hardware. It is the recommended engine for:

- Datasets with hundreds of raw files
- Cloud-scale reanalysis of public proteomics data
- Rapid exploratory searches before final analysis

Sage produces scores comparable in sensitivity to Comet for standard tryptic datasets, though it may have slightly reduced sensitivity for highly modified peptides compared to MS-GF+.

---

## Multi-Engine Consensus (ConsensusID)

Running two or more engines in combination and merging results with ConsensusID improves both sensitivity (more PSMs identified by at least one engine) and specificity (PSMs confirmed by multiple engines are more reliable).

```bash
--search_engines "comet msgf"
--search_engines "comet sage"
--search_engines "comet msgf sage"
```

When more than one engine is specified, quantms automatically runs all selected engines and pipes their results through the OpenMS [ConsensusID](https://openms.readthedocs.io/) module.

### How ConsensusID Works

ConsensusID merges PSMs from multiple engines at the spectrum level:

1. For each spectrum, PSM candidates from all engines are collected
2. A consensus score is computed — by default using the `PEPMatrix` method, which combines posterior error probabilities from each engine
3. The merged PSM list is passed to Percolator for unified FDR estimation

The recommended combination for most datasets is **Comet + MS-GF+**, which provides the best sensitivity-to-speed trade-off. Adding Sage reduces wall-clock time compared to running only Comet + MS-GF+ and often produces comparable results.

---

## Which Engine to Choose

```
Is your dataset very large (>100 files) or do you need rapid turnaround?
  → Use Sage, or Sage + Comet

Do you need maximum sensitivity (phosphoproteomics, low-abundance proteome)?
  → Use MS-GF+, or Comet + MS-GF+

Standard tryptic proteomics, balanced speed and sensitivity?
  → Use Comet (default), or Comet + MS-GF+ for best results

Re-analyzing public PRIDE data at scale?
  → Use Sage for speed; add Comet if sensitivity is critical
```

For publication-quality analysis, running two engines (Comet + MS-GF+) is recommended. The additional computation time is typically 1.5–2× a single-engine run, and the sensitivity gain at the protein level is consistently 10–20%.

---

## Common Search Parameters

These parameters apply to all engines:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--enzyme` | `Trypsin` | Digest enzyme (`Trypsin`, `LysC`, `GluC`, `chymotrypsin`, etc.) |
| `--num_enzyme_termini` | `2` | Enzyme termini: `2` (fully), `1` (semi), `0` (non-specific) |
| `--allowed_missed_cleavages` | `2` | Maximum missed cleavage sites |
| `--fixed_mods` | `Carbamidomethyl (C)` | Fixed modifications |
| `--variable_mods` | `Oxidation (M)` | Variable modifications (comma-separated) |
| `--add_decoys` | `true` | Auto-generate reversed decoy sequences |
| `--fdr_threshold` | `0.01` | PSM/peptide FDR threshold |

> When running from an SDRF file, search parameters encoded in the SDRF (`comment[cleavage agent details]`, `comment[modification parameters]`, tolerances) take precedence over command-line values.
