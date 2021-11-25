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

quantms identification workflow
---------------------

.. image:: images/id-dda-pipeline.png
   :width: 350

Mass spectra processing: Raw conversion
~~~~~~~~~~~~~~~~~~~~~~

The RAW data (files from the instrument) can be provided to quantms pipeline in two different formats: (i) RAW files - instrument files; (ii) mzML files (HUPO-PSI standard file format). quantms uses the `thermorawfileparser <https://github.com/compomics/ThermoRawFileParser>`_ to convert the input RAW files to mzML and all the following steps are built in top of the standard mzML.

.. important:: Automatic RAW file conversion is only supported from Thermo Scientific.

Additionally to file conversion, the Raw conversion step allows the users to perform an extra peak-picking step ```openmspeakpicker true``` for those datasets/projects where peaks can be extracted using the Thermo RAW API. Read more about the OpenMS peak picker algorithm `here <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_PeakPickerWavelet.html>`_ .


References
---------------------

[1] Perez-Riverol Y, Wang R, Hermjakob H, Müller M, Vesada V, Vizcaíno JA. Open source libraries and frameworks for mass spectrometry based proteomics: a developer's perspective. Biochim Biophys Acta. 2014 Jan;1844(1 Pt A):63-76. doi: 10.1016/j.bbapap.2013.02.032. Epub 2013 Mar 1. PMID: 23467006; PMCID: PMC3898926.
[2] Perez-Riverol Y, Moreno P. Scalable Data Analysis in Proteomics and Metabolomics Using BioContainers and Workflows Engines. Proteomics. 2020 May;20(9):e1900147. doi: 10.1002/pmic.201900147. Epub 2019 Dec 18. PMID: 31657527.
