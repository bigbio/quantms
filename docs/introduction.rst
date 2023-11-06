Quantitative mass spectrometry data analysis
==============================================

Bottom-up proteomics is a common method to identify proteins
and characterize their amino acid sequences and post-translational
modifications by proteolytic digestion of proteins prior to analysis
by mass spectrometry. In bottom-up or shotgun proteomics [AEBERSOLD2003]_, the protein extract
is enzymatically digested, followed by one or more dimensions of
separation of the peptides by liquid chromatography coupled to
mass spectrometry.
By comparing the masses of the proteolytic peptides or their
tandem mass spectra with those predicted from a sequence database,
peptides can be identified and multiple peptide identifications
assembled into a protein identification.


.. image:: images/ms-proteomics.png
   :width: 400
   :align: center


Different quantification strategies
------------------------------------------

Quantification strategies in proteomics depend on the acquisition strategy
used on the mass spectrometer and how/if the peptides were labelled with
special reagents or isotopes.
Acquisition strategies can be divided into the highly reproducible
:doc:`data-independent acquisition (DIA) strategies <dia>`
(e.g., SWATH) and the well-proven, sensitive
:doc:`data-dependent acquisition (DDA) <dda>`.
With respect to usually more expensive labelling strategies, the most commonly
employed ones are the isobaric chemical labels :doc:`iTraq and TMT <iso>` and the metabolic
labelling strategies (usually based on isotopically labelled amino acids) like SILAC (TODO link)
(SILAC is not yet supported by this pipeline).
The advantage of labels is that they allow multiplexing of samples and
avoiding retention alignment and the implied requirement of having a
very reproducible chromatography.


Workflow-based analysis
-----------------------

While there exist tools for the analysis of shotgun proteomics data like MaxQuant [Cox2008]_, most of these
tools are designed as single-tiered/monolithic software application where tasks cannot be distributed or evaluated
separately, therefore limiting the scalability and reproducibility of the data analysis [RIVEROL2020]_.
The different sub-workflows of the `quantms workflow <https://github.com/bigbio/quantms>`_ on the other hand
enable the distribution of all the different steps of a peptide identification and quantification workflow in
cloud or HPC environments through the usage of nextflow [DI2017]_. It also features rich quality control
reports and different methods for automated downstream statistical post-processing including reports on
significance analysis for differential expression which all can be emailed to you after successful completion of
the pipeline.
The workflow can be configured solely by an SDRF input file for easy one-command-reanalyses of PRIDE datasets
but also offers extensive configurability on either a web-based or a guided command-line interface provided
through its integration into nf-core [EWELS2020]_. The membership in nf-core additionally secures best practices
of open and collaborative development of the pipeline including continuous testing after every contribution.
The used software is strictly versioned through the exclusive usage of (bio-)conda packages whose
association with the biocontainer ecosystem [DA2017]_ also
allows us to provide a workflow profile for several containerization software's (like docker, singularity, podman, etc.).
Containerization ensures an even more reproducible environment for your analyses.
The pipeline can easily be supervised on-the-fly `via nf-tower <https://cloud.tower.nf/>`_. Failed runs can be debugged by investigating
the rich pipeline execution reports.

|

