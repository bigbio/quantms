DDA Identification workflow
=========================

The peptide/protein identification workflow is the cornerstone of the Data dependant acquisition (DDA) quantification methods such as LFQ or TMT. To identify proteins by mass spectrometry, the proteins of interest in the sample are reduced and then digested into peptides using a proteolytic enzyme (e.g. trypsin). The peptides complex mixture is then separated by liquid chromatography which is coupled to the mass spectrometer.

In DDA mode, the mass spectrometer first records the mass/charge (m/z) of each peptide ion and then selects the peptide ions individually to obtain sequence information via MS/MS (Figure 1). As a result for each sample, millions of MS and corresponding MS/MS are obtained which correspond to all peptides in the mixture.

.. image:: images/msms.png
   :width: 350

In order to identified the MS/MS spectra, several computational algorithms and tools can now be used to identify peptides and proteins. The most popular ones are based on protein sequence databases, where the experimental MS/MS is compared with the theoretical MS/MS of each peptide obtained from the insilico digestion of the protein database [read review ref 1].

.. note:: Several well established software applications like Mascot and MaxQuant can be used for peptide and protein identification.

However, most of the computational proteomics tools are designed as single-tiered/monolithic software application where the analytics tasks cannot be distributed, limiting the scalability and reproducibility of the data analysis [ref 2]. The identification sub-workflow of the `quantms workflow <https://github.com/bigbio/quantms>`_ enables to distribute in cloud/distributed environments all the different steps of a peptide identification workflow including:

- target/decoy database creation
- mass spectra processing
- peptide identification
- false positive control
- creation of reports

.. image:: images/id-dda-pipeline.png
   :width: 350

Mass spectra processing: Raw conversion
---------------------------------------

The RAW data (files from the instrument) can be provided to quantms pipeline in two different formats: (i) RAW files - instrument files; (ii) mzML files (HUPO-PSI standard file format). quantms uses the `thermorawfileparser <https://github.com/compomics/ThermoRawFileParser>`_ to convert the input RAW files to mzML and all the following steps are built in top of the standard mzML.

.. important:: Automatic RAW file conversion is only supported from Thermo Scientific.

Additionally to file conversion, the Raw conversion step allows the users to perform an extra peak-picking step ``openmspeakpicker true`` for those datasets/projects where peaks can be extracted using the Thermo RAW API. Read more about the OpenMS peak picker algorithm `here <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_PeakPickerWavelet.html>`_ .

Target/Decoy database generation
----------------------------------------

Target/Decoy is the most common approach to control the number of false positive peptides and proteins identified by the corresponding workflow [ref 3]. The user can provide the protein FSATA database with the decoys already attached or generate the database within the pipeline by using the following option: ``add_decoys``.

.. hint:: Additionally, the user can define the prefix for the decoy proteins  (e.g. DECOY_) by using the parameter ``decoy_string``. We STRONGLY recommend to use DECOY_ prefix for all the decoy proteins for better compatibility with exiting tools such as :doc:`pquant` or :doc:`pmultiqc`

Peptide Identification
------------------------------------

The peptide identification step in the quantms pipeline can be performed (**independently** or **combined**) with two different open-source tools : `Comet <http://comet-ms.sourceforge.net/>`_ or `MS-GF+ <https://github.com/MSGFPlus/msgfplus>`_. The parameters for the search engine Comet or MS-GF+ are read from the SDRF input parameters including the post-translation modifications (annotated with UNIMOD accessions), precursor and fragment ion mass tolerances, etc. The only parameter that MUST be provided by commandline to the quantms workflow is the psm and peptide FDR threshold ``psm_pep_fdr_cutoff`` (default value ``0.01``).

.. note:: The benefit of using multiple database search engine combined has been proved to be efficient to identified more around **15% peptides** more than using only one search engine. However, you need to be aware that adding another search engine will increase the CPU computing time. :doc:`identification-benchmarks`.

Percolator: Boosting peptide identifications
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

`Percolator <https://github.com/percolator/percolator>`_ uses a semi-supervised machine learning to discriminate correct from incorrect peptide-spectrum matches. Percolator uses different properties from the peptide identifications such as retention time, number of missed-cleavages, peptide identification score, to train a SVM model that separates more accurately the true positive identifications from false positives.

FDR filtering and ConsensusID
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The FDR filtering at peptide spectrum match (PSM) level can be applied for each peptide results. To filter the peptides first the tool compute the peptide error probability (PEP) and then filter using the provided thershold. The PEP score is the probability that a peptide (PSM-peptide spectral match) is incorrect. Basically, the higher the score the more confidence you can have that the given peptide identification is correct.

When multiple search engines are used ```search_engines msgf,comet``` the results for each RAW file is combined into one single identification file including the combination of both search engines. The `ConsensusID tool <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_ConsensusID.html>`_ is used to combined the results from different search engines.

References
---------------------

[1] Perez-Riverol Y, Wang R, Hermjakob H, Müller M, Vesada V, Vizcaíno JA. Open source libraries and frameworks for mass spectrometry based proteomics: a developer's perspective. Biochim Biophys Acta. 2014 Jan;1844(1 Pt A):63-76. doi: 10.1016/j.bbapap.2013.02.032. Epub 2013 Mar 1. PMID: 23467006; PMCID: PMC3898926.

[2] Perez-Riverol Y, Moreno P. Scalable Data Analysis in Proteomics and Metabolomics Using BioContainers and Workflows Engines. Proteomics. 2020 May;20(9):e1900147. doi: 10.1002/pmic.201900147. Epub 2019 Dec 18. PMID: 31657527.

[3] Elias JE, Gygi SP. Target-decoy search strategy for mass spectrometry-based proteomics. Methods Mol Biol. 2010;604:55-71. doi: 10.1007/978-1-60761-444-9_5. PMID: 20013364; PMCID: PMC2922680.

