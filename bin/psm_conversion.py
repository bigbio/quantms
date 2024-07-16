#!/usr/bin/env python

import numpy as np
import pyopenms as oms
import pandas as pd
import re
import os
from pathlib import Path
import sys

_parquet_field = [
    "sequence", "protein_accessions", "protein_start_positions", "protein_end_positions",
    "modifications", "retention_time", "charge", "calc_mass_to_charge", "reference_file_name",
    "scan_number", "peptidoform", "posterior_error_probability", "global_qvalue", "is_decoy",
    "consensus_support", "mz_array", "intensity_array", "num_peaks", "search_engines", "id_scores", "hit_rank"
]


def mods_position(peptide):
    if peptide.startswith("."):
        peptide = peptide[1:]
    pattern = re.compile(r"\((.*?)\)")
    original_mods = pattern.findall(peptide)
    peptide = re.sub(r"\(.*?\)", ".", peptide)
    position = [i.start() for i in re.finditer(r"\.", peptide)]
    for j in range(1, len(position)):
        position[j] -= j

    for k in range(0, len(original_mods)):
        original_mods[k] = str(position[k]) + "-" + original_mods[k]

    original_mods = [str(i) for i in original_mods] if len(original_mods) > 0 else np.nan

    return original_mods


def convert_psm(idxml, spectra_file, export_decoy_psm):
    prot_ids = []
    pep_ids = []
    parquet_data = []
    consensus_support = np.nan
    mz_array = []
    intensity_array = []
    num_peaks = np.nan
    id_scores = []
    search_engines = []

    oms.IdXMLFile().load(idxml, prot_ids, pep_ids)
    if "ConsensusID" in prot_ids[0].getSearchEngine():
        if prot_ids[0].getSearchParameters().metaValueExists("SE:MS-GF+"):
            search_engines = ["MS-GF+"]
        if prot_ids[0].getSearchParameters().metaValueExists("SE:Comet"):
            search_engines.append("Comet")
        if prot_ids[0].getSearchParameters().metaValueExists("SE:Sage"):
            search_engines.append("Sage")
    else:
        search_engines = [prot_ids[0].getSearchEngine()]

    reference_file_name = os.path.splitext(prot_ids[0].getMetaValue("spectra_data")[0].decode("UTF-8"))[0]
    spectra_df = pd.read_csv(spectra_file) if spectra_file else None

    for peptide_id in pep_ids:
        retention_time = peptide_id.getRT()
        calc_mass_to_charge = peptide_id.getMZ()
        scan_number = int(re.findall(r"(spectrum|scan)=(\d+)", peptide_id.getMetaValue("spectrum_reference"))[0][1])

        if isinstance(spectra_df, pd.DataFrame):
            spectra = spectra_df[spectra_df["scan"] == scan_number]
            mz_array = spectra["mz"].values
            intensity_array = spectra["intensity"].values
            num_peaks = len(mz_array)

        for hit in peptide_id.getHits():
            # if remove decoy when mapped to target+decoy?
            is_decoy = 0 if hit.getMetaValue("target_decoy") == "target" else 1
            if export_decoy_psm == "false" and is_decoy:
                continue
            global_qvalue = np.nan
            if len(search_engines) > 1:
                if "q-value" in peptide_id.getScoreType():
                    global_qvalue = hit.getScore()
                consensus_support = hit.getMetaValue("consensus_support")
            elif search_engines == "Comet":
                id_scores = ["Comet:Expectation value: " + str(hit.getScore())]
            elif search_engines == "MS-GF+":
                id_scores = ["MS-GF:SpecEValue: " + str(hit.getScore())]
            elif search_engines == "Sage":
                id_scores = ["Sage:hyperscore: " + str(hit.getScore())]

            if hit.metaValueExists("MS:1001491"):
                global_qvalue = hit.getMetaValue("MS:1001491")

            charge = hit.getCharge()
            peptidoform = hit.getSequence().toString()
            modifications = mods_position(peptidoform)
            sequence = hit.getSequence().toUnmodifiedString()
            protein_accessions = [ev.getProteinAccession() for ev in hit.getPeptideEvidences()]
            posterior_error_probability = hit.getMetaValue("Posterior Error Probability_score")
            protein_start_positions = [ev.getStart() for ev in hit.getPeptideEvidences()]
            protein_end_positions = [ev.getEnd() for ev in hit.getPeptideEvidences()]
            hit_rank = hit.getRank()

            parquet_data.append([sequence, protein_accessions, protein_start_positions, protein_end_positions,
                                 modifications, retention_time, charge, calc_mass_to_charge, reference_file_name,
                                 scan_number, peptidoform, posterior_error_probability, global_qvalue, is_decoy,
                                 consensus_support, mz_array, intensity_array, num_peaks, search_engines, id_scores,
                                 hit_rank])

    pd.DataFrame(parquet_data, columns=_parquet_field).to_csv(f"{Path(idxml).stem}_psm.csv",
                                                              mode="w",
                                                              index=False,
                                                              header=True)


def main():
    idxml_path = sys.argv[1]
    spectra_file = sys.argv[2]
    export_decoy_psm = sys.argv[3]
    convert_psm(idxml_path, spectra_file, export_decoy_psm)


if __name__ == "__main__":
    sys.exit(main())
