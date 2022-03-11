Modification localization
=========================

Mass spectrometry (MS) proteomics is widely used to identified and quantify post-translation modifications in complex biological samples. In a typical (MS) proteomics experiment , the resulted spectra are most commonly identified with sequence search engines such as Comet, and MS-GF+ (read more details: :doc:`identification`).

In each of these softwares and tools, the correct peptide sequence is often identified and the possible location of a PTM assigned. Yet, the confidence with which the modification is localized in the event of multiple possible amino acid residues is often not well characterized. Most search engines provide the best matching peptide ion sequence and locations for PTMs, often with a confidence score quantifying the likelihood that the peptide ion sequence is correct, but do not generally provide confidence metrics for the PTM site assignments.

Robust metrics for local and global false localization rates (FLR) should always be computed to complement the global and local false discovery rate (FDR) metrics that are currently commonly reported for peptide ion identification results (as reviewed in [CHALKLEY2012]_).

PTM localization in quantms
------------------------------------

quantms workflow uses `Luciphor <https://github.com/dfermin/lucXor>`_ tool for PTM localization analysis. Luciphor [FERMIN2013]_, is a site localization tool for generic post-translational modifications (PTMs). The software provides a site-level localization score for generic PTMs and associated false discovery rate called the false localization rate.

By default, PTM localization is disable which means that the reported sites will be the ones reported by the search engines. If the user wants to enable the PTM localization analysis, the following parameter must be used `--enable_mod_localization true`. If PTM localization is enabled, the algorithm will perform the analysis by default only on Phosphosites (S,Y,T).

.. note:: Additional parameters for the algorithms are: `luciphor_decoy_mass = 79.966330999999997`, `luciphor_neutral_losses = null`, `luciphor_decoy_neutral_losses = null`. The user can chang the default parameters by passing a new value to the pipeline, for example: `--luciphor_decoy_mass  85.34`

Luciphor score is added to each PTM site in the mzTab (:doc:`formats`) for each PSM. It is important to note that quantms workflow do not filter peptides or PSMS based on the PTM localization score, only add the scores to the repoted PSMs and it must be the users the ones taking the decision about the quality of the PTM size.

References
------------------------------------

.. [CHALKLEY2012]
Chalkley RJ; Clauser KR Modification Site Localization Scoring: Strategies and Performance. Mol. Cell Proteomics 2012, 11 (5), 3–14. 10.1074/mcp.R111.015305.

.. [FERMIN2013]
Fermin D; Walmsley SJ; Gingras A-C; Choi H; Nesvizhskii AI LuciPHOr: Algorithm for Phosphorylation Site Localization with False Localization Rate Estimation Using Modified Target-Decoy Approach. Mol. Cell Proteomics 2013, 12 (11), 3409–3419. 10.1074/mcp.M113.028928.

