Percolator (SVM-based rescoring)
================================

`Percolator <https://github.com/percolator/percolator>`_ rescores search engine results for improved identification rates.
It uses semi-supervised machine learning to discriminate correct from incorrect peptide-spectrum matches.
Different properties from the peptide identifications such as retention time, number of missed-cleavages, peptide identification score, are used to train a SVM model that separates more accurately the true positive identifications from false positives.

**Main publications:**
Lukas Käll, Jesse Canterbury, Jason Weston, William Stafford Noble and Michael J. MacCoss.
Semi-supervised learning for peptide identification from shotgun proteomics datasets
Nature Methods 4:923 – 925, November 2007

Matthew The, William Stafford Noble, Michael J. MacCoss and Lukas Käll
Fast and Accurate Protein False Discovery Rates on Large-Scale Proteomics Data Sets with Percolator 3.0
J. Am. Soc. Mass Spectrom. (2016) 27: 1719, November 2016

**Details on Percolator’s q-value calculation method can be found in:**
Lukas Käll, John D. Storey, Michael J. MacCoss and William Stafford Noble
Assigning confidence measures to peptides identified by tandem mass spectrometry
Journal of Proteome Research, 7(1):29-34, January 2008

**Details on Percolator’s posterior error probability calculation method can be found in:**
Lukas Käll, John D. Storey and William Stafford Noble
Nonparametric estimation of posterior error probabilities associated with peptides identified by tandem mass spectrometry
Bioinformatics, 24(16):i42-i48, August 2008
