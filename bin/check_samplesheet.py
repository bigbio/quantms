#!/usr/bin/env python

# nf-core: Update the script to check the sdrf
# This script is based on the example at: https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv

import errno
import os
import sys

import click
import pandas as pd
from sdrf_pipelines.sdrf.sdrf import SdrfDataFrame
from sdrf_pipelines.sdrf.sdrf_schema import DEFAULT_TEMPLATE, MASS_SPECTROMETRY

CONTEXT_SETTINGS = dict(help_option_names=["-h", "--help"])


@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    """
    This is the main tool that gives access to all commands to convert SDRF files into pipelines-specific configuration
    files.
    """
    pass


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


def check_sdrf(
    input_sdrf: str,
    skip_ms_validation: bool = False,
    skip_factor_validation: bool = False,
    skip_experimental_design_validation: bool = False,
    use_ols_cache_only: bool = False,
    skip_sdrf_validation: bool = False,
):
    """
    Check the SDRF file for errors. If any errors are found, print them and exit with a non-zero status code.
    @param input_sdrf: Path to the SDRF file to check
    @param skip_ms_validation: Disable the validation of mass spectrometry fields in SDRF (e.g. posttranslational modifications)
    @param skip_factor_validation: Disable the validation of factor values in SDRF
    @param skip_experimental_design_validation: Disable the validation of experimental design
    @param use_ols_cache_only: Use ols cache for validation of the terms and not OLS internet service
    @param skip_sdrf_validation: Disable the validation of SDRF
    """
    if skip_sdrf_validation:
        print("No SDRF validation was performed.")
        sys.exit(0)

    df = SdrfDataFrame.parse(input_sdrf)
    errors = df.validate(DEFAULT_TEMPLATE, use_ols_cache_only)

    if not skip_ms_validation:
        errors = errors + df.validate(MASS_SPECTROMETRY, use_ols_cache_only)

    if not skip_factor_validation:
        errors = errors + df.validate_factor_values()

    if not skip_experimental_design_validation:
        errors = errors + df.validate_experimental_design()

    for error in errors:
        print(error)

    sys.exit(bool(errors))


def check_expdesign(expdesign):
    """
    Check the expdesign file for errors. If any errors are found, print them and exit with a non-zero status code.
    @param expdesign: Path to the expdesign file to check
    """
    data = pd.read_csv(expdesign, sep="\t", header=0, dtype=str)
    data = data.dropna()
    schema_file = ["Fraction_Group", "Fraction", "Spectra_Filepath", "Label", "Sample"]
    schema_sample = ["Sample", "MSstats_Condition", "MSstats_BioReplicate"]

    # check table format: two table
    with open(expdesign, "r") as f:
        lines = f.readlines()
        try:
            empty_row = lines.index("\n")
        except ValueError:
            print(
                "the one-table format parser is broken in OpenMS2.5, please use one-table or sdrf"
            )
            sys.exit(1)
        if lines.index("\n") >= len(lines):
            print(
                "the one-table format parser is broken in OpenMS2.5, please use one-table or sdrf"
            )
            sys.exit(1)

        s_table = [i.replace("\n", "").split("\t") for i in lines[empty_row + 1 :]][1:]
        s_header = lines[empty_row + 1].replace("\n", "").split("\t")
        s_DataFrame = pd.DataFrame(s_table, columns=s_header)

    # check missed mandatory column
    missed_columns = set(schema_file) - set(data.columns)
    if len(missed_columns) != 0:
        print("{0} column missed".format(" ".join(missed_columns)))
        sys.exit(1)

    missed_columns = set(schema_sample) - set(s_DataFrame.columns)
    if len(missed_columns) != 0:
        print("{0} column missed".format(" ".join(missed_columns)))
        sys.exit(1)

    if len(set(data.Label)) != 1 and "MSstats_Mixture" not in s_DataFrame.columns:
        print("MSstats_Mixture column missed in ISO experiments")
        sys.exit(1)

    # check a logical problem: may be improved
    check_expdesign_logic(data, s_DataFrame)


def check_expdesign_logic(fTable, sTable):
    if int(max(fTable.Fraction_Group)) > len(set(fTable.Fraction_Group)):
        print("Fraction_Group discontinuous!")
        sys.exit(1)
    fTable_D = fTable.drop_duplicates(["Fraction_Group", "Fraction", "Label", "Sample"])
    if fTable_D.shape[0] < fTable.shape[0]:
        print(
            "Existing duplicate entries in Fraction_Group, Fraction, Label and Sample"
        )
        sys.exit(1)
    if len(set(sTable.Sample)) < sTable.shape[0]:
        print("Existing duplicate Sample in sample table!")
        sys.exit(1)


@click.command(
    "validate", short_help="Reformat nf-core/quantms sdrf file and check its contents."
)
@click.option("--exp_design", help="SDRF/Expdesign file to be validated")
@click.option("--is_sdrf", help="SDRF file or Expdesign file", is_flag=True)
@click.option(
    "--skip_sdrf_validation", help="Disable the validation of SDRF", is_flag=True
)
@click.option(
    "--skip_ms_validation",
    help="Disable the validation of mass spectrometry fields in SDRF (e.g. posttranslational modifications)",
    is_flag=True,
)
@click.option(
    "--skip_factor_validation",
    help="Disable the validation of factor values in SDRF",
    is_flag=True,
)
@click.option(
    "--skip_experimental_design_validation",
    help="Disable the validation of experimental design",
    is_flag=True,
)
@click.option(
    "--use_ols_cache_only",
    help="Use ols cache for validation of the terms and not OLS internet service",
    is_flag=True,
)
def validate(
    exp_design: str,
    is_sdrf: bool = False,
    skip_sdrf_validation: bool = False,
    skip_ms_validation: bool = False,
    skip_factor_validation: bool = False,
    skip_experimental_design_validation: bool = False,
    use_ols_cache_only: bool = False,
):
    """
    Reformat nf-core/quantms sdrf file and check its contents.
    @param exp_design: SDRF/Expdesign file to be validated
    @param is_sdrf: SDRF file or Expdesign file
    @param skip_sdrf_validation: Disable the validation of SDRF
    @param skip_ms_validation: Disable the validation of mass spectrometry fields in SDRF (e.g. posttranslational modifications)
    @param skip_factor_validation: Disable the validation of factor values in SDRF
    @param skip_experimental_design_validation: Disable the validation of experimental design
    @param use_ols_cache_only: Use ols cache for validation of the terms and not OLS internet service

    """
    # TODO validate expdesign file
    if is_sdrf:
        check_sdrf(
            input_sdrf=exp_design,
            skip_sdrf_validation=skip_sdrf_validation,
            skip_ms_validation=skip_ms_validation,
            skip_factor_validation=skip_factor_validation,
            skip_experimental_design_validation=skip_experimental_design_validation,
            use_ols_cache_only=use_ols_cache_only,
        )
    else:
        check_expdesign(exp_design)


cli.add_command(validate)


def main():
    try:
        cli()
    except SystemExit as e:
        if e.code != 0:
            raise


if __name__ == "__main__":
    main()