..
    Commented out. The sidebar is too big and we have everything necessary in the global TOC
    sidebar:: Subworkflows and tools
    :subtitle: Here you can find information about individual subworkflows and tools:

        - :doc:`Preprocessing and conversion <preprocessing>`
        - :doc:`Peptide identification <identification>`
            - :doc:`Comet <comet>`
            - :doc:`MSGF+ <msgf>`
            - :doc:`Sage` <sage>`
            - PSM re-scoring
                - :doc:`Distribution-based <idpep>`
                - :doc:`Percolator <percolator>`
            - :doc:`False discovery rates <fdr>`
            - :doc:`Modification localization <modlocal>`
        - :doc:`Label-free quantification <lfq>`
        - :doc:`Isobaric labelled quantification <iso>`
        - :doc:`Data-independent acquistion <dia>`
        - :doc:`Statistical postprocessing <statistics>`
            - :doc:`MSstats <msstats>`
            - :doc:`Triqler <triqler>`
        - :doc:`Quality control <pmultiqc>`


quantms workflow in a nutshell
--------------------------------

Mass spectrometry quantitative data analysis can be divided in the following main steps.
Make sure to follow the links to get to know more about the implementation
details of specific steps in the pipeline.

- Peptide identification

    - Through matching of peptide fragment spectra (:doc:`identification`)

        - with protein database and known modifications |Implemented|
        - with protein database and unknown modifications |In development|
        - with spectrum database |Unsupported|
        - without database (de novo) |Unsupported|

- Peptide quantification

    - DDA

        - label-free |Implemented|
            Through finding interesting features (or 3D peaks) on MS1 level, consisting
            of isotopic traces with the same elution profile (either targeted
            at locations with identifications or untargeted), aligning and
            matching them between runs, potentially re-quantifiying missing features
            and lastly integrating the intensity of the raw peaks in those features (:doc:`lfq`).

        - isobaric labels |Implemented|
            Through comparing the intensity of reporter ions arising from the
            fragmentation of the isobaric label in the fragment spectra either
            in the MS2 spectrum used for identification or in separate MS3 spectra (:doc:`iso`).

        - metabolic labels |Unsupported|
            Through feature finding (as in label-free) and linking features with a mass shift depending
            on the isotopes in the label. Matching modifications in the fragment spectra
            if available can be used to confirm links.

    - DIA

        - (transition) library-free

            - Through creating a library of transitions to extract and compare
              based on the results from peptide search engines, aligning the extracted
              peak groups, and performing rigorous statistical
              testing of those peak group to classify them correctly |In development|
            - With diaNN (:doc:`dia`) |Implemented|

        - (transition) library-based
            - with predefined transition libraries |Implemented|

- Protein inference and quantification
    This is done to map ambiguous peptides to the mostly likely proteins of origin
    and to create protein groups based on the ambiguity level between them.
    Heuristics based on inference scores and groupings can then help in deciding which peptides
    to use for quantification of which protein. Aggregation of quantities
    to the protein level can be performed by several different rules (e.g., top-3)
    or left to the downstream statistical tools (:doc:`inference`).

- Downstream (statistical) data analysis
    Downstream data analysis tools like MSstats and Triqler can
    perform more elaborate normalization, imputation, aggregation
    and statistical significance testing based on the raw intensities,
    protein associations and scores from the upstream pipeline (:doc:`statistics`).

- Quality control
    Our chosen and developed quality control tools gather required
    information from the resulting mzTab file and optionally
    intermediate results to provide statistics and summary plots of
    important quality control metrics like (:doc:`pmultiqc`).


.. image:: images/quantms.png
   :width: 450
   :align: center

References
--------------------------------

.. [AEBERSOLD2003]
    Aebersold, R., Mann, M. Mass spectrometry-based proteomics. Nature 422, 198–207 (2003). https://doi.org/10.1038/nature01511.

.. [Cox2008]
    Cox J, Mann M. MaxQuant enables high peptide identification rates, individualized p.p.b.-range mass accuracies and proteome-wide protein quantification. Nat Biotechnol. 2008;26(12):1367-1372. doi:10.1038/nbt.1511.

.. [RIVEROL2020]
    Perez-Riverol Y, Moreno P. Scalable Data Analysis in Proteomics and Metabolomics Using BioContainers and Workflows Engines. Proteomics. 2020 May;20(9):e1900147. doi: 10.1002/pmic.201900147. Epub 2019 Dec 18. PMID: 31657527.

.. [DI2017]
    Di Tommaso, Paolo et al. Nextflow enables reproducible computational workflows. Nature biotechnology vol. 35,4 (2017): 316-319. doi:10.1038/nbt.3820.

.. [EWELS2020]
    Ewels, Philip A et al. The nf-core framework for community-curated bioinformatics pipelines. Nature biotechnology vol. 38,3 (2020): 276-278. doi:10.1038/s41587-020-0439-x.

.. [DA2017]
    da Veiga Leprevost, Felipe et al. BioContainers: an open-source and community-driven framework for software standardization. Bioinformatics (Oxford, England) vol. 33,16 (2017): 2580-2582. doi:10.1093/bioinformatics/btx192.

.. |Unsupported| image:: https://img.shields.io/badge/feature-unsupported-red?logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiA/PjxzdmcgaWQ9IlNpcmVuIiBzdHlsZT0iZW5hYmxlLWJhY2tncm91bmQ6bmV3IDAgMCAzMiAzMjsiIHZlcnNpb249IjEuMSIgdmlld0JveD0iMCAwIDMyIDMyIiB4bWw6c3BhY2U9InByZXNlcnZlIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj48c3R5bGUgdHlwZT0idGV4dC9jc3MiPgoJLnN0MHtmaWxsOiNGMjU5NDk7fQoJLnN0MXtmaWxsOiNGRkZGRkY7fQoJLnN0MntmaWxsOiM4QjlDQTU7fQoJLnN0M3tmaWxsOiNGQkMzNEU7fQo8L3N0eWxlPjxnPjxwYXRoIGNsYXNzPSJzdDAiIGQ9Ik0yMy41NzgsMjZ2LTkuMDAxYzAtNC4xNzktMy4zOTktNy41NzgtNy41NzgtNy41NzhzLTcuNTc4LDMuMzk5LTcuNTc4LDcuNTc4VjI2SDIzLjU3OHogTTE2LDE0LjkyICAgYy0xLjE0NiwwLTIuMDc4LDAuOTMyLTIuMDc4LDIuMDc4YzAsMC41NTItMC40NDgsMS0xLDFzLTEtMC40NDctMS0xYzAtMi4yNDksMS44My00LjA3OCw0LjA3OC00LjA3OGMwLjU1MiwwLDEsMC40NDgsMSwxICAgUzE2LjU1MiwxNC45MiwxNiwxNC45MnoiLz48cGF0aCBjbGFzcz0ic3QxIiBkPSJNMTYsMTIuOTJjLTIuMjQ5LDAtNC4wNzgsMS44My00LjA3OCw0LjA3OGMwLDAuNTUyLDAuNDQ4LDEsMSwxczEtMC40NDcsMS0xYzAtMS4xNDYsMC45MzItMi4wNzgsMi4wNzgtMi4wNzggICBjMC41NTIsMCwxLTAuNDQ4LDEtMVMxNi41NTIsMTIuOTIsMTYsMTIuOTJ6Ii8+PHBhdGggY2xhc3M9InN0MiIgZD0iTTI1LDI2aC0xLjQyMkg4LjQyMkg3Yy0wLjU1MiwwLTEsMC40NDctMSwxczAuNDQ4LDEsMSwxaDE4YzAuNTUzLDAsMS0wLjQ0NywxLTFTMjUuNTUzLDI2LDI1LDI2eiIvPjxwYXRoIGNsYXNzPSJzdDMiIGQ9Ik0xNiw4LjU1MWMwLjU1MiwwLDEtMC40NDgsMS0xVjVjMC0wLjU1Mi0wLjQ0OC0xLTEtMXMtMSwwLjQ0OC0xLDF2Mi41NTFDMTUsOC4xMDMsMTUuNDQ4LDguNTUxLDE2LDguNTUxeiIvPjxwYXRoIGNsYXNzPSJzdDMiIGQ9Ik0yOSwxNy4yMzFoLTIuNTA2Yy0wLjU1MywwLTEsMC40NDctMSwxczAuNDQ3LDEsMSwxSDI5YzAuNTUzLDAsMS0wLjQ0NywxLTFTMjkuNTUzLDE3LjIzMSwyOSwxNy4yMzF6Ii8+PHBhdGggY2xhc3M9InN0MyIgZD0iTTYuNTA2LDE4LjIzMWMwLTAuNTUzLTAuNDQ4LTEtMS0xSDNjLTAuNTUyLDAtMSwwLjQ0Ny0xLDFzMC40NDgsMSwxLDFoMi41MDYgICBDNi4wNTgsMTkuMjMxLDYuNTA2LDE4Ljc4NCw2LjUwNiwxOC4yMzF6Ii8+PHBhdGggY2xhc3M9InN0MyIgZD0iTTcuODY2LDExLjM4YzAuMTk2LDAuMTk5LDAuNDU1LDAuMjk5LDAuNzEzLDAuMjk5YzAuMjUzLDAsMC41MDYtMC4wOTUsMC43MDEtMC4yODcgICBjMC4zOTQtMC4zODcsMC40LTEuMDIsMC4wMTMtMS40MTRMNy41MjEsOC4xNzVDNy4xMzMsNy43OCw2LjUsNy43NzUsNi4xMDcsOC4xNjJjLTAuMzk0LDAuMzg3LTAuNCwxLjAyLTAuMDEzLDEuNDE0TDcuODY2LDExLjM4eiIvPjxwYXRoIGNsYXNzPSJzdDMiIGQ9Ik0yMy40MiwxMS42NzljMC4yNTksMCwwLjUxOC0wLjEsMC43MTMtMC4yOTlsMS43NzItMS44MDRjMC4zODgtMC4zOTQsMC4zODItMS4wMjctMC4wMTItMS40MTQgICBjLTAuMzk2LTAuMzg3LTEuMDI4LTAuMzgyLTEuNDE0LDAuMDEzbC0xLjc3MiwxLjgwNGMtMC4zODgsMC4zOTQtMC4zODIsMS4wMjcsMC4wMTIsMS40MTQgICBDMjIuOTE0LDExLjU4NCwyMy4xNjcsMTEuNjc5LDIzLjQyLDExLjY3OXoiLz48L2c+PC9zdmc+

.. |In development| image:: https://img.shields.io/badge/feature-in%20development-yellow?logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiA/PjwhRE9DVFlQRSBzdmcgIFBVQkxJQyAnLS8vVzNDLy9EVEQgU1ZHIDEuMS8vRU4nICAnaHR0cDovL3d3dy53My5vcmcvR3JhcGhpY3MvU1ZHLzEuMS9EVEQvc3ZnMTEuZHRkJz48c3ZnIGhlaWdodD0iNjBweCIgaWQ9IkxheWVyXzEiIHN0eWxlPSJlbmFibGUtYmFja2dyb3VuZDpuZXcgMCAwIDY0LjAwMSA2MDsiIHZlcnNpb249IjEuMSIgdmlld0JveD0iMCAwIDY0LjAwMSA2MCIgd2lkdGg9IjY0LjAwMXB4IiB4bWw6c3BhY2U9InByZXNlcnZlIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj48ZyBpZD0iU3RhbmRfMV8iPjxnPjxyZWN0IGhlaWdodD0iOCIgc3R5bGU9ImZpbGw6I0IzQjNCMzsiIHdpZHRoPSIzMiIgeD0iMTYuMDAxIiB5PSI0NCIvPjwvZz48L2c+PGcgaWQ9IkxlZyI+PGc+PHBhdGggZD0iTTguMDAxLDU2YzAsMi4yMDksMS43OTEsNCw0LDRzNC0xLjc5MSw0LTRWNmgtOFY1NnogTTQ4LjAwMSw2djUwYzAsMi4yMDksMS43OSw0LDQsNCAgICBjMi4yMDksMCw0LTEuNzkxLDQtNFY2SDQ4LjAwMXoiIHN0eWxlPSJmaWxsOiNDQ0NDQ0M7Ii8+PC9nPjwvZz48ZyBpZD0iQmFyIj48Zz48cGF0aCBkPSJNNjAuNDQ1LDE1Ljk5OUgzLjU1NkMxLjU5MiwxNS45OTksMCwxNy42MDksMCwxOS41OTZ2OC43ODljMCwxLjk4NiwxLjU5MiwzLjU5NywzLjU1NiwzLjU5N2g1Ni44OSAgICBjMS45NjMsMCwzLjU1NS0xLjYxLDMuNTU1LTMuNTk3di04Ljc4OUM2NCwxNy42MDksNjIuNDA4LDE1Ljk5OSw2MC40NDUsMTUuOTk5eiIgc3R5bGU9ImZpbGw6I0U2RTZFNjsiLz48L2c+PC9nPjxnIGlkPSJTdHJpcGVzXzFfIj48Zz48cGF0aCBkPSJNMTAuMDAxLDE2bC0xMCwxMHYyLjM5NWMwLjAwNSwxLjk4MSwxLjU5NCwzLjU4NywzLjU1NSwzLjU4NyAgICBINi4wMkwyMi4wMDEsMTZIMTAuMDAxeiBNNjAuNDU1LDE2aC0yLjQ1NEw0Mi4wMiwzMS45ODFoMTJsOS45OC05Ljk4di0yLjQwNUM2NCwxNy42MTIsNjIuNDEzLDE2LjAwNiw2MC40NTUsMTZ6IE0zNC4wMDEsMTYgICAgbC0xNiwxNmgxMmwxNi0xNkgzNC4wMDF6IiBzdHlsZT0iZmlsbC1ydWxlOmV2ZW5vZGQ7Y2xpcC1ydWxlOmV2ZW5vZGQ7ZmlsbDojRkY4ODMzOyIvPjwvZz48L2c+PGcgaWQ9IkxpZ2h0cyI+PGc+PHBhdGggZD0iTTEyLjAwMSwwYy0zLjMxMywwLTYsMi42ODYtNiw2YzAsMy4zMTMsMi42ODcsNiw2LDYgICAgczYtMi42ODcsNi02QzE4LjAwMSwyLjY4NiwxNS4zMTQsMCwxMi4wMDEsMHogTTUyLjAwMSwwYy0zLjMxMywwLTYsMi42ODYtNiw2YzAsMy4zMTMsMi42ODcsNiw2LDZzNi0yLjY4Nyw2LTYgICAgQzU4LjAwMSwyLjY4Niw1NS4zMTQsMCw1Mi4wMDEsMHoiIHN0eWxlPSJmaWxsLXJ1bGU6ZXZlbm9kZDtjbGlwLXJ1bGU6ZXZlbm9kZDtmaWxsOiNGRkNDNjY7Ii8+PC9nPjwvZz48Zy8+PGcvPjxnLz48Zy8+PGcvPjxnLz48Zy8+PGcvPjxnLz48Zy8+PGcvPjxnLz48Zy8+PGcvPjxnLz48L3N2Zz4=

.. |Implemented| image:: https://img.shields.io/badge/feature-implemented-2ba686?logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiA/PjxzdmcgaWQ9IkxheWVyXzEiIHN0eWxlPSJlbmFibGUtYmFja2dyb3VuZDpuZXcgMCAwIDEyOCAxMjg7IiB2ZXJzaW9uPSIxLjEiIHZpZXdCb3g9IjAgMCAxMjggMTI4IiB4bWw6c3BhY2U9InByZXNlcnZlIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj48c3R5bGUgdHlwZT0idGV4dC9jc3MiPgoJLnN0MHtmaWxsOiMzMUFGOTE7fQoJLnN0MXtmaWxsOiNGRkZGRkY7fQo8L3N0eWxlPjxnPjxjaXJjbGUgY2xhc3M9InN0MCIgY3g9IjY0IiBjeT0iNjQiIHI9IjY0Ii8+PC9nPjxnPjxwYXRoIGNsYXNzPSJzdDEiIGQ9Ik01NC4zLDk3LjJMMjQuOCw2Ny43Yy0wLjQtMC40LTAuNC0xLDAtMS40bDguNS04LjVjMC40LTAuNCwxLTAuNCwxLjQsMEw1NSw3OC4xbDM4LjItMzguMiAgIGMwLjQtMC40LDEtMC40LDEuNCwwbDguNSw4LjVjMC40LDAuNCwwLjQsMSwwLDEuNEw1NS43LDk3LjJDNTUuMyw5Ny42LDU0LjcsOTcuNiw1NC4zLDk3LjJ6Ii8+PC9nPjwvc3ZnPg==
