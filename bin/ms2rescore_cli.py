#!/usr/bin/env python
# Written by Jonas Scheid under the MIT license


import sys
import click
import importlib.resources
import json
import logging
from typing import List

import pandas as pd

from ms2rescore import rescore, package_data
from psm_utils.io.idxml import IdXMLReader, IdXMLWriter
from psm_utils import PSMList
import pyopenms as oms

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


def parse_cli_arguments_to_config(**kwargs):
    """Update default MS²Rescore config with CLI arguments"""
    config = json.load(importlib.resources.open_text(package_data, "config_default.json"))

    for key, value in kwargs.items():
        # Skip these arguments since they need to set in a nested dict of feature_generators
        if key in ["ms2pip_model", "ms2_tolerance", "rng", "calibration_set_size"]:
            continue

        elif key == "feature_generators":
            feature_generators = value.split(",")
            # Reset feature generator dict since there might be default generators we don't want
            config["ms2rescore"]["feature_generators"] = {}
            if "basic" in feature_generators:
                config["ms2rescore"]["feature_generators"]["basic"] = {}
            if "ms2pip" in feature_generators:
                config["ms2rescore"]["feature_generators"]["ms2pip"] = {
                    "model": kwargs["ms2pip_model"],
                    "ms2_tolerance": kwargs["ms2_tolerance"],
                }
            if "deeplc" in feature_generators:
                config["ms2rescore"]["feature_generators"]["deeplc"] = {
                    "deeplc_retrain": False,
                    "calibration_set_size": kwargs["calibration_set_size"],
                }
            if "maxquant" in feature_generators:
                config["ms2rescore"]["feature_generators"]["maxquant"] = {}
            if "ionmob" in feature_generators:
                config["ms2rescore"]["feature_generators"]["ionmob"] = {}

        elif key == "rescoring_engine":
            # Reset rescoring engine dict we want to allow only computing features
            config["ms2rescore"]["rescoring_engine"] = {}
            if value == "mokapot":
                config["ms2rescore"]["rescoring_engine"]["mokapot"] = {
                    "write_weights": True,
                    "write_txt": False,
                    "write_flashlfq": False,
                    "rng": kwargs["rng"],
                    "test_fdr": kwargs["test_fdr"],
                    "max_workers": kwargs["processes"],
                }
            if value == "percolator":
                logging.info(
                    "Percolator rescoring engine has been specified. Use the idXML containing rescoring features and run Percolator in a separate step."
                )
                continue

        else:
            config["ms2rescore"][key] = value

    return config


def rescore_idxml(input_file, output_file, config) -> None:
    """Rescore PSMs in an idXML file and keep other information unchanged."""
    # Read PSMs
    reader = IdXMLReader(input_file)
    psm_list = reader.read_file()

    # Rescore
    rescore(config, psm_list)

    # Filter out PeptideHits within PeptideIdentification(s) that could not be processed by all feature generators
    peptide_ids_filtered = filter_out_artifact_psms(psm_list, reader.peptide_ids)

    # Write
    writer = IdXMLWriter(output_file, reader.protein_ids, peptide_ids_filtered)
    writer.write_file(psm_list)


def filter_out_artifact_psms(
    psm_list: PSMList, peptide_ids: List[oms.PeptideIdentification]
) -> List[oms.PeptideIdentification]:
    """Filter out PeptideHits that could not be processed by all feature generators"""
    num_mandatory_features = max([len(psm.rescoring_features) for psm in psm_list])
    new_psm_list = PSMList(psm_list=[psm for psm in psm_list if len(psm.rescoring_features) == num_mandatory_features])

    # get differing peptidoforms of both psm lists
    psm_list_peptides = set([next(iter(psm.provenance_data.items()))[1] for psm in psm_list])
    new_psm_list_peptides = set([next(iter(psm.provenance_data.items()))[1] for psm in new_psm_list])
    not_supported_peptides = psm_list_peptides - new_psm_list_peptides

    # no need to filter if all peptides are supported
    if len(not_supported_peptides) == 0:
        return peptide_ids
    # Create new peptide ids and filter out not supported peptides
    new_peptide_ids = []
    for peptide_id in peptide_ids:
        new_hits = []
        for hit in peptide_id.getHits():
            if hit.getSequence().toString() in not_supported_peptides:
                continue
            new_hits.append(hit)
        if len(new_hits) == 0:
            continue
        peptide_id.setHits(new_hits)
        new_peptide_ids.append(peptide_id)
    logging.info(
        f"Removed {len(psm_list_peptides) - len(new_psm_list_peptides)} PSMs. Peptides not supported: {not_supported_peptides}"
    )
    return new_peptide_ids


@click.command()
@click.option(
    "-p", "--psm_file", help="Path to PSM file (PIN, mzIdentML, MaxQuant msms, X!Tandem XML, idXML)", required=True
)
@click.option(
    "-s",
    "--spectrum_path",
    help="Path to MGF/mzML spectrum file or directory with spectrum files (default: derived from identification file)",
    required=True,
)
@click.option(
    "-o", "--output_path", help="Path and stem for output file names (default: derive from identification file)"
)
@click.option("-l", "--log_level", help="Logging level (default: `info`)", default="info")
@click.option("-n", "--processes", help="Number of parallel processes available to MS²Rescore", type=int, default=16)
@click.option("-f", "--fasta_file", help="Path to FASTA file")
@click.option("-t", "--test_fdr", help="The false-discovery rate threshold at which to evaluate the learned models. (default: 0.05)", default=0.05)
@click.option(
    "-fg",
    "--feature_generators",
    help="Comma-separated list of feature generators to use (default: `ms2pip,deeplc`). See ms2rescore doc for further information",
    default="",
)
@click.option("-pipm", "--ms2pip_model", help="MS²PIP model (default: `Immuno-HCD`)", type=str, default="Immuno-HCD")
@click.option(
    "-ms2tol", "--ms2_tolerance", help="Fragment mass tolerance [Da](default: `0.02`)", type=float, default=0.02
)
@click.option(
    "-cs",
    "--calibration_set_size",
    help="Percentage of number of calibration set for DeepLC (default: `0.15`)",
    default=0.15,
)
@click.option("-re", "--rescoring_engine", help="Either mokapot or percolator (default: `mokapot`)", default="mokapot")
@click.option(
    "-rng", "--rng", help="Seed for mokapot's random number generator (default: `4711`)", type=int, default=4711
)
@click.option("-d", "--id_decoy_pattern", help="Regex decoy pattern (default: `DECOY_`)", default="^DECOY_")
@click.option(
    "-lsb",
    "--lower_score_is_better",
    help="Interpretation of primary search engine score (default: True)",
    default=True,
)
def main(**kwargs):
    config = parse_cli_arguments_to_config(**kwargs)
    logging.info("MS²Rescore config:")
    logging.info(config)
    rescore_idxml(kwargs["psm_file"], kwargs["output_path"], config)


if __name__ == "__main__":
    sys.exit(main())
