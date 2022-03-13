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
The columns specified in the SDRF that are **relevant and important** for the quantms pipeline can be
divided into two categories:

**Peptide Search Parameters**:

- ``comment[cleavage agent details]``:
    Enzyme used in the experiment, including sites and positions.
- ``comment[modification parameters]``:
    Post-translation modifications that will be consider within the peptide/protein search
- ``comment[precursor mass tolerance], comment[fragment mass tolerance]``:
    Precursor mass tolerance use for the peptide search. All parameters will be translated to search engine
    specific parameters as closely as possible.

**Experimental Design**:

- ``factor value[disease]``:
    The factor value is the variable under study.
    In a proteomics study it can be the disease, organism part, tumor location, etc.
    The study variable will have multiple values depending of the samples and conditions.
    For example, in the SDRF above, the variable under study ``factor value[phenotype]``
    has two values (one for each sample), ``control`` (sample 1) and ``primary tumor`` (sample 2).

.. hint:: To simplify handling of conditions in downstream statistical software (e.g., MSstats), all factor value
    columns will be appended for each row with the ``|`` separator. Consider this when building contrasts for
    the MSstats parameters (see the parameter documentation (TODO link) and the chapter on :doc:`MSstats <msstats>` for further
    details).

.. important:: Unequal fractionations are not supported yet, please remove superfluous fractions in all samples
    if a run failed or was discarded.

.. important:: When multiple conditions are under study which cannot be reliably aligned or compared (e.g., due to
    different instruments, chromatographies, fractionations, and/or quantification strategies), the user should create
    multiple SDRFs (one for each experiment).

- ``characteristics[biological replicate]``:
    Biological replicates are samples that belongs to the same condition value and material source.
- ``comment[technical replicate]``:
    Technical replicates are repetitions of measures of the same sample.
- ``comment[fraction identifier]``:
    Fraction identifiers are use to numbered and identified each fraction (for any fractionation method).
- ``comment[label]``:
    Label is used by quantms to associate samples to labels/channels in the experiment (e.g. TMT127).
    Use ``label free`` for all rows to indicate a label free experiment.

Spectra Data
~~~~~~~~~~~~~~~~~~~~~~~~~~

The spectra data can be provided in RAW files (for Thermo-Fisher instruments only) or preferably in mzML.
If RAW files are provided, the first step of the identification pipeline
`converts them into mzML <https://quantms.readthedocs.io/en/latest/identification.html#mass-spectra-processing-raw-conversion>`_.


Protein databases
~~~~~~~~~~~~~~~~~~

Protein databases in **fasta** format can be download from multiple sources; the most common ones
are `UNIPROT <https://www.uniprot.org/>`_ and `ENSEMBL <https://www.ensembl.org/info/data/ftp/index.html>`_.
They can also be created by translating transcripts.

.. important:: Please be careful with the usage of stop codons (``*`` character) in your database. Their handling
    changes from search engine to search engine. Remove them and duplicate/split your protein entries manually to avoid
    misinterpretation.

.. hint:: Contaminants should be appended to the database. For each contaminant protein the prefix ``CONTAMINANT_`` should be added as prefix of the protein.

Output formats
---------------------------

The main output of the quantms is the standard HUPO-PSI format `mztab <https://www.psidev.info/mztab>`_. The mzTab allows quantms to store quantification/identification information from proteomics experiments in a single file.
If MSstats was activated, the workflow outputs two mzTab:
 - one in the proteomicslfq or proteininferencer folder, containing raw intensities from OpenMS for each feature/channel
 - one in the msstats folder, with intensities replaced by the output from MSstats(TMT). This contains normalized and
    potentially imputed quantities.

Additionally, :doc:`msstats` and :doc:`triqler`  output for downstream analysis are exported. If you would like to have another output included in the pipeline please contact the developers over the discussion forum, slack or open an issue.


Intermediate formats
------------------------

`OpenMS <https://www.openms.de/>`_ adapters are a cornerstone of quantms, they allow to convert between file formats,
handle proteomics data such as enzymes definitions, PTMs, etc.
OpenMS offers an open-source software C++ library (+ python bindings) for LC/MS data management and analyses.
Multiple files from OpenMS ecosystem are use within quantms to store intermediate steps. Among these files are:

- OpenMS' experimental design:
    OpenMS has its own simplified, TSV-based `experimental design format <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/release/latest/html/classOpenMS_1_1ExperimentalDesign.html#details>`_.
    It currently can be used as a replacement to SDRF, if all missing search engine parameters are given
    on the command line. This type of input might be deprecated in the future. Since SDRF will be converted to the
    this format plus a configuration table internally, it might be worthwhile to know the format for debugging purposes.
    The converted design can be found in the ``SDRFPARSING`` output folder.

- idXML:
    An xml-based file format to store PSMs, peptide, and protein evidences. More information about the idXML can be `found here <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/classOpenMS_1_1IdXMLFile.html>`_.

- consensusXML:
    An xml-based file format that extends idXML to include quantification data across multiple runs. More information about the consensusXML can be `found here <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/classOpenMS_1_1ConsensusXMLFile.html>`_.

The easiest way to parse these files is to use `pyopenms <https://pyopenms.readthedocs.io/en/latest/>`_
with its `pandas dataframe conversion capabilities <https://pyopenms.readthedocs.io/en/latest/pandas_df_conversion.html>`_.

|Get help on Slack|   |Report Issue| |Get help on GitHub Forum|

.. |Get help on Slack| image:: http://img.shields.io/badge/slack-nf--core%20%23quantms-4A154B?labelColor=000000&logo=slack
                   :target: https://nfcore.slack.com/channels/quantms

.. |Report Issue| image:: https://img.shields.io/github/issues/bigbio/quantms
                   :target: https://github.com/bigbio/quantms/issues

.. |Get help on GitHub Forum| image:: https://img.shields.io/badge/Github-Discussions-green
                   :target: https://github.com/bigbio/quantms/discussions
