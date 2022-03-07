Percolator (SVM-based rescoring)
================================

`Percolator <https://github.com/percolator/percolator>`_ uses a semi-supervised machine learning to discriminate correct from incorrect peptide-spectrum matches. Percolator uses different properties from the peptide identifications such as retention time, number of missed-cleavages, peptide identification score, to train a SVM model that separates more accurately the true positive identifications from false positives.
