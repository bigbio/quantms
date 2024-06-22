MS2Rescore (AI-assisted rescoring of peptide identifications)
================================

`MS2Rescore <https://github.com/compomics/ms2rescore>`_ rescores search engine results for improved identification rates.
It uses semi-supervised machine learning to discriminate correct from incorrect peptide-spectrum matches.

Different properties from the peptide identifications such as: retention time, peptide fragmention spectrum intensity, peptide
identification score, are used to train a model that separates more accurately the true positive identifications
from false positives.

quantms uses MS2Rescore [BUUR2024]_ to generate extra PSM features including retention time and fragmention ions intensity,
which proved to be increase peptide identifications and sensitivity, especially for immunopeptide datasets. The MS2Rescore uses MS2PIP [DEG2016]_ and DeepLC [BOUW2021]_ separately to predict PSM features.

MS2Rescore features generator used in quantms
---------------------------------------

- MS2PIP
- DeepLC

Troubleshooting
---------------------------

Features generators fails. This might be a result of setting the wrong model parameters or unsupported experimental type resulting in bad
model prediction. In those cases, MS2Rescore can be disable (default `--ms2recore false`).

For additional details on the main algorithm [DEG2016]_, [BOUW2021]_, please refer to the publications.

References
-----------------------------

.. [BUUR2024] Louise M. Buur, Arthur Declercq, Marina Strobl, Robbin Bouwmeester, Sven Degroeve, Lennart Martens, Viktoria Dorfer, and Ralf Gabriels.
   MS2Rescore 3.0 Is a Modular, Flexible, and User-Friendly Platform to Boost Peptide Identifications, as Showcased with MS Amanda 3.0. Journal of Proteome Research,
   March 2024

.. [DEG2016] Sven Degroeve, Lennart Martens. MS2PIP: a tool for MS/MS peak intensity prediction. Bioinformatics, 3199–3203,
   September 2013

.. [BOUW2021] Robbin Bouwmeester, Ralf Gabriels, Niels Hulstaert, Lennart Martens, Sven Degroeve. DeepLC can predict retention times for peptides that carry as-yet unseen modifications. Nature Methods, 1363–1369, October 2021