name: SPECTRUM2FEATURES
description: A module to add signal-to-noise ratio features for percolator
keywords:
  - features
  - percolator
tools:
  - custom:
      description: |
        A custom module to add signal-to-noise ratio features.
      homepage: https://github.com/bigbio/quantms
      documentation: https://github.com/bigbio/quantms/tree/readthedocs
input:
  - meta:
      type: map
      description: Groovy Map containing sample information
  - ms_file:
      type: file
      description: |
        A string specifying the path to the mass spectrometry file.
      pattern: "*.mzML"
  - id_file:
      type: file
      description: |
        Input idXML file containing the identifications.
      pattern: "*.idXML"
output:
  - meta:
      type: map
      description: Groovy Map containing sample information
  - id_files_snr:
      type: file
      description: |
        Output file in idXML format
      pattern: "*.idXML"
  - log:
      type: file
      description: log file
      pattern: "*.log"
  - version:
      type: file
      description: File containing software version
      pattern: "versions.yml"
authors:
  - "@daichengxin"
