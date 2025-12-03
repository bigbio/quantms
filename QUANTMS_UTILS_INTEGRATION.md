# quantms-utils Integration Requirements

This document describes the validation functionality that needs to be added to the `quantms-utils` library to support the experimental design validation feature in quantms.

## Required Command

Add a new command `validateexpdesign` to the `quantmsutilsc` CLI tool in quantms-utils.

### Command Signature

```bash
quantmsutilsc validateexpdesign --expdesign <path_to_expdesign_file>
```

### Functionality

The command should validate OpenMS experimental design files for duplicate `(Fraction_Group, Fraction, Label)` combinations.

#### Input
- `--expdesign`: Path to the OpenMS experimental design TSV file

#### Validation Logic
1. Read the TSV file with tab delimiter
2. Check for required columns: `Fraction_Group`, `Fraction`, `Label`
3. For each row, extract the combination of `(Fraction_Group, Fraction, Label)`
4. Track all occurrences of each combination with row numbers
5. If any combination appears more than once, report:
   - The duplicate combination values
   - How many times it appears
   - The specific row numbers where it appears
   - Sample and Spectra_Filepath/MSRun information for each duplicate row

#### Output
- **On success**: Print validation success message and exit with code 0
- **On failure**: Print detailed error messages showing:
  - Which combinations are duplicated
  - Row numbers for each duplicate
  - Sample and file information for debugging
  - Exit with code 1

#### Example Output (Success)
```
Validating experimental design file: test_design.tsv

✓ Validation passed: All 24 (Fraction_Group, Fraction, Label) combinations are unique.
```

#### Example Output (Failure)
```
Validating experimental design file: test_design.tsv

ERROR: Duplicate (Fraction_Group=1, Fraction=1, Label=TMT130N) combination found!
This combination appears 2 times in the following rows:
  - Row 2: Sample=TMT130N_mus, Spectra=Margolis_Mouse_Neuronal_TMT_TP_F1.mzML
  - Row 4: Sample=TMT130N_mus, Spectra=Margolis_Mouse_Neuronal_TMT_TP_F1.mzML

================================================================================
VALIDATION FAILED: Duplicate (Fraction_Group, Fraction, Label) combinations detected!
================================================================================

Please fix the SDRF file to ensure each (Fraction_Group, Fraction, Label) combination is unique.
Common causes:
  - Duplicate label assignments for the same data file
  - Incorrect fraction or fraction group assignments
  - Copy-paste errors in the SDRF file
```

## Implementation Reference

The reference implementation is currently in `bin/validate_expdesign.py` in this repository. The core validation logic should be extracted and adapted for quantms-utils:

### Key Components
1. **Function**: `validate_expdesign(expdesign_file: str) -> bool`
2. **Error handling**: File not found, missing columns, CSV parsing errors
3. **Duplicate detection**: Using combinations as dictionary keys to track occurrences
4. **Detailed reporting**: Row numbers, sample names, file paths for each duplicate

### Suggested Location in quantms-utils
- Module: `quantmsutils/sdrf/expdesign_validator.py`
- CLI integration: `quantmsutils/commands/validateexpdesign.py`

## Usage in quantms

Once the command is available in quantms-utils, it will be called by:
1. **PREPROCESS_EXPDESIGN** process - validates user-provided experimental designs
2. **SDRF_PARSING** process - uses the bin/validate_expdesign.py script (since it uses sdrf-pipelines container)

## Container Requirements

The validation command must be available in the `quantms-utils` container:
- Container: `biocontainers/quantms-utils:0.0.25` (or later version)
- The command should be accessible via the `quantmsutilsc` entry point

## Migration Plan

1. Add validation function to quantms-utils library
2. Add CLI command to quantmsutilsc
3. Release new version of quantms-utils (e.g., 0.0.25)
4. Update quantms to use the new version
5. Eventually remove bin/validate_expdesign.py from quantms (after ensuring both containers can use quantms-utils)
