False discovery rate estimation
===============================

The FDR filtering at peptide spectrum match (PSM) level can be applied for each peptide results. To filter the peptides first the tool compute the peptide error probability (PEP) and then filter using the provided thershold. The PEP score is the probability that a peptide (PSM-peptide spectral match) is incorrect. Basically, the higher the score the more confidence you can have that the given peptide identification is correct.

Target/Decoy database generation
----------------------------------------

Target/Decoy is the most common approach to control the number of false positive peptides and proteins identified by the corresponding workflow [ref 3]. The user can provide the protein FSATA database with the decoys already attached or generate the database within the pipeline by using the following option: ``add_decoys``.

.. hint:: Additionally, the user can define the prefix for the decoy proteins  (e.g. DECOY_) by using the parameter ``decoy_string``. We STRONGLY recommend to use DECOY_ prefix for all the decoy proteins for better compatibility with exiting tools such as :doc:`pquant` or :doc:`pmultiqc`


[1] Elias JE, Gygi SP. Target-decoy search strategy for mass spectrometry-based proteomics. Methods Mol Biol. 2010;604:55-71. doi: 10.1007/978-1-60761-444-9_5. PMID: 20013364; PMCID: PMC2922680.
