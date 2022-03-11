Percolator (SVM-based rescoring)
================================

`Percolator <https://github.com/percolator/percolator>`_ rescores search engine results for improved identification rates.
It uses semi-supervised machine learning to discriminate correct from incorrect peptide-spectrum matches.
Different properties from the peptide identifications such as retention time, number of missed-cleavages, peptide identification score, are used to train a SVM model that separates more accurately the true positive identifications from false positives.

quantMS uses Percolator to improve identification results and to obtain error probabilities for peptide spectrum matches.
In order to build a good mode for discriminating correct and incorrect matches, the tool needs sufficient correct peptide spectrum
matches.

**Percolator features used in quantMS:**
- score recalibration
- calculation of (posterior) error probabilities for individual PSMs
- limited batch sizes

**Troubleshooting:**

Score recalibration fails. This might be a result of setting the wrong search parameters resulting in too little identifications.

**Alternatives:**

Mixture modelling using the *IDPosteriorErrorProbability* tool is a fallback for Percolator. It is more robust, works with less data
 but on average yields a lower number of identifications.

For additional details on the main algorithm [KAELL2007]_, [THE2016]_, the q-value calculation method [KAELL2008A]_, and posterior error probability estimation [KAELL2008B]_ please refer to the publications.

References
-----------------------------

    .. [KAELL2007] Lukas Käll, Jesse Canterbury, Jason Weston, William Stafford Noble and Michael J. MacCoss. **Semi-supervised learning for peptide identification from shotgun proteomics datasets.** *Nature Methods 4:923 – 925, November 2007*
    .. [THE2016] Matthew The, William Stafford Noble, Michael J. MacCoss and Lukas Käll. **Fast and Accurate Protein False Discovery Rates on Large-Scale Proteomics Data Sets with Percolator 3.0.** *J. Am. Soc. Mass Spectrom. (2016) 27: 1719, November 2016*
    .. [KAELL2008A] Lukas Käll, John D. Storey, Michael J. MacCoss and William Stafford Noble. **Assigning confidence measures to peptides identified by tandem mass spectrometry.** *Journal of Proteome Research, 7(1):29-34, January 2008*
    .. [KAELL2008B] Lukas Käll, John D. Storey and William Stafford Noble. **Nonparametric estimation of posterior error probabilities associated with peptides identified by tandem mass spectrometry.** *Bioinformatics, 24(16):i42-i48, August 2008*
