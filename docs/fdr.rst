False discovery rate estimation
===============================

quantms offers confidence estimation for your identifications based on the target-decoy approach to control the
*false discovery rate (FDR)* [ELIAS2010]_. Target-decoy FDR estimation is based on simulating false positives
by introducing known absent decoy proteins or peptides into the protein database.

Target/Decoy database generation
----------------------------------------

In quantms, the user can provide the protein FASTA database with the decoys already
attached or generate the database within the pipeline by using the following option: ``add_decoys``.

.. hint:: Additionally, the user can define the prefix for the decoy proteins  (e.g. `DECOY_`) by using the parameter
    ``decoy_string``. We **STRONGLY** recommend to use `DECOY_` prefix for all the decoy proteins for better compatibility
    with downstream QC tools such as :doc:`pmultiqc`

.. warning:: Currently, only appended decoy databases are supported, such that target and decoy sequences compete during
    spectrum matching

Estimation procedures and levels of FDR control
-----------------------------------------------

The exact type of target-decoy FDR estimation used in the workflow, depends on the level at which the FDR is controlled
and which type of PSM re-scoring procedure was used.

PSM or peptide level
********************

The first FDR control happens after PSM re-scoring by either Percolator or a distribution-fitting approach.
Percolator outputs its own PSM- or peptide-level FDR with correction for an estimated rate of incorrect targets,
therefore this usually improved estimate is used when Percolator was chosen.

.. warning:: Choosing peptide-level FDR with Percolator will discard all but the best PSM per peptide. Use with caution
    if you need full traceability.

When using OpenMS' distribution-fitting approach, a standard formula for FDR calculation is used
(TODO add formula) and is currently only available for the PSM level.

The FDR filtering at peptide spectrum match (PSM) level is currently always applied at the single file level.
We argue that experiment-wide FDR control at the end of the workflow on the protein level is sufficient to limit error
rates for the overall analysis. Nonetheless, an option for experiment-wide re-scoring and FDR control on PSM/peptide-level
is under consideration.

.. hint:: The chosen FDR cutoff for PSMs/peptides influences the amount of PSMs available for ID-based feature
    finding, feature linking, as well as protein inference and grouping (see protein :doc:`inference`).

Protein level
*************

FDR control on protein (group) level uses the same formula as above, based on a ranking on the
protein scores/probabilities after inference. On protein level, picked protein FDR can be chosen, which
only counts the highest scoring hit for every target-decoy protein pair [SAV2015]_.

References
----------------------------

.. [ELIAS2010] Elias JE, Gygi SP. Target-decoy search strategy for mass spectrometry-based proteomics. Methods Mol Biol. 2010;604:55-71. doi: 10.1007/978-1-60761-444-9_5. PMID: 20013364; PMCID: PMC2922680.

.. [SAV2015] Savitski MM, Wilhelm M, Hahne H, Kuster B, Bantscheff M. A Scalable Approach for Protein False Discovery Rate Estimation in Large Proteomic Data Sets. Mol Cell Proteomics. 2015 Sep;14(9):2394-404. doi: 10.1074/mcp.M114.046995. Epub 2015 May 17. PMID: 25987413; PMCID: PMC4563723.

