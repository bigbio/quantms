Data-independent acquisition (DIA) quantification
==================================================

In mass spectrometry, data-independent acquisition (DIA) is a method of molecular structure determination in which all ions within a selected m/z range are fragmented and analyzed in a second stage of tandem mass spectrometry [DOR2014]_.

.. image:: images/dia.png
   :width: 300
   :align: center

The major difference between DDA and DIA analytical methods is the way the spectra is acquired. Tandem mass spectra are acquired either by fragmenting all ions that enter the mass spectrometer at a given time (called broadband DIA) or by sequentially isolating and fragmenting ranges of m/z. DIA is an alternative to data-dependent acquisition (:doc:`dda`) where a fixed number of precursor ions are selected and analyzed by tandem mass spectrometry. This is the main reason why the peptide identification protocol is different between (:doc:`identification`) and major search engines like :doc:`msgf` and :doc:`comet` do not work with DIA data.

Data analysis of DIA data is based in two major strategies library-based and library-free peptide identification. The classical approach to DIA data analysis uses a spectral library of peptides, which are queried in the DIA samples and quantified in case of their presence. However, this method has been has multiple drawbacks that make difficult automatic reanalysis of public proteomics data:

- In addition to the DIA data, the corresponding DDA needs to be deposited in public databases and properly annotated.
- The need for spectral libraries previously created from DDA data. Previously to the DIA analysis, the user MUST analyze the DDA data and create the spectral libraries which involves multiple steps including peptide identification, RT transitions alignments, etc.

Some of these challenges has been highlighted in multiple publications [MAXDIA2022]_ [MATHIAS2021]_. quantms aims to make reanalysis of public proteomics data easy, fast, scalable and as reproducible as possible. For that reason library-free data analysis is not the best option.

.. tip:: For library-based data analysis we recommend the nf-core pipeline `diaproteomics <https://nf-co.re/diaproteomics>`_ [LEON2021]_

Additionally to library-based algorithms, several library-free approaches exist, and spectral predictions have been successfully used for DIA data analysis. Library-free approaches has two main ways to perform the analysis, by un-multiplex the MSn spectra and perform the analysis as a common DDA or by using predicted in-silico libraries from protein databases. The predicted algorithm uses the protein database to generate the spectra library. In case reliability of library-free identifications is achieved, DIA can additionally be employed in a discovery mode, without biases imposed by a library and, at the same time, with certainty that the identified set of proteins contains, at most, a predefined percentage of false positives—for example, 1%, as is standardly applied in DDA-based proteomics.

.. note:: By 2022, DIA data analysis is an evolving field in proteomics, new algorithm for prediction of libraries from databases are still emerging and new tools are created for pseudo spectra identification. By 2022, we use `diann <https://github.com/vdemichev/DiaNN>`_ as the main tool to perform library-free data analysis. We will continue evolving this pipeline and performing benchmarks and comparisons with other existing tools.

DIANN data analysis
--------------------



References
------------

.. [DOR2014] Doerr, A. DIA mass spectrometry. Nat Methods 12, 35 (2015). https://doi.org/10.1038/nmeth.3234

.. [MAXDIA2022] Sinitcyn P, Hamzeiy H, Salinas Soto F, Itzhak D, McCarthy F, Wichmann C, Steger M, Ohmayer U, Distler U, Kaspar-Schoenefeld S, Prianichnikov N, Yılmaz Ş, Rudolph JD, Tenzer S, Perez-Riverol Y, Nagaraj N, Humphrey SJ, Cox J. MaxDIA enables library-based and library-free data-independent acquisition proteomics. Nat Biotechnol. 2021 Dec;39(12):1563-1573. doi: 10.1038/s41587-021-00968-7. Epub 2021 Jul 8. PMID: 34239088; PMCID: PMC8668435.

.. [MATHIAS2021] Mathias Walzer, David García-Seisdedos, Ananth Prakash, Paul Brack, Peter Crowther, Robert L. Graham, Nancy George, Suhaib Mohammed, Pablo Moreno, Irene Papathedourou, Simon J. Hubbard, Juan Antonio Vizcaíno. Implementing the reuse of public DIA proteomics datasets: from the PRIDE database to Expression Atlas. bioRxiv 2021.06.08.447493; doi: https://doi.org/10.1101/2021.06.08.447493

.. [LEON2021] Bichmann L, Gupta S, Rosenberger G, Kuchenbecker L, Sachsenberg T, Ewels P, Alka O, Pfeuffer J, Kohlbacher O, Röst H. DIAproteomics: A Multifunctional Data Analysis Pipeline for Data-Independent Acquisition Proteomics and Peptidomics. J Proteome Res. 2021 Jul 2;20(7):3758-3766. doi: 10.1021/acs.jproteome.1c00123. Epub 2021 Jun 21. PMID: 34153189.


