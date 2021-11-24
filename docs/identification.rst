DDA Identification workflow
=========================

The peptide/protein identification workflow is the cornerstone of the Data dependant acquisition (DDA) quantification methods such as LFQ or TMT. To identify proteins by mass spectrometry, the proteins of interest in the sample are reduced and then digested into peptides using a proteolytic enzyme (e.g. trypsin). The peptides complex mixture is then separated by liquid chromatography which is coupled to the mass spectrometer.

In DDA mode, the mass spectrometer first records the mass/charge (m/z) of each peptide ion and then selects the peptide ions individually to obtain sequence information via MS/MS (Figure 1). As a result for each sample, millions of MS and corresponding MS/MS are obtained which correspond to all peptides in the mixture.

In order to identified the MS/MS spectra, Several computational methods can now be used to identify peptides and proteins. The most popular ones are based on protein sequence databases, where the experimental MS/MS is compared with the theoretical MS/MS of each peptide obtained from the in-silico digestion of the protein database [read review 1].

.. note:: As a result, there are several well established software applications like Mascot [12], X!Tandem [13], Sequest [14], MyriMatch [15], SpectraST [11], OMSSA [16], and Andromeda [17], among others.



.. image:: images/id-dda-pipeline.png
   :width: 350

References

[1] Perez-Riverol Y, Wang R, Hermjakob H, Müller M, Vesada V, Vizcaíno JA. Open source libraries and frameworks for mass spectrometry based proteomics: a developer's perspective. Biochim Biophys Acta. 2014 Jan;1844(1 Pt A):63-76. doi: 10.1016/j.bbapap.2013.02.032. Epub 2013 Mar 1. PMID: 23467006; PMCID: PMC3898926.
