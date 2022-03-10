ProteomicsLFQ metatool (OpenMS)
===============================

The ProteomicsLFQ tool performs label-free quantification of peptides and proteins.

Feature extraction:
ProteomicsLFQ supports **ID-based feature extraction** or a combined **ID-based + untargeted extraction**.

1. **ID-based feature extraction** uses targeted feature dectection using RT and m/z information derived from identification data to extract features. Only identifications found in a particular MS run are used to extract features in the same run. No transfer of IDs (match between runs) is performed.
2. **ID-based + untargeted extraction** adds untargeted feature detection to obtain quantities from unidentified features. Transfer of Ids (match between runs) is performed by transfering feature identifications to coeluting, unidentified features with similar mass and RT in other runs.
         
Requantification:
1. Optionally, a requantification step is performed that tries to fill NA values. If a peptide has been quantified in more than half of all maps, the peptide is selected for requantification. In that case, the mean observed RT (and theoretical m/z) of the peptide is used to perform a second round of targeted extraction.

Output:
- mzTab file with analysis results
- Aalysis results for statistical downstream analysis in MSstats and Triqler
- ConsensusXML file for visualization and further processing in OpenMS
