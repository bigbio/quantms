Protein inference
=================

Assembling peptides identified (:doc:`identification`) from tandem mass spectra into a list of proteins, referred to as protein inference, is a critical step in proteomics research [HUANG2012]_. Due to the existence of shared peptides across multiple proteins, it is very difficult to determine which proteins are present in the sample.

.. image:: images/protein-inference-protein-groups.png
   :width: 300
   :align: center

The peptide-centric approach is by design flawed by the presence of shared peptides also named degenerated peptides whose sequence is shared between different proteins. When such peptides are encountered, it is common practice to group the matching proteins into ambiguity groups [NES2012]_.

Over the years multiple algorithms has been developed to map the identified peptide list into a final protein list. Various tools are available for this task, integrated in a larger environment like the Trans-Proteomic Pipeline (TPP),MaxQuant or PeptideShaker, or standalone like IDPicker.

.. note:: Different software will give you different proteins from the same peptide list. In addition different software's in combination with different peptide identification tools can give completly different results (read our previous benchmark in the topic [AUDA2017]_)

In quantms, different algorithms and configurations are provided to the user to perform the protein inference. Bayesian inference is performed using the Epifany algorithm [PFEU2020]_, while in the aggregation, the algorithm aggregates the scores of peptide sequences that match a protein accession. Only the top PSM for a peptide is used. By default it also annotates the number of peptides used for the calculation and can be used for further filtering.


Protein inference in DDA experiments are provided embedded in the proteomicsLFQ quantification step or independently in the isobaric workflow analysis.

References
------------------------

.. [HUANG2012] Huang T, Wang J, Yu W, He Z. Protein inference: a review. Brief Bioinform. 2012 Sep;13(5):586-614. doi: 10.1093/bib/bbs004. Epub 2012 Feb 28. PMID: 22373723.

.. [NES2012] Nesvizhskii AI, Aebersold R. Interpretation of shotgun proteomic data: the protein inference problem. Mol Cell Proteomics. 2005 Oct;4(10):1419-40. doi: 10.1074/mcp.R500012-MCP200. Epub 2005 Jul 11. PMID: 16009968.

.. [AUDA2017] Audain E, Uszkoreit J, Sachsenberg T, Pfeuffer J, Liang X, Hermjakob H, Sanchez A, Eisenacher M, Reinert K, Tabb DL, Kohlbacher O, Perez-Riverol Y. In-depth analysis of protein inference algorithms using multiple search engines and well-defined metrics. J Proteomics. 2017 Jan 6;150:170-182. doi: 10.1016/j.jprot.2016.08.002. Epub 2016 Aug 4. PMID: 27498275.

.. [PFEU2020] Pfeuffer J, Sachsenberg T, Dijkstra TMH, Serang O, Reinert K, Kohlbacher O. EPIFANY: A Method for Efficient High-Confidence Protein Inference. J Proteome Res. 2020 Mar 6;19(3):1060-1072. doi: 10.1021/acs.jproteome.9b00566. Epub 2020 Feb 13. PMID: 31975601; PMCID: PMC7583457.



