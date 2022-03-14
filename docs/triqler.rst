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
============  ===============   ===============  ============  ==============  ================  =========

.. note:: The triqler output is stored in the `proteomicslfq` folder and is **only** available for label-free (:doc:`lfq`) experiments. The triqler output generation automatically activates decoy quantification which makes the pipeline a slower.

Some remarks:

- For Triqler to work, it also needs decoy PSMs, preferably resulting from a search engine search with a reversed protein sequence database concatenated to the target database. quantms exports the decoy and target proteins into the triqler output.
- The intensities should not be log transformed, Triqler will do this transformation for you.
- The search engine scores should be such that higher scores indicate a higher confidence in the PSM. quantms uses a transformation of the Posterior error probability (PEP) as `1-PEP` for each PSM.
- Multiple proteins can be specified at the end of the line, separated by tabs. However, it should be noted that Triqler currently discards shared peptides.

Running Triqler
--------------------------

Triqler can be run in the quantms output by using the following command:

.. code-block:: bash

   python -m triqler --fold_change_eval 0.8 out_triqler.tsv

References
---------------------------

.. [THE2018] The M, Käll L. Integrated Identification and Quantification Error Probabilities for Shotgun Proteomics.
    Mol Cell Proteomics. 2019 Mar;18(3):561-570. doi: 10.1074/mcp.RA118.001018. Epub 2018 Nov 27. PMID: 30482846; PMCID: PMC6398204.
