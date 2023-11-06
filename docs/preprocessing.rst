Conversion and preprocessing
============================

Often mass spectrometry data needs to be converted or preprocessed. quantms checks your input files and
automatically decides on necessary steps.

Mass spectra processing: Raw conversion
---------------------------------------

The RAW data (files from the instrument) can be provided to quantms pipeline in two different formats: (i) RAW files - instrument files; (ii) mzML files (HUPO-PSI standard file format). quantms uses the `thermorawfileparser <https://github.com/compomics/ThermoRawFileParser>`_ to convert the input RAW files to mzML and all the following steps are built in top of the standard mzML.

.. important:: Automatic RAW file conversion is only supported from Thermo Scientific.

Additionally to file conversion, the Raw conversion step allows the users to perform an extra peak-picking step ``openmspeakpicker true`` for those datasets/projects where peaks can be extracted using the Thermo RAW API. Read more about the OpenMS peak picker algorithm `here <https://abibuilder.informatik.uni-tuebingen.de/archive/openms/Documentation/nightly/html/TOPP_PeakPickerWavelet.html>`_ .
When bruker .d files are provided, quantms provides an optional parameter `convert_dotd` to convert .d to mzML (default false).

Mass spectra statistics: Quality metrics extraction
---------------------------------------

The mass spectrum file can be parsed and generates a set of statistics about the file by `script <https://github.com/bigbio/quantms/blob/dev/bin/mzml_statistics.py>`_ , and then passed to the pmultiqc module to perform quality control visualization.
including as follow columns:

- ``SpectrumID``
- ``MSLevel``
- ``Charge``
- ``MS_peaks``
- ``Base_Peak_Intensity``
- ``Retention_Time``
- ``Exp_Mass_To_Charge``
- ``AcquisitionDateTime``
