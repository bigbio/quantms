#!/usr/bin/env python

# nf-core: Update the script to check the sdrf
# This script is based on the example at: https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

import os
import sys
import errno
import argparse
from sdrf_pipelines.sdrf.sdrf import SdrfDataFrame
from sdrf_pipelines.sdrf.sdrf_schema import MASS_SPECTROMETRY

def parse_args(args=None):
    Description = "Reformat nf-core/quantms sdrf file and check its contents."
    Epilog = "Example usage: python validate_sdrf.py <template> <sdrf> <check_ms>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("TEMPLATE", help="Input sdrf file.")
    parser.add_argument("SDRF", help="SDRF file to be validated")
    parser.add_argument("--CHECK_MS", help="check mass spectrometry fields in SDRF.", action="store_true")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)

def check_sdrf(template, check_ms, sdrf):
    df = SdrfDataFrame.parse(sdrf)
    errors = df.validate(template)
    if check_ms:
        errors = errors + df.validate(MASS_SPECTROMETRY)
    print(errors)

def main(args=None):
    args = parse_args(args)
    check_sdrf(args.TEMPLATE, args.CHECK_MS, args.SDRF)


if __name__ == "__main__":
    sys.exit(main())
