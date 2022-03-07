False discovery rate estimation
===============================

The FDR filtering at peptide spectrum match (PSM) level can be applied for each peptide results. To filter the peptides first the tool compute the peptide error probability (PEP) and then filter using the provided thershold. The PEP score is the probability that a peptide (PSM-peptide spectral match) is incorrect. Basically, the higher the score the more confidence you can have that the given peptide identification is correct.

[1] Elias JE, Gygi SP. Target-decoy search strategy for mass spectrometry-based proteomics. Methods Mol Biol. 2010;604:55-71. doi: 10.1007/978-1-60761-444-9_5. PMID: 20013364; PMCID: PMC2922680.
