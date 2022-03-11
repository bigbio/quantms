Label-free quantification with DDA (LFQ)
========================================

LFQ algorithms detect isotopic patterns of eluting peptides and integrate their chromatographic intensities.

.. image:: images/label-free-linking.png
   :width: 600
   :align: center

Quantification across several MS runs is obtained by determining and *linking* of corresponding peptide signals, so-called
*features*, between runs. While label-free quantification scales to a large number of experiments, it heavily relies
on correct linking of corresponding peptides. *Chromatographic retention time alignment* algorithms compensate for differences
in chromatographic elution and reduce mislinked peptides across maps.

ProteomicsLFQ metatool (OpenMS)
-----------------------------------

In quantms, The ProteomicsLFQ tool performs label-free quantification of peptides and proteins. This tool performs
different steps from the feature extraction to the output of the quantified peptides and proteins.

Feature extraction
~~~~~~~~~~~~~~~~~~~~~~~~~~~

ProteomicsLFQ supports **ID-based feature extraction** or a combined **ID-based + untargeted extraction**.

1. **ID-based feature extraction** uses targeted feature detection using RT and m/z information derived from identification data to extract features. Only identifications found in a particular MS run are used to extract features in the same run. No transfer of IDs (match between runs) is performed.
2. **ID-based + untargeted extraction** adds untargeted feature detection to obtain quantities from unidentified features. Transfer of IDs (match between runs) is performed by transfering feature identifications to coeluting, unidentified features with similar mass and RT in other runs.

Requantification:
~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Optionally, a re-quantification step is performed that tries to fill missing values. If a peptide has been quantified in more than half of all maps, the peptide is selected for requantification. In that case, the mean observed RT (and theoretical m/z) of the peptide is used to perform a second round of targeted extraction.

Map alignment
~~~~~~~~~~~~~~~~~~~~~~~~~~

ProteomicsLFQ supports two modes of alignment. **star** alignment and **tree guided** alignment.

1. **star** alignment uses the MapAlignmentAlgorithmIdentification algorithm to align all data to the reference run with the highest number of identifications.
2. **tree guided** alignment uses the MapAlignmentAlgorithmIdentification algorithm to align data. For each pair of maps, the similarity is determined based on the intersection of the contained identifications using Pearson correlation. Using hierarchical clustering together with average linkage a binary tree is produced. Following the tree, the maps are aligned, resulting in a transformed data.

Cubic spline smoothing is used to convert the mapping to a smooth function.

Feature linking
~~~~~~~~~~~~~~~~~~~~~~~

Features are linked using the OpenMS FeatureGroupingAlgorithmQT with a maximum linking tolerance of 10 ppm and RT tolerance estimated from the data.

Output
~~~~~~~~~~~~~~~~~~~~~

1. mzTab file with analysis results
2. Analysis results for statistical downstream analysis in MSstats and Triqler
3. ConsensusXML file for visualization and further processing in OpenMS

.. toctree::
   :maxdepth: 1

   identification
   inference
   msstats
   formats
