Triqler
=======


`Triqler <https://github.com/statisticalbiotechnology/triqler>`_ is a probabilistic graphical model that propagates error
information through all steps from MS1 feature to protein level, employing distributions in favor of point estimates,
most notably for missing value imputation [THE2018]_. The model outputs posterior probabilities for fold changes between treatment
groups, highlighting uncertainty rather than hiding it.



quantms & triqler
-------------------

quantms exports the triqler input after the quantification steps in the LFQ analysis (:doc:`lfq`).The following table is
an example how the exported file should looks like:

============  ===============   ===============  ============  ==============  ================  =========
run           condition         charge           searchScore   intensity       peptide           proteins
============  ===============   ===============  ============  ==============  ================  =========
6             heart             2                0.9840915     3.275759e07     AAAFEQLQK         O94826
14            heart             2                0.9999985     2.708722e07     AAAGELQEDSGLC(Carbamidomethyl)VLAR   Q96C19
============  ===============   ===============  ============  ==============  ================  =========

.. note:: The triqler output is stored in the `proteomicslfq` folder and is **only** available for label-free experiments.

References
---------------------------

.. [THE2018]] The M, Käll L. Integrated Identification and Quantification Error Probabilities for Shotgun Proteomics.
Mol Cell Proteomics. 2019 Mar;18(3):561-570. doi: 10.1074/mcp.RA118.001018. Epub 2018 Nov 27. PMID: 30482846; PMCID: PMC6398204.
