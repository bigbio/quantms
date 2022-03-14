How to debug the pipeline
=========================

quantms provides multiple strategies to **debug** and trace the behaviour of the workflow and the corresponding tools. The workflow use different parameters to debug the specific tools or set of tools that perform similar tasks:

- `pp_debug`: this parameter is used to debug the peak picking tool (see :doc:`preprocessing`).
- `db_debug`: this parameter is used to debug all the search engines (:doc:`comet` and :doc:`msgf`).
- `luciphor_debug`: this parameter is used to debug the modification localization step with luciphor (:doc:`modlocal`)
- `inf_quant_debug`: this parameter is used to debug the proteomicsLFQ tool, which is used for the LFQ (:doc:`lfq`) analysis, including the steps for feature detection, protein inference and peptide/protein quantification.
- `iso_debug`: this parameter is used to debug the isobaric analyzer (:doc:`iso`) which perform feature detection in isobaric experiments (e.g. TMT, iTRAQ).

.. tip:: The value of the parameter range from 0 (no debug) to 1000, maximum verbose.

Log files
-------------------

Log files are stored in the corresponding folder of each step. For example, for comet searches (:doc:`comet`) are stored in the folder `searchenginecomet/` with the extension **.log**:

.. code-block:: bash

   Debug level: 1000
   >> CometAdapter -in UM_F_50cm_2019_0414.mzML -out UM_F_50cm_2019_0414_comet.idXML -threads 8 -database Homo-sapiens-uniprot-reviewed-contaminants-decoy-202108.fasta -instrument low_res -missed_cleavages 2 -min_peptide_length 6 -max_peptide_length 40 -num_hits 1 -num_enzyme_termini fully -enzyme Trypsin/P -isotope_error 0/1 -precursor_charge 2:4 -fixed_modifications "Carbamidomethyl (C)" "TMT6plex (K)" -variable_modifications "Acetyl (Protein N-term)" "Oxidation (M)" "TMT6plex (Protein N-term)" "TMT6plex (S)" -max_variable_mods_in_peptide 3 -precursor_mass_tolerance 20 -precursor_error_units ppm -fragment_mass_tolerance 0.6 -fragment_bin_offset 0.4 -debug 1000 -force
   Value of string option 'test': 0
   Debug level (after ini file): 1000
   Value of string option 'no_progress': 0
   Value of string option 'comet_executable': comet.exe
   ..........................

Depending of the debug parameter, the log file will contains more or less details about the running details for the specific tool.

Debug nextflow and architecture errors
-----------------------------

Some errors of the pipeline are not related with the pipeline but with the architecture running the pipeline or `nextflow <https://www.nextflow.io>`_. Nextlow enables to debug the pipeline by using the varaible `NXF_DEBUG`, for example, if the user wants to debug an error not related with the data or a tool, it can set the variable before running `export NXF_DEBUG=3`.

.. tip:: Nextlow allows users to `resume <https://www.nextflow.io/blog/2019/troubleshooting-nextflow-resume.html>`_ a previous failing run using the nextflow parameter `-resume`. This feature enables to start the processing from the steps that have fail and do not need to run the entire pipeline again.

For specific errors, and details about how nextflow is executed on each arquitecture, please read the details in `Nextflow executors <https://www.nextflow.io/docs/latest/executor.html>`_.

