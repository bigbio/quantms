name: PSMCLEAN
description: A module to clean invalid PSMs
keywords:
  - PSMs
  - clean
tools:
  - custom:
      description: |
        A custom module for PSMs postprocessing.
      homepage: https://github.com/bigbio/quantms
      documentation: https://github.com/bigbio/quantms/tree/readthedocs
input:
  - idxml_file:
      type: file
      description: idXML identification file
      pattern: "*.idXML"
  - mzml:
      type: file
      description: spectrum data file
      pattern: "*.mzML"
  - meta:
      type: map
      description: Groovy Map containing sample information
output:
  - idxml:
      type: file
      description: idXML identification file after postprocessing
      pattern: "*.idXML"
  - version:
      type: file
      description: File containing software version
      pattern: "versions.yml"
authors:
  - "@daichengxin"
