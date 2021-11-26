Formats in quantms
===============================

The quantms is natively based on HUPO-PSI standard file formats:

- `mzML <https://www.psidev.info/mzML>`_: The mzML format is an open, XML-based format for mass spectrometer output files, developed with the full participation of vendors and researchers in order to create a single open format that would be supported by all software.

- `mzTab <https://www.psidev.info/mztab>`_: mzTab is intended as a lightweight supplement to the existing standard mzML to store and represent peptide and protein and identifications together with experimental metadata and basic quantitative information.

- `sdrf <https://github.com/bigbio/proteomics-metadata-standard>`_: The SDRF-Proteomics format describes the sample characteristics and the relationships between samples and data files included in a dataset. The information in SDRF files is organised so that it follows the natural flow of a proteomics experiment.

Apart of this three main file formats, additionally, multiple file formats are used within the workflow between steps and as a final output for downstream analysis including: idXML, consensusXML, MSstats output, etc.

Input formats
---------------------------

The quantms should receive three main inputs: Experimental design (SDRF); Spectra data files (RAW or mzML); Protein database (Fasta).

SDRF: experimental design
~~~~~~~~~~~~~~~~~~~~~~~~~~

The HUPO-PSI and ProteomeXchange recently developed the MAGE-TAB an standard file format for experimental design representation. Within the MAGE-TAB, the Sample and Data Relationship Format (SDRF) is a lightweight tab delimited format to represent the sample metadata and its relation with the data files (RAW or mzML files).

.. image:: https://raw.githubusercontent.com/bigbio/proteomics-metadata-standard/master/sdrf-proteomics/images/sdrf-nutshell.png
   :width: 900
   :align: center

|
Multiple concepts from SDRF and **relevant and important** for the quantms pipeline:

**Peptide Search Parameters**:

- comment[cleavage agent details]: enzyme used in the experiment, including sites and positions.
- comment[modification parameters]: post-translation modifications that will be consider within the peptide/protein search
- comment[precursor mass tolerance], comment[fragment mass tolerance]: Precursor mass tolerance use for the peptide search. Both each engines Comet and MSGF+ use this parameter.

**Experimental Design**:

- factor value[disease]: The factor value is the variable under study. In a proteomics study it can be the disease, organism part, tumor location, etc. The study variable will have multiple values depending of the samples and conditions. For example, in the SDRF above, the variable under study **factor value[phenotype]** has to values (one for each sample), control (sample 1) and primary tumor (sample 2).

.. important:: When multiple conditions are under study, the user can create multiple SDRFs (one for each variable under study). This is needed because in the LFQ data analysis when match between runs is enable (MBR), the proteomicsLFQ quantification step needs to match samples that belongs to the same condition value.

- characteristics[biological replicate]: Biological replicates are samples that belongs to the same condition value and material source.
- comment[technical replicate]: Technical replicates are repetitions of measures of the same sample.
- comment[fraction identifier]: Fraction identifiers are use to numbered and identified each fraction (for any fractionation method).
- comment[label]: Label is used by quantms to associate samples to labels/channels in the experiment (e.g. TMT127).

Spectra Data
~~~~~~~~~~~~~~~~~~~~~~~~~~

The spectra data can be provided in RAW files (Thermo instruments) or preferably in mzML. If RAW files are provided, the first step of the identification pipeline `convert them into mzML <https://quantms.readthedocs.io/en/latest/identification.html#mass-spectra-processing-raw-conversion>`_.


Protein databases
~~~~~~~~~~~~~~~~~~

Protein databases can be download from multiple sources; the most common ones are `UNIPROT <https://www.uniprot.org/>`_ and `ENSEMBL <https://www.ensembl.org/info/data/ftp/index.html>`_.

.. hint:: Contaminants should be appended to the database. For each contaminant protein the prefix ``CONTAMINANT_`` should be added as prefix of the protein.


Output formats
---------------------------

