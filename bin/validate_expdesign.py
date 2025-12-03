#!/usr/bin/env python3
"""
Validates OpenMS experimental design files for duplicate (Fraction_Group, Fraction, Label) combinations.

This script checks the experimental design file generated from SDRF conversion to ensure that
each combination of (Fraction_Group, Fraction, Label) appears only once, which is a requirement
for downstream OpenMS tools like MSstatsConverter and ProteinQuantifier.
"""

import sys
import argparse
import csv
from collections import defaultdict


def validate_expdesign(expdesign_file):
    """
    Validate the experimental design file for duplicate combinations.
    
    Args:
        expdesign_file: Path to the OpenMS experimental design TSV file
        
    Returns:
        bool: True if validation passes, False otherwise
    """
    print(f"Validating experimental design file: {expdesign_file}")
    
    # Track combinations and their row numbers
    combinations = defaultdict(list)
    
    # Read the file
    try:
        with open(expdesign_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='\t')
            
            # Check if required columns exist
            required_cols = ['Fraction_Group', 'Fraction', 'Label']
            if not all(col in reader.fieldnames for col in required_cols):
                print(f"ERROR: Missing required columns. Expected columns: {required_cols}")
                print(f"Found columns: {reader.fieldnames}")
                return False
            
            # Check each row for duplicates
            for row_num, row in enumerate(reader, start=2):  # Start at 2 because line 1 is header
                fraction_group = row.get('Fraction_Group', '')
                fraction = row.get('Fraction', '')
                label = row.get('Label', '')
                
                # Create the combination tuple
                combination = (fraction_group, fraction, label)
                
                # Track which rows have this combination
                combinations[combination].append({
                    'row': row_num,
                    'data': row
                })
        
        # Check for duplicates
        duplicates_found = False
        for combination, occurrences in combinations.items():
            if len(occurrences) > 1:
                duplicates_found = True
                fraction_group, fraction, label = combination
                print(f"\nERROR: Duplicate (Fraction_Group={fraction_group}, Fraction={fraction}, Label={label}) combination found!")
                print(f"This combination appears {len(occurrences)} times in the following rows:")
                
                for occurrence in occurrences:
                    row_num = occurrence['row']
                    data = occurrence['data']
                    # Get relevant columns for display
                    sample = data.get('Sample', 'N/A')
                    spectra = data.get('Spectra_Filepath', data.get('MSRun', 'N/A'))
                    print(f"  - Row {row_num}: Sample={sample}, Spectra={spectra}")
        
        if duplicates_found:
            print("\n" + "="*80)
            print("VALIDATION FAILED: Duplicate (Fraction_Group, Fraction, Label) combinations detected!")
            print("="*80)
            print("\nPlease fix the SDRF file to ensure each (Fraction_Group, Fraction, Label) combination is unique.")
            print("Common causes:")
            print("  - Duplicate label assignments for the same data file")
            print("  - Incorrect fraction or fraction group assignments")
            print("  - Copy-paste errors in the SDRF file")
            return False
        else:
            print(f"\n✓ Validation passed: All {len(combinations)} (Fraction_Group, Fraction, Label) combinations are unique.")
            return True
            
    except FileNotFoundError:
        print(f"ERROR: File not found: {expdesign_file}")
        return False
    except Exception as e:
        print(f"ERROR: Failed to read or parse the file: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Validate OpenMS experimental design files for duplicate combinations',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        '--expdesign',
        required=True,
        help='Path to the OpenMS experimental design TSV file'
    )
    
    args = parser.parse_args()
    
    # Run validation
    is_valid = validate_expdesign(args.expdesign)
    
    # Exit with appropriate code
    if is_valid:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
