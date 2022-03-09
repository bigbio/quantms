Label-free quantification with DDA (LFQ)
========================================

LFQ algorithms detect isotopic patterns of eluting peptides and integrate their
chromatographic intensities. 

.. image:: images/label-free-linking.png
   :width: 600
   :align: center

Quantification across several MS runs is obtained by determining 
and *linking* of corresponding peptide signals, so-called
*features*, between runs. While label-free quantification scales to a large
number of experiments, it heavily relies on correct linking of corresponding peptides.
*Chromatographic retention time alignment* algorithms compensate for differences
in chromatographic elution and reduce mislinked peptides across maps.

