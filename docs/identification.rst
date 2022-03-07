Peptide identification from fragment spectra
=========================

.. toctree::
   :maxdepth: 1

   searchengines
   consensusid
   rescoring
   fdr
   modlocal

The peptide identification workflow is the cornerstone of data-dependent acquisition (DDA)
quantification methods such as LFQ or TMT and can also be used to create transition libraries for DIA.
To identify proteins by mass spectrometry, the proteins of interest in the sample are
digested into peptides using a proteolytic enzyme (e.g., trypsin).
The complex peptide mixture is then separated by liquid chromatography which is coupled to the mass spectrometer.

In DDA mode, the mass spectrometer first records the mass/charge (m/z) of each peptide ion and then selects
the peptide ions individually for fragmentation to obtain sequence information via MS/MS spectra (Figure 1).
As a result for each sample, millions of MS and corresponding MS/MS are obtained
which correspond to all peptides in the mixture.

.. image:: images/msms.png
   :width: 600
   :align: center

In order to identify the MS/MS spectra, several computational algorithms and tools
can now be used to identify peptides and proteins. The most popular ones are based on protein sequence databases,
where the experimental MS/MS is compared with the theoretical MS/MS of each peptide obtained from the *in silico*
digestion of the protein database [read review ref 1].

.. image:: images/id-dda-pipeline.png
   :width: 400
   :align: center


Peptide Identification
------------------------------------

The peptide identification step in the quantms pipeline can be performed (**independently** or **combined**) with two different open-source tools : `Comet <https://github.com/UWPR/Comet>`_ or `MS-GF+ <https://github.com/MSGFPlus/msgfplus>`_. The parameters for the search engine Comet or MS-GF+ are read from the SDRF input parameters including the post-translation modifications (annotated with UNIMOD accessions), precursor and fragment ion mass tolerances, etc. The only parameter that MUST be provided by commandline to the quantms workflow is the psm and peptide FDR threshold ``psm_pep_fdr_cutoff`` (default value ``0.01``).

.. note:: Using multiple database search engine combined can yield up to **15% more peptides**
    compared to using only one search engine. However, you need to be aware that adding another
    search engine will increase the CPU computing time. :doc:`identification-benchmarks`.


References
---------------------

[1] Perez-Riverol Y, Wang R, Hermjakob H, Müller M, Vesada V, Vizcaíno JA. Open source libraries and frameworks for mass spectrometry based proteomics: a developer's perspective. Biochim Biophys Acta. 2014 Jan;1844(1 Pt A):63-76. doi: 10.1016/j.bbapap.2013.02.032. Epub 2013 Mar 1. PMID: 23467006; PMCID: PMC3898926.

[2] Perez-Riverol Y, Moreno P. Scalable Data Analysis in Proteomics and Metabolomics Using BioContainers and Workflows Engines. Proteomics. 2020 May;20(9):e1900147. doi: 10.1002/pmic.201900147. Epub 2019 Dec 18. PMID: 31657527.


