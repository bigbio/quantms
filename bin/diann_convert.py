#!/usr/bin/env python
"""
This script converts the output from DIA-NN into three standard formats: MSstats, Triqler and mzTab.
License: Apache 2.0
Authors: Hong Wong, Yasset Perez-Riverol
Revisions:
    2023-Aug-05: J. Sebastian Paez
"""
import logging
import os
import re
import warnings
from pathlib import Path
from typing import Any, List, Tuple, Dict, Set, Union

import click
import numpy as np
import pandas as pd
from pyopenms import AASequence, FASTAFile, ModificationsDB
from pyopenms.Constants import PROTON_MASS_U

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 500)
pd.set_option("display.width", 1000)

CONTEXT_SETTINGS = dict(help_option_names=["-h", "--help"])
REVISION = "0.1.1"

logging.basicConfig(format="%(asctime)s [%(funcName)s] - %(message)s", level=logging.DEBUG)
logger = logging.getLogger(__name__)


@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass


@click.command("convert")
@click.option("--folder", "-f")
@click.option("--exp_design", "-d")
@click.option("--diann_version", "-v")
@click.option("--dia_params", "-p")
@click.option("--charge", "-c")
@click.option("--missed_cleavages", "-m")
@click.option("--qvalue_threshold", "-q", type=float)
@click.pass_context
def convert(ctx, folder, exp_design, dia_params, diann_version, charge, missed_cleavages, qvalue_threshold):
    """
    Convert DIA-NN output to MSstats, Triqler or mzTab.
    The output formats are used for quality control and downstream analysis.

    :param folder: DiannConvert specifies the folder where the required file resides. The folder contains
        the DiaNN main report, protein matrix, precursor matrix, experimental design file, protein sequence
        FASTA file, version file of DiaNN and ms_info TSVs
    :type folder: str
    :param dia_params: A list contains DIA parameters
    :type dia_params: list
    :param diann_version: Path to a version file of DIA-NN
    :type diann_version: str
    :param charge: The charge assigned by DIA-NN(max_precursor_charge)
    :type charge: int
    :param missed_cleavages: Allowed missed cleavages assigned by DIA-NN
    :type missed_cleavages: int
    :param qvalue_threshold: Threshold for filtering q value
    :type qvalue_threshold: float
    """
    logger.debug(f"Revision {REVISION}")
    logger.debug("Reading input files...")
    diann_directory = DiannDirectory(folder, diann_version_file=diann_version)
    report = diann_directory.main_report_df(qvalue_threshold=qvalue_threshold)
    s_DataFrame, f_table = get_exp_design_dfs(exp_design)

    # Convert to MSstats
    msstats_columns_keep = [
        "Protein.Names",
        "Modified.Sequence",
        "Precursor.Charge",
        "Precursor.Quantity",
        "File.Name",
        "Run",
    ]

    logger.debug("Converting to MSstats format...")
    out_msstats = report[msstats_columns_keep]
    out_msstats.columns = ["ProteinName", "PeptideSequence", "PrecursorCharge", "Intensity", "Reference", "Run"]
    out_msstats = out_msstats[out_msstats["Intensity"] != 0]

    # Q: What is this line doing?
    out_msstats.loc[:, "PeptideSequence"] = out_msstats.apply(
        lambda x: AASequence.fromString(x["PeptideSequence"]).toString(), axis=1
    )
    out_msstats["FragmentIon"] = "NA"
    out_msstats["ProductCharge"] = "0"
    out_msstats["IsotopeLabelType"] = "L"
    unique_reference_map = {k: os.path.basename(k) for k in out_msstats["Reference"].unique()}
    out_msstats["Reference"] = out_msstats["Reference"].map(unique_reference_map)
    del unique_reference_map

    logger.debug("\n\nReference Column >>>")
    logger.debug(out_msstats["Reference"])

    logger.debug(f"\n\nout_msstats ({out_msstats.shape}) >>>")
    logger.debug(out_msstats.head(5))

    logger.debug(f"\n\nf_table ({f_table.shape})>>>")
    logger.debug(f_table.head(5))

    logger.debug(f"\n\ns_DataFrame ({s_DataFrame.shape})>>>")
    logger.debug(s_DataFrame.head(5))

    logger.debug("Adding Fraction, BioReplicate, Condition columns")
    # Changing implementation from apply to merge went from several minutes to
    # ~50ms
    out_msstats = out_msstats.merge(
        (
            s_DataFrame[["Sample", "MSstats_Condition", "MSstats_BioReplicate"]]
            .merge(f_table[["Fraction", "Sample", "run"]], on="Sample")
            .rename(columns={"run": "Run", "MSstats_BioReplicate": "BioReplicate", "MSstats_Condition": "Condition"})
            .drop(columns=["Sample"])
        ),
        on="Run",
        validate="many_to_one",
    )
    exp_out_prefix = Path(exp_design).stem
    out_msstats.to_csv(exp_out_prefix + "_msstats_in.csv", sep=",", index=False)
    logger.info(f"MSstats input file is saved as {exp_out_prefix}_msstats_in.csv")

    # Convert to Triqler
    triqler_cols = ["ProteinName", "PeptideSequence", "PrecursorCharge", "Intensity", "Run", "Condition"]
    out_triqler = out_msstats[triqler_cols]
    del out_msstats
    out_triqler.columns = ["proteins", "peptide", "charge", "intensity", "run", "condition"]
    out_triqler = out_triqler[out_triqler["intensity"] != 0]

    out_triqler.loc[:, "searchScore"] = report["Q.Value"]
    out_triqler.loc[:, "searchScore"] = 1 - out_triqler["searchScore"]
    out_triqler.to_csv(exp_out_prefix + "_triqler_in.tsv", sep="\t", index=False)
    logger.info(f"Triqler input file is saved as {exp_out_prefix}_triqler_in.tsv")
    del out_triqler

    mztab_out = f"{Path(exp_design).stem}_out.mzTab"
    # Convert to mzTab
    diann_directory.convert_to_mztab(
        report=report,
        f_table=f_table,
        charge=charge,
        missed_cleavages=missed_cleavages,
        dia_params=dia_params,
        out=mztab_out,
    )


def _true_stem(x):
    """
    Return the true stem of a file name, i.e. the
    file name without the extension.

    :param x: The file name
    :type x: str
    :return: The true stem of the file name
    :rtype: str

    Examples:
    >>> _true_stem("foo.mzML")
    'foo'
    >>> _true_stem("foo.d.tar")
    'foo'

    These examples can be tested with pytest:
    $ pytest -v --doctest-modules
    """
    split = os.path.basename(x).split(".")
    stem = split[0]

    # Should I check here that the extensions are
    # allowed? I can see how this would break if the
    # file name contains a period.
    return stem


def get_exp_design_dfs(exp_design_file):
    logger.info(f"Reading experimental design file: {exp_design_file}")
    with open(exp_design_file, "r") as f:
        data = f.readlines()
        empty_row = data.index("\n")
        f_table = [i.replace("\n", "").split("\t") for i in data[1:empty_row]]
        f_header = data[0].replace("\n", "").split("\t")
        f_table = pd.DataFrame(f_table, columns=f_header)
        f_table.loc[:, "run"] = f_table.apply(lambda x: _true_stem(x["Spectra_Filepath"]), axis=1)

        s_table = [i.replace("\n", "").split("\t") for i in data[empty_row + 1 :]][1:]
        s_header = data[empty_row + 1].replace("\n", "").split("\t")
        s_DataFrame = pd.DataFrame(s_table, columns=s_header)

    return s_DataFrame, f_table

def compute_mass_modified_peptide(peptide_seq: str) -> float:
    """
    Function that takes a peptide sequence including modifications and compute the mass using the AASequence class from
    pyopenms. The notation of a peptidoform for pyopenms is the following:

    if not modifications is present:
      AVQVHQDTLRTMYFAXR -> AVQVHQDTLRTMYFAX[178.995499]R
    if modification is present in Methionine:
      AVQVHQDTLRTM(Oxidation)YFAXR -> AVQVHQDTLRTM(Oxidation)YFAX[178.995499]R

    @param peptide_seq: str, peptide sequence
    @return: float, mass of the peptide
    """
    peptide_parts: List[str] = []
    not_mod = True
    aa_mass = {
        "X": "X[178.98493453312]",  # 196.995499 - 17.003288 - 1.00727646688
        "U": "U[132.94306553312]",  # 150.95363  - 17.003288 - 1.00727646688
        "O": "O[237.14773053312]",  # 255.158295 - 17.003288 - 1.00727646688
    }
    for aa in peptide_seq:
        # Check if the letter is in aminoacid
        if aa == "(":
            not_mod = False
        elif aa == ")":
            not_mod = True
        # Check aminoacid letter
        if aa in aa_mass and not_mod:
            aa = aa_mass[aa]
        elif aa not in ['G','A','V','L','I','F','M','P','W','S','C','T','Y','N','Q','D','E','K','R','H'] and not_mod and aa != ")":
            aa = aa+"[0.0000]"
        peptide_parts.append(aa)
    new_peptide_seq = ''.join(peptide_parts)
    mass = AASequence.fromString(new_peptide_seq).getMonoWeight()
    logger.debug(new_peptide_seq + ":" + str(mass))
    return mass

class DiannDirectory:
    def __init__(self, base_path, diann_version_file):
        self.base_path = Path(base_path)
        if not self.base_path.exists() and not self.base_path.is_dir():
            raise NotADirectoryError(f"Path {self.base_path} does not exist")
        self.diann_version_file = Path(diann_version_file)
        if not self.diann_version_file.is_file():
            raise FileNotFoundError(f"Path {self.diann_version_file} does not exist")

    def find_first_file_with_suffix(self, suffix: str) -> os.PathLike:
        """Finds a file with a given suffix in the directory.

        :param suffix: The suffix to search for
        :type suffix: str

        :raises FileNotFoundError: If no file with the given suffix is found
        """
        try:
            return next(self.base_path.glob(f"**/*{suffix}"))
        except StopIteration:
            raise FileNotFoundError(f"Could not find file with suffix {suffix}")

    @property
    def report(self) -> os.PathLike:
        return self.find_first_file_with_suffix("report.tsv")

    @property
    def pg_matrix(self) -> os.PathLike:
        return self.find_first_file_with_suffix("pg_matrix.tsv")

    @property
    def pr_matrix(self) -> os.PathLike:
        return self.find_first_file_with_suffix("pr_matrix.tsv")

    @property
    def fasta(self) -> os.PathLike:
        try:
            return self.find_first_file_with_suffix(".fasta")
        except FileNotFoundError:
            return self.find_first_file_with_suffix(".fa")

    @property
    def ms_info(self) -> os.PathLike:
        return self.find_first_file_with_suffix("ms_info.tsv")

    @property
    def diann_version(self) -> str:
        logger.debug("Validating DIANN version")
        diann_version_id = None
        with open(self.diann_version_file) as f:
            for line in f:
                if "DIA-NN" in line:
                    logger.debug(f"Found DIA-NN version: {line}")
                    diann_version_id = line.rstrip("\n").split(": ")[1]

        if diann_version_id is None:
            raise ValueError(f"Could not find DIA-NN version in file {self.diann_version_file}")

        return diann_version_id

    def validate_diann_version(self) -> None:
        supported_diann_versions = ["1.8.1"]
        if self.diann_version not in supported_diann_versions:
            raise ValueError(f"Unsupported DIANN version {self.diann_version}")

    def convert_to_mztab(
        self, report, f_table, charge: int, missed_cleavages: int, dia_params: List[Any], out: os.PathLike
    ) -> None:
        logger.info("Converting to mzTab")
        self.validate_diann_version()

        # This could be a branching point if we want to support other versions
        # of DIA-NN, maybe something like this:
        # if diann_version_id == "1.8.1":
        #     self.convert_to_mztab_1_8_1(report, f_table, charge, missed_cleavages, dia_params)
        # else:
        #     raise ValueError(f"Unsupported DIANN version {diann_version_id}, supported versions are 1.8.1 ...")

        logger.info(f"Reading fasta file: {self.fasta}")
        entries: list = []
        f = FASTAFile()
        f.load(str(self.fasta), entries)
        fasta_entries = [(e.identifier, e.sequence, len(e.sequence)) for e in entries]
        fasta_df = pd.DataFrame(fasta_entries, columns=["id", "seq", "len"])

        logger.info("Mapping run information to report")
        index_ref = f_table.copy()
        index_ref.rename(columns={"Fraction_Group": "ms_run", "Sample": "study_variable", "run": "Run"}, inplace=True)
        index_ref["ms_run"] = index_ref["ms_run"].astype("int")
        index_ref["study_variable"] = index_ref["study_variable"].astype("int")
        report = report.merge(index_ref[["ms_run", "Run", "study_variable"]], on="Run", validate="many_to_one")

        MTD, database = mztab_MTD(index_ref, dia_params, str(self.fasta), charge, missed_cleavages)
        pg = pd.read_csv(
            self.pg_matrix,
            sep="\t",
            header=0,
        )
        PRH = mztab_PRH(report, pg, index_ref, database, fasta_df)
        del pg
        pr = pd.read_csv(
            self.pr_matrix,
            sep="\t",
            header=0,
        )
        precursor_list = list(report["Precursor.Id"].unique())
        PEH = mztab_PEH(report, pr, precursor_list, index_ref, database)
        del pr
        PSH = mztab_PSH(report, str(self.base_path), database)
        del report
        MTD.loc["", :] = ""
        PRH.loc[len(PRH) + 1, :] = ""
        PEH.loc[len(PEH) + 1, :] = ""
        with open(out, "w", newline="") as f:
            MTD.to_csv(f, mode="w", sep="\t", index=False, header=False)
            PRH.to_csv(f, mode="w", sep="\t", index=False, header=True)
            PEH.to_csv(f, mode="w", sep="\t", index=False, header=True)
            PSH.to_csv(f, mode="w", sep="\t", index=False, header=True)

        logger.info(f"mzTab file generated successfully! at {out}_out.mzTab")

    def main_report_df(self, qvalue_threshold: float) -> pd.DataFrame:
        remain_cols = [
            "File.Name",
            "Run",
            "Protein.Group",
            "Protein.Names",
            "Protein.Ids",
            "First.Protein.Description",
            "PG.MaxLFQ",
            "RT.Start",
            "Global.Q.Value",
            "Lib.Q.Value",
            "PEP",
            "Precursor.Normalised",
            "Precursor.Id",
            "Q.Value",
            "Modified.Sequence",
            "Stripped.Sequence",
            "Precursor.Charge",
            "Precursor.Quantity",
            "Global.PG.Q.Value",
        ]
        report = pd.read_csv(self.report, sep="\t", header=0, usecols=remain_cols)

        # filter based on qvalue parameter for downstream analysiss
        logger.debug(f"Filtering report based on qvalue threshold: {qvalue_threshold}, {len(report)} rows")
        report = report[report["Q.Value"] < qvalue_threshold]
        logger.debug(f"Report filtered, {len(report)} rows remaining")

        logger.debug("Calculating Precursor.Mz")
        # Making the map is 10x faster, and includes the mass of
        # the modification. with respect to the previous implementation.
        uniq_masses = {k: compute_mass_modified_peptide(k) for k in report["Modified.Sequence"].unique()}
        mass_vector = report["Modified.Sequence"].map(uniq_masses)
        report["Calculate.Precursor.Mz"] = (mass_vector + (PROTON_MASS_U * report["Precursor.Charge"])) / report[
            "Precursor.Charge"
        ]

        logger.debug("Indexing Precursors")
        # Making the map is 1500x faster
        precursor_index_map = {k: i for i, k in enumerate(report["Precursor.Id"].unique())}
        report["precursor.Index"] = report["Precursor.Id"].map(precursor_index_map)

        logger.debug(f"Shape of main report {report.shape}")
        logger.debug(str(report.head()))

        return report


def MTD_mod_info(fix_mod, var_mod):
    """
    Convert fixed and variable modifications to the format required by the MTD sub-table.

    :param fix_mod: Fixed modifications from DIA parameter list
    :type fix_mod: str
    :param var_mod: Variable modifications from DIA parameter list
    :type var_mod: str
    :return: A tuple contains fixed and variable modifications, and flags indicating whether they are null
    :rtype: tuple
    """
    var_ptm = []
    fix_ptm = []
    mods_db = ModificationsDB()

    if fix_mod != "null":
        fix_flag = 1
        for mod in fix_mod.split(","):
            mod_obj = mods_db.getModification(mod)
            mod_name = mod_obj.getId()
            mod_accession = mod_obj.getUniModAccession()
            site = mod_obj.getOrigin()
            fix_ptm.append(("[UNIMOD, " + mod_accession.upper() + ", " + mod_name + ", ]", site))
    else:
        fix_flag = 0
        fix_ptm.append("[MS, MS:1002453, No fixed modifications searched, ]")

    if var_mod != "null":
        var_flag = 1
        for mod in var_mod.split(","):
            mod_obj = mods_db.getModification(mod)
            mod_name = mod_obj.getId()
            mod_accession = mod_obj.getUniModAccession()
            site = mod_obj.getOrigin()
            var_ptm.append(("[UNIMOD, " + mod_accession.upper() + ", " + mod_name + ", ]", site))
    else:
        var_flag = 0
        var_ptm.append("[MS, MS:1002454, No variable modifications searched, ]")

    return fix_ptm, var_ptm, fix_flag, var_flag


def mztab_MTD(index_ref, dia_params, fasta, charge, missed_cleavages):
    """
    Construct MTD sub-table.

    :param index_ref: On the basis of f_table, two columns "MS_run" and "study_variable" are added for matching
    :type index_ref: pandas.core.frame.DataFrame
    :param dia_params: A list contains DIA parameters
    :type dia_params: list
    :param fasta: Fasta file path
    :type fasta: str
    :param charge: Charges set by Dia-NN
    :type charge: int
    :param missed_cleavages: Missed cleavages set by Dia-NN
    :type missed_cleavages: int
    :return: MTD sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    logger.info("Constructing MTD sub-table...")
    dia_params_list = dia_params.split(";")
    dia_params_list = ["null" if i == "" else i for i in dia_params_list]
    FragmentMassTolerance = dia_params_list[0]
    FragmentMassToleranceUnit = dia_params_list[1]
    PrecursorMassTolerance = dia_params_list[2]
    PrecursorMassToleranceUnit = dia_params_list[3]
    Enzyme = dia_params_list[4]
    FixedModifications = dia_params_list[5]
    VariableModifications = dia_params_list[6]
    out_mztab_MTD = pd.DataFrame()
    out_mztab_MTD.loc[1, "mzTab-version"] = "1.0.0"
    out_mztab_MTD.loc[1, "mzTab-mode"] = "Summary"
    out_mztab_MTD.loc[1, "mzTab-type"] = "Quantification"
    out_mztab_MTD.loc[1, "title"] = "ConsensusMap export from OpenMS"
    out_mztab_MTD.loc[1, "description"] = "OpenMS export from consensusXML"
    out_mztab_MTD.loc[1, "protein_search_engine_score[1]"] = "[, , DIA-NN Global.PG.Q.Value, ]"
    out_mztab_MTD.loc[1, "peptide_search_engine_score[1]"] = (
        "[, , DIA-NN Q.Value (minimum of the respective precursor q-values), ]"
    )
    out_mztab_MTD.loc[1, "psm_search_engine_score[1]"] = "[MS, MS:MS:1001869, protein-level q-value, ]"
    out_mztab_MTD.loc[1, "software[1]"] = "[MS, MS:1003253, DIA-NN, Release (v1.8.1)]"
    out_mztab_MTD.loc[1, "software[1]-setting[1]"] = fasta
    out_mztab_MTD.loc[1, "software[1]-setting[2]"] = "db_version:null"
    out_mztab_MTD.loc[1, "software[1]-setting[3]"] = "fragment_mass_tolerance:" + FragmentMassTolerance
    out_mztab_MTD.loc[1, "software[1]-setting[4]"] = "fragment_mass_tolerance_unit:" + FragmentMassToleranceUnit
    out_mztab_MTD.loc[1, "software[1]-setting[5]"] = "precursor_mass_tolerance:" + PrecursorMassTolerance
    out_mztab_MTD.loc[1, "software[1]-setting[6]"] = "precursor_mass_tolerance_unit:" + PrecursorMassToleranceUnit
    out_mztab_MTD.loc[1, "software[1]-setting[7]"] = "enzyme:" + Enzyme
    out_mztab_MTD.loc[1, "software[1]-setting[8]"] = "enzyme_term_specificity:full"
    out_mztab_MTD.loc[1, "software[1]-setting[9]"] = "charges:" + str(charge)
    out_mztab_MTD.loc[1, "software[1]-setting[10]"] = "missed_cleavages:" + str(missed_cleavages)
    out_mztab_MTD.loc[1, "software[1]-setting[11]"] = "fixed_modifications:" + FixedModifications
    out_mztab_MTD.loc[1, "software[1]-setting[12]"] = "variable_modifications:" + VariableModifications

    (fixed_mods, variable_mods, fix_flag, var_flag) = MTD_mod_info(FixedModifications, VariableModifications)
    if fix_flag == 1:
        for i in range(1, len(fixed_mods) + 1):
            out_mztab_MTD.loc[1, "fixed_mod[" + str(i) + "]"] = fixed_mods[i - 1][0]
            out_mztab_MTD.loc[1, "fixed_mod[" + str(i) + "]-site"] = fixed_mods[i - 1][1]
            out_mztab_MTD.loc[1, "fixed_mod[" + str(i) + "]-position"] = "Anywhere"
    else:
        out_mztab_MTD.loc[1, "fixed_mod[1]"] = fixed_mods[0]

    if var_flag == 1:
        for i in range(1, len(variable_mods) + 1):
            out_mztab_MTD.loc[1, "variable_mod[" + str(i) + "]"] = variable_mods[i - 1][0]
            out_mztab_MTD.loc[1, "variable_mod[" + str(i) + "]-site"] = variable_mods[i - 1][1]
            out_mztab_MTD.loc[1, "variable_mod[" + str(i) + "]-position"] = "Anywhere"
    else:
        out_mztab_MTD.loc[1, "variable_mod[1]"] = variable_mods[0]

    out_mztab_MTD.loc[1, "quantification_method"] = "[MS, MS:1001834, LC-MS label-free quantitation analysis, ]"
    out_mztab_MTD.loc[1, "protein-quantification_unit"] = "[, , Abundance, ]"
    out_mztab_MTD.loc[1, "peptide-quantification_unit"] = "[, , Abundance, ]"

    for i in range(1, max(index_ref["ms_run"]) + 1):
        out_mztab_MTD.loc[1, "ms_run[" + str(i) + "]-format"] = "[MS, MS:1000584, mzML file, ]"
        out_mztab_MTD.loc[1, "ms_run[" + str(i) + "]-location"] = (
            "file://" + index_ref[index_ref["ms_run"] == i]["Spectra_Filepath"].values[0]
        )
        out_mztab_MTD.loc[1, "ms_run[" + str(i) + "]-id_format"] = (
            "[MS, MS:1000777, spectrum identifier nativeID format, ]"
        )
        out_mztab_MTD.loc[1, "assay[" + str(i) + "]-quantification_reagent"] = "[MS, MS:1002038, unlabeled sample, ]"
        out_mztab_MTD.loc[1, "assay[" + str(i) + "]-ms_run_ref"] = "ms_run[" + str(i) + "]"

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        # This is used here in order to ignore performance warnings from pandas.
        for i in range(1, max(index_ref["study_variable"]) + 1):
            study_variable = []
            for j in list(index_ref[index_ref["study_variable"] == i]["ms_run"].values):
                study_variable.append("assay[" + str(j) + "]")
            out_mztab_MTD.loc[1, "study_variable[" + str(i) + "]-assay_refs"] = ",".join(study_variable)
            out_mztab_MTD.loc[1, "study_variable[" + str(i) + "]-description"] = "no description given"

    # The former loop makes a very sharded frame, this
    # makes the frame more compact in memory.
    out_mztab_MTD = out_mztab_MTD.copy()
    out_mztab_MTD.loc[2, :] = "MTD"

    # Transpose out_mztab_MTD
    col = list(out_mztab_MTD.columns)
    row = list(out_mztab_MTD.index)
    out_mztab_MTD_T = pd.DataFrame(out_mztab_MTD.values.T, index=col, columns=row)
    out_mztab_MTD_T.columns = ["inf", "index"]
    out_mztab_MTD_T.insert(0, "title", out_mztab_MTD_T.index)
    index = out_mztab_MTD_T.loc[:, "index"]
    out_mztab_MTD_T.drop(labels=["index"], axis=1, inplace=True)
    out_mztab_MTD_T.insert(0, "index", index)
    database = os.path.basename(fasta.split(".")[-2])

    return out_mztab_MTD_T, database


def mztab_PRH(report, pg, index_ref, database, fasta_df):
    """
    Construct PRH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param pg: Dataframe for Dia-NN protein groups matrix
    :type pg: pandas.core.frame.DataFrame
    :param index_ref: On the basis of f_table, two columns "ms_run" and "study_variable" are added for matching
    :type index_ref: pandas.core.frame.DataFrame
    :param database: Path to fasta file
    :type database: str
    :param fasta_df: A dataframe contains protein IDs, sequences and lengths
    :type fasta_df: pandas.core.frame.DataFrame
    :return: PRH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    logger.info("Constructing PRH sub-table...")
    logger.debug(
        f"Input report shape: {report.shape},"
        f" input pg shape: {pg.shape},"
        f" input index_ref shape: {index_ref.shape},"
        f" input fasta_df shape: {fasta_df.shape}"
    )
    file = list(pg.columns[5:])
    col = {}
    for i in file:
        col[i] = (
            "protein_abundance_assay[" + str(index_ref[index_ref["Run"] == _true_stem(i)]["ms_run"].values[0]) + "]"
        )

    pg.rename(columns=col, inplace=True)

    logger.debug("Classifying results type ...")
    pg["opt_global_result_type"] = "single_protein"
    pg.loc[pg["Protein.Ids"].str.contains(";"), "opt_global_result_type"] = "indistinguishable_protein_group"

    out_mztab_PRH = pg
    del pg
    out_mztab_PRH = out_mztab_PRH.drop(["Protein.Names"], axis=1)
    out_mztab_PRH.rename(
        columns={"Protein.Group": "accession", "First.Protein.Description": "description"}, inplace=True
    )
    out_mztab_PRH.loc[:, "database"] = database

    null_col = [
        "taxid",
        "species",
        "database_version",
        "search_engine",
        "opt_global_Posterior_Probability_score",
        "opt_global_nr_found_peptides",
        "opt_global_cv_PRIDE:0000303_decoy_hit",
    ]
    for i in null_col:
        out_mztab_PRH.loc[:, i] = "null"

    logger.debug("Extracting accession values (keeping first)...")
    out_mztab_PRH.loc[:, "accession"] = out_mztab_PRH.apply(lambda x: x["accession"].split(";")[0], axis=1)

    protein_details_df = out_mztab_PRH[out_mztab_PRH["opt_global_result_type"] == "indistinguishable_protein_group"]
    prh_series = protein_details_df["Protein.Ids"].str.split(";", expand=True).stack().reset_index(level=1, drop=True)
    prh_series.name = "accession"
    protein_details_df = (
        protein_details_df.drop("accession", axis=1).join(prh_series).reset_index().drop(columns="index")
    )
    if len(protein_details_df) > 0:
        logger.info(f"Found {len(protein_details_df)} indistinguishable protein groups")
        # The Following line fails if there are no indistinguishable protein groups
        protein_details_df.loc[:, "col"] = "protein_details"
        # protein_details_df = protein_details_df[-protein_details_df["accession"].str.contains("-")]
        out_mztab_PRH = pd.concat([out_mztab_PRH, protein_details_df]).reset_index(drop=True)
    else:
        logger.info("No indistinguishable protein groups found")

    logger.debug("Calculating protein coverage (bottleneck)...")
    # This is a bottleneck
    # reimplementation runs in 67s vs 137s (old) in my data
    out_mztab_PRH.loc[:, "protein_coverage"] = calculate_protein_coverages(
        report=report, out_mztab_PRH=out_mztab_PRH, fasta_df=fasta_df
    )

    logger.debug("Getting ambiguity members...")
    # IN THEORY this should be the same as
    # out_mztab_PRH["ambiguity_members"] = out_mztab_PRH["Protein.Ids"]
    # out_mztab_PRH.loc[out_mztab_PRH["opt_global_result_type"] == "single_protein", "ambiguity_members"] = "null"
    # or out_mztab_PRH.loc[out_mztab_PRH["Protein.Ids"] == out_mztab_PRH["accession"], "ambiguity_members"] = "null"
    out_mztab_PRH.loc[:, "ambiguity_members"] = out_mztab_PRH.apply(
        lambda x: x["Protein.Ids"] if x["opt_global_result_type"] == "indistinguishable_protein_group" else "null",
        axis=1,
    )

    logger.debug("Matching PRH to best search engine score...")
    score_looker = ModScoreLooker(report)
    out_mztab_PRH[["modifiedSequence", "best_search_engine_score[1]"]] = out_mztab_PRH.apply(
        lambda x: score_looker.get_score(x["Protein.Ids"]), axis=1, result_type="expand"
    )

    logger.debug("Matching PRH to modifications...")
    out_mztab_PRH.loc[:, "modifications"] = out_mztab_PRH.apply(
        lambda x: find_modification(x["modifiedSequence"]), axis=1, result_type="expand"
    )

    logger.debug("Matching PRH to protein quantification...")
    ## quantity at protein level: PG.MaxLFQ
    # This used to be a bottleneck in performance
    # This implementation drops the run time from 57s to 25ms
    protein_agg_report = (
        report[["PG.MaxLFQ", "Protein.Ids", "study_variable"]]
        .groupby(["study_variable", "Protein.Ids"])
        .agg({"PG.MaxLFQ": ["mean", "std", "sem"]})
        .reset_index()
        .pivot(columns=["study_variable"], index="Protein.Ids")
        .reset_index()
    )
    protein_agg_report.columns = ["::".join([str(s) for s in col]).strip() for col in protein_agg_report.columns.values]
    subname_mapper = {
        "Protein.Ids::::": "Protein.Ids",
        "PG.MaxLFQ::mean": "protein_abundance_study_variable",
        "PG.MaxLFQ::std": "protein_abundance_stdev_study_variable",
        "PG.MaxLFQ::sem": "protein_abundance_std_error_study_variable",
    }
    name_mapper = name_mapper_builder(subname_mapper)
    protein_agg_report.rename(columns=name_mapper, inplace=True)
    # out_mztab_PRH has columns accession and Protein.Ids; 'Q9NZJ9', 'A0A024RBG1;Q9NZJ9;Q9NZJ9-2']
    # the report table has 'Protein.Group' and 'Protein.Ids': 'Q9NZJ9', 'A0A024RBG1;Q9NZJ9;Q9NZJ9-2'
    # Oddly enough the last implementation mapped the the accession (Q9NZJ9) in the mztab
    # to the Protein.Ids (A0A024RBG1;Q9NZJ9;Q9NZJ9-2), leading to A LOT of missing values.
    out_mztab_PRH = out_mztab_PRH.merge(
        protein_agg_report, on="Protein.Ids", how="left", validate="many_to_one", copy=True
    )
    del name_mapper
    del subname_mapper
    del protein_agg_report
    # end of (former) bottleneck

    out_mztab_PRH.loc[:, "PRH"] = "PRT"
    index = out_mztab_PRH.loc[:, "PRH"]
    out_mztab_PRH.drop(["PRH", "Genes", "modifiedSequence", "Protein.Ids"], axis=1, inplace=True)
    out_mztab_PRH.insert(0, "PRH", index)
    out_mztab_PRH.fillna("null", inplace=True)
    out_mztab_PRH.loc[:, "database"] = database
    new_cols = [col for col in out_mztab_PRH.columns if not col.startswith("opt_")] + [
        col for col in out_mztab_PRH.columns if col.startswith("opt_")
    ]
    out_mztab_PRH = out_mztab_PRH[new_cols]
    return out_mztab_PRH


def mztab_PEH(
    report: pd.DataFrame, pr: pd.DataFrame, precursor_list: List[str], index_ref: pd.DataFrame, database: os.PathLike
) -> pd.DataFrame:
    """
    Construct PEH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param pr: Dataframe for Dia-NN precursors matrix
    :type pr: pandas.core.frame.DataFrame
    :param precursor_list: A list contains all precursor IDs
    :type precursor_list: list
    :param index_ref: On the basis of f_table, two columns "ms_run" and "study_variable" are added for matching
    :type index_ref: pandas.core.frame.DataFrame
    :param database: Path to fasta file
    :type database: str
    :return: PEH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    logger.info("Constructing PEH sub-table...")
    logger.debug(
        f"report.shape: {report.shape}, "
        f" pr.shape: {pr.shape},"
        f" len(precursor_list): {len(precursor_list)},"
        f" index_ref.shape: {index_ref.shape}"
    )
    out_mztab_PEH = pd.DataFrame()
    out_mztab_PEH = pr.iloc[:, 0:10]
    out_mztab_PEH.drop(
        ["Protein.Group", "Protein.Names", "First.Protein.Description", "Proteotypic"], axis=1, inplace=True
    )
    out_mztab_PEH.rename(
        columns={
            "Stripped.Sequence": "sequence",
            "Protein.Ids": "accession",
            "Modified.Sequence": "opt_global_cv_MS:1000889_peptidoform_sequence",
            "Precursor.Charge": "charge",
        },
        inplace=True,
    )

    logger.debug("Finding modifications...")
    out_mztab_PEH.loc[:, "modifications"] = out_mztab_PEH.apply(
        lambda x: find_modification(x["opt_global_cv_MS:1000889_peptidoform_sequence"]), axis=1, result_type="expand"
    )

    logger.debug("Extracting sequence...")
    out_mztab_PEH.loc[:, "opt_global_cv_MS:1000889_peptidoform_sequence"] = out_mztab_PEH.apply(
        lambda x: AASequence.fromString(x["opt_global_cv_MS:1000889_peptidoform_sequence"]).toString(), axis=1
    )

    logger.debug("Checking accession uniqueness...")
    out_mztab_PEH.loc[:, "unique"] = out_mztab_PEH.apply(
        lambda x: "0" if ";" in str(x["accession"]) else "1", axis=1, result_type="expand"
    )

    null_col = ["database_version", "search_engine", "retention_time_window", "mass_to_charge", "opt_global_feature_id"]
    for i in null_col:
        out_mztab_PEH.loc[:, i] = "null"
    out_mztab_PEH.loc[:, "opt_global_cv_MS:1002217_decoy_peptide"] = "0"

    logger.debug("Matching precursor IDs...")
    # Pre-calculating the indices and using a lookup table drops run time from
    # ~6.5s to 11ms
    precursor_indices = {k: i for i, k in enumerate(precursor_list)}
    pr_ids = out_mztab_PEH["Precursor.Id"].map(precursor_indices)
    out_mztab_PEH["pr_id"] = pr_ids
    del precursor_indices

    logger.debug("Getting scores per run")
    # This implementation is 422-700x faster than the apply-based one
    tmp = (
        report.groupby(["precursor.Index", "ms_run"])
        .agg({"Q.Value": ["min"]})
        .reset_index()
        .pivot(columns=["ms_run"], index="precursor.Index")
        .reset_index()
    )
    tmp.columns = pd.Index(["::".join([str(s) for s in col]).strip() for col in tmp.columns.values])
    subname_mapper = {
        "precursor.Index::::": "precursor.Index",
        "Q.Value::min": "search_engine_score[1]_ms_run",
    }
    name_mapper = name_mapper_builder(subname_mapper)
    tmp.rename(columns=name_mapper, inplace=True)
    out_mztab_PEH = out_mztab_PEH.merge(
        tmp.rename(columns={"precursor.Index": "pr_id"}), on="pr_id", validate="one_to_one"
    )
    del tmp
    del subname_mapper
    del name_mapper

    logger.debug("Getting peptide abundances per study variable")
    pep_study_report = per_peptide_study_report(report)
    out_mztab_PEH = out_mztab_PEH.merge(pep_study_report, on="pr_id", how="left", validate="one_to_one", copy=True)
    del pep_study_report

    logger.debug("Getting peptide properties...")
    # Re-implementing this section from apply -> assign to groupby->agg
    # speeds up the process from 11s to 25ms in my data (~440x faster)
    # Notably, this changes slightly...
    # "opt_global_q-value" was the FIRST "Global.Q.Value", now its the min
    # "opt_global_SpecEValue_score" was the FIRST "Lib.Q.Value" now its the min
    # I believe picking the first is inconsistent because no sorting is checked
    # and the first is arbitrary.

    aggtable = (
        report.groupby(["precursor.Index"])
        .agg(
            {
                "Q.Value": "min",
                "RT.Start": "mean",
                "Global.Q.Value": "min",
                "Lib.Q.Value": "min",
                "Calculate.Precursor.Mz": "mean",
            }
        )
        .reset_index()
        .rename(
            columns={
                "precursor.Index": "pr_id",
                "Q.Value": "best_search_engine_score[1]",
                "RT.Start": "retention_time",
                "Global.Q.Value": "opt_global_q-value",
                "Lib.Q.Value": "opt_global_SpecEValue_score",
                "Calculate.Precursor.Mz": "mass_to_charge",
            }
        )
    )
    del out_mztab_PEH["mass_to_charge"]
    out_mztab_PEH = out_mztab_PEH.merge(aggtable, on="pr_id", validate="one_to_one")

    logger.debug("Re-ordering columns...")
    out_mztab_PEH.loc[:, "PEH"] = "PEP"
    out_mztab_PEH.loc[:, "database"] = str(database)
    index = out_mztab_PEH.loc[:, "PEH"]
    out_mztab_PEH.drop(["PEH", "Precursor.Id", "Genes", "pr_id"], axis=1, inplace=True)
    out_mztab_PEH.insert(0, "PEH", index)
    out_mztab_PEH.fillna("null", inplace=True)
    new_cols = [col for col in out_mztab_PEH.columns if not col.startswith("opt_")] + [
        col for col in out_mztab_PEH.columns if col.startswith("opt_")
    ]
    out_mztab_PEH = out_mztab_PEH[new_cols]

    return out_mztab_PEH


def mztab_PSH(report, folder, database):
    """
    Construct PSH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param folder: DiannConvert specifies the folder where the required file resides. The folder contains
        the DiaNN main report, protein matrix, precursor matrix, experimental design file, protein sequence
        FASTA file, version file of DiaNN and ms_info TSVs
    :type folder: str
    :param database: Path to fasta file
    :type database: str
    :return: PSH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    logger.info("Constructing PSH sub-table")

    def __find_info(directory, n):
        # This line matches n="220101_myfile", folder="." to
        # "myfolder/220101_myfile_ms_info.tsv"
        files = list(Path(directory).rglob(f"{n}_ms_info.tsv"))
        # Check that it matches one and only one file
        if not files:
            raise ValueError(f"Could not find {n} info file in {directory}")
        if len(files) > 1:
            raise ValueError(f"Found multiple {n} info files in {directory}: {files}")

        return files[0]

    out_mztab_PSH = pd.DataFrame()
    for n, group in report.groupby(["Run"]):
        if isinstance(n, tuple) and len(n) == 1:
            # This is here only to support versions of pandas where the groupby
            # key is a tuple.
            # related: https://github.com/pandas-dev/pandas/pull/51817
            n = n[0]

        file = __find_info(folder, n)
        target = pd.read_csv(file, sep="\t")
        group.sort_values(by="RT.Start", inplace=True)
        target = target[["Retention_Time", "SpectrumID", "Exp_Mass_To_Charge"]]
        target.columns = ["RT.Start", "opt_global_spectrum_reference", "exp_mass_to_charge"]
        # Standardize spectrum identifier format for bruker data
        if type(target.loc[0, "opt_global_spectrum_reference"]) != str:
            target.loc[:, "opt_global_spectrum_reference"] = "scan=" + target.loc[
                :, "opt_global_spectrum_reference"
            ].astype(str)

        # TODO seconds returned from precursor.getRT()
        target.loc[:, "RT.Start"] = target.apply(lambda x: x["RT.Start"] / 60, axis=1)
        out_mztab_PSH = pd.concat([out_mztab_PSH, pd.merge_asof(group, target, on="RT.Start", direction="nearest")])
    del report

    ## Score at PSM level: Q.Value
    out_mztab_PSH = out_mztab_PSH[
        [
            "Stripped.Sequence",
            "Protein.Ids",
            "Q.Value",
            "RT.Start",
            "Precursor.Charge",
            "Calculate.Precursor.Mz",
            "exp_mass_to_charge",
            "Modified.Sequence",
            "PEP",
            "Global.Q.Value",
            "Global.Q.Value",
            "opt_global_spectrum_reference",
            "ms_run",
        ]
    ]
    out_mztab_PSH.columns = [
        "sequence",
        "accession",
        "search_engine_score[1]",
        "retention_time",
        "charge",
        "calc_mass_to_charge",
        "exp_mass_to_charge",
        "opt_global_cv_MS:1000889_peptidoform_sequence",
        "opt_global_SpecEValue_score",
        "opt_global_q-value",
        "opt_global_q-value_score",
        "opt_global_spectrum_reference",
        "ms_run",
    ]

    out_mztab_PSH.loc[:, "opt_global_cv_MS:1002217_decoy_peptide"] = "0"
    out_mztab_PSH.loc[:, "PSM_ID"] = out_mztab_PSH.index
    out_mztab_PSH.loc[:, "unique"] = out_mztab_PSH.apply(
        lambda x: "0" if ";" in str(x["accession"]) else "1", axis=1, result_type="expand"
    )
    out_mztab_PSH.loc[:, "database"] = database

    null_col = [
        "database_version",
        "search_engine",
        "pre",
        "post",
        "start",
        "end",
        "opt_global_feature_id",
        "opt_global_map_index",
    ]
    for i in null_col:
        out_mztab_PSH.loc[:, i] = "null"

    logger.info("Finding Modifications ...")
    out_mztab_PSH.loc[:, "modifications"] = out_mztab_PSH.apply(
        lambda x: find_modification(x["opt_global_cv_MS:1000889_peptidoform_sequence"]), axis=1, result_type="expand"
    )

    out_mztab_PSH.loc[:, "spectra_ref"] = out_mztab_PSH.apply(
        lambda x: "ms_run[{}]:".format(x["ms_run"]) + x["opt_global_spectrum_reference"], axis=1, result_type="expand"
    )

    out_mztab_PSH.loc[:, "opt_global_cv_MS:1000889_peptidoform_sequence"] = out_mztab_PSH.apply(
        lambda x: AASequence.fromString(x["opt_global_cv_MS:1000889_peptidoform_sequence"]).toString(),
        axis=1,
        result_type="expand",
    )

    out_mztab_PSH.loc[:, "PSH"] = "PSM"
    index = out_mztab_PSH.loc[:, "PSH"]
    out_mztab_PSH.drop(["PSH", "ms_run"], axis=1, inplace=True)
    out_mztab_PSH.insert(0, "PSH", index)
    out_mztab_PSH.fillna("null", inplace=True)
    new_cols = [col for col in out_mztab_PSH.columns if not col.startswith("opt_")] + [
        col for col in out_mztab_PSH.columns if col.startswith("opt_")
    ]
    out_mztab_PSH = out_mztab_PSH[new_cols]
    # out_mztab_PSH.to_csv("./out_psms.mztab", sep=",", index=False)

    return out_mztab_PSH


def add_info(target, index_ref):
    """
    On the basis of f_table, two columns "ms_run" and "study_variable" are added for matching.

    :param target: The value of "Run" column in f_table
    :type target: str
    :param index_ref: A dataframe on the basis of f_table
    :type index_ref: pandas.core.frame.DataFrame
    :return: A tuple contains ms_run and study_variable
    :rtype: tuple
    """
    match = index_ref[index_ref["Run"] == target]
    ms_run = match["ms_run"].values[0]
    study_variable = match["study_variable"].values[0]

    return ms_run, study_variable


def classify_result_type(target):
    """Classify proteins

    :param target: The target dataframe contains "Protein.Group" and "Protein.Ids"
    :type target: pandas.core.frame.DataFrame
    :return: A string implys protein type
    :rtype: str
    """
    if ";" in target["Protein.Ids"]:
        return "indistinguishable_protein_group"
    return "single_protein"


def match_in_report(report, target, max_, flag, level):
    """
    This function is used to match the columns "ms_run" and "study_variable" from the report and
    get the corresponding information for the mztab ms_run and study_values metadata values.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param target: The value of "pr_id" column in out_mztab_PEH(level="peptide") or the "accession" column in out_mztab_PRH(level="protein")
    :type target: str
    :param max_: max_assay or max_study_variable
    :type max_: int
    :param flag: Match the "study_variable" column(flag=1) or the "ms_run" column(flag=0) in the filter result
    :type flag: int
    :param level: "pep" or "protein"
    :type level: str
    :return: A tuple contains multiple messages
    :rtype: tuple
    """  # noqa
    if flag == 1 and level == "pep":
        result = report[report["precursor.Index"] == target]
        PEH_params = []
        for i in range(1, max_ + 1):
            match = result[result["study_variable"] == i]
            PEH_params.extend([match["Precursor.Normalised"].mean(), "null", "null", "null", match["RT.Start"].mean()])

        return tuple(PEH_params)

    if flag == 0 and level == "pep":
        result = report[report["precursor.Index"] == target]
        q_value = []
        for i in range(1, max_ + 1):
            match = result[result["ms_run"] == i]
            q_value.append(match["Q.Value"].values[0] if match["Q.Value"].values.size > 0 else np.nan)

        return tuple(q_value)

    if flag == 1 and level == "protein":
        result = report[report["Protein.Ids"] == target]
        PRH_params = []
        for i in range(1, max_ + 1):
            match = result[result["study_variable"] == i]
            PRH_params.extend([match["PG.MaxLFQ"].mean(), "null", "null"])

        return tuple(PRH_params)


class ModScoreLooker:
    """
    Class used to cache the lookup table of accessions to best scores and their
    respective mod sequences.

    Pre-computing the lookup table leverages a lot of speedum and vectortized
    operations from pandas, and is much faster than doing the lookup on the fly
    in a loop.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    """

    def __init__(self, report: pd.DataFrame) -> None:
        self.lookup_dict = self.make_lookup_dict(report)

    def make_lookup_dict(self, report) -> Dict[str, Tuple[str, float]]:
        grouped_df = (
            report[["Modified.Sequence", "Protein.Ids", "Global.PG.Q.Value"]]
            .sort_values("Global.PG.Q.Value", ascending=True)
            .groupby(["Protein.Ids"])
            .head(1)
        )
        #        Modified.Sequence               Protein.Ids  Global.PG.Q.Value
        # 78265          LFNEQNFFQR  Q8IV63;Q8IV63-2;Q8IV63-3           0.000252
        # 103585    NPTIVNFPITNVDLR           Q53GS9;Q53GS9-2           0.000252
        # 103586          NPTWKPLIR           Q7Z4Q2;Q7Z4Q2-2           0.000252
        # 103588      NPVGYPLAWQFLR           Q9NZ08;Q9NZ08-2           0.000252

        out = {
            row["Protein.Ids"]: (row["Modified.Sequence"], row["Global.PG.Q.Value"]) for _, row in grouped_df.iterrows()
        }
        return out

    def get_score(self, protein_id: str) -> Tuple[Union[str, float], float]:
        """Returns a tuple contains modified sequences and the score at protein level.

        Gets the best score and corresponding peptide for a given protein_id

        Note that protein id can be something like 'Q8IV63;Q8IV63-2;Q8IV63-3'

        Note2: This implementation also fixes a bug where the function would
        return the first peptide in the report, not the best one. (but with the
        score of the best one for that accession)

        :param protein_id: The value of "accession" column in report
        :type target: str
        :return: A tuple that contains (best modified sequence, best score)
            if the accession is not found, (np.nan, np.nan) is returned.
        :rtype: tuple
        """
        # Q: in what cases can the accession not exist in the table?
        #    or an accession not have peptides?
        val = self.lookup_dict.get(protein_id, (np.nan, np.nan))
        return val


# Pre-compiling the regex makes the next function 2x faster
# in my benchmarking - JSPP
MODIFICATION_PATTERN = re.compile(r"\((.*?)\)")


def find_modification(peptide):
    """
    Identify the modification site based on the peptide containing modifications.

    :param peptide: Sequences of peptides
    :type peptide: str
    :return: Modification sites
    :rtype: str

    Examples:
    >>> find_modification("PEPM(UNIMOD:35)IDE")
    '4-UNIMOD:35'
    >>> find_modification("SM(UNIMOD:35)EWEIRDS(UNIMOD:21)EPTIDEK")
    '2-UNIMOD:35,9-UNIMOD:21'
    """
    peptide = str(peptide)
    original_mods = MODIFICATION_PATTERN.findall(peptide)
    peptide = MODIFICATION_PATTERN.sub(".", peptide)
    position = [i for i, x in enumerate(peptide) if x == "."]
    for j in range(1, len(position)):
        position[j] -= j

    for k in range(0, len(original_mods)):
        original_mods[k] = str(position[k]) + "-" + original_mods[k].upper()

    original_mods = ",".join(str(i) for i in original_mods) if len(original_mods) > 0 else "null"

    return original_mods


def name_mapper_builder(subname_mapper):
    """Returns a function that renames the columns of the grouped table to match the ones
    in the final table.

    Examples:
        >>> mapping_dict = {
        ...     "precursor.Index::::": "pr_id",
        ...     "Precursor.Normalised::mean": "peptide_abundance_study_variable"
        ... }
        >>> name_mapper = name_mapper_builder(mapping_dict)
        >>> name_mapper("precursor.Index::::")
        "pr_id"
        >>> name_mapper("Precursor.Normalised::mean::1")
        "peptide_abundance_study_variable[1]"
    """
    num_regex = re.compile(r"(.*)::(\d+)$")

    def name_mapper(x):
        """Renames the columns of the grouped table to match the ones
        in the final table.

        Examples:
            >>> name_mapper("precursor.Index::::")
            "pr_id"
            >>> name_mapper("Precursor.Normalised::mean::1")
            "peptide_abundance_study_variable[1]"
        """
        orig_x = x
        for k, v in subname_mapper.items():
            if k in x:
                x = x.replace(k, v)
        out = num_regex.sub(r"\1[\2]", x)
        if out == orig_x:
            # This should never happen but I am adding it here
            # to prevent myself from shoting myself in the foot in the future.
            raise ValueError(f"Column name {x} not found in subname_mapper")
        return out

    return name_mapper


def per_peptide_study_report(report: pd.DataFrame) -> pd.DataFrame:
    """Summarizes the report at peptide/study level and flattens the columns.

    This function was implemented to replace an 'apply -> filter' approach.
    In my benchmarking it went from 35.23 seconds for 4 samples, 4 conditions to
    0.007 seconds.

    This implementation differs in several aspects in the output values:
    1. in the fact that it actually gets values for the m/z
    2. always returns a float, whilst the apply version returns an 'object' dtype.
    3. The original implementation, missing values had the string 'null', here they have the value np.nan.
    4. The order of the final output is different; the original orders columns by
    study variables > calculated value, this one is calculated value > study variables.

    Calculates the mean, standard deviation and std error of the precursor
    abundances, as well as the mean retention time and m/z.

    The names in the end are called "peptide" but thechnically the are at the
    precursor level. (peptide+charge combinations).

    The columns will look like this in the end:
    [
        'pr_id',
        'peptide_abundance_study_variable[1]',
        ...
        'peptide_abundance_stdev_study_variable[1]',
        ...
        'peptide_abundance_std_error_study_variable[1]',
        ...
        'opt_global_retention_time_study_variable[1]',
        ...
        'opt_global_mass_to_charge_study_variable[1]',
        ...
    ]
    """
    pep_study_grouped = (
        report.groupby(["study_variable", "precursor.Index"])
        .agg({"Precursor.Normalised": ["mean", "std", "sem"], "RT.Start": ["mean"], "Calculate.Precursor.Mz": ["mean"]})
        .reset_index()
        .pivot(columns=["study_variable"], index="precursor.Index")
        .reset_index()
    )
    pep_study_grouped.columns = pd.Index(
        ["::".join([str(s) for s in col]).strip() for col in pep_study_grouped.columns.values]
    )
    # Columns here would be like:
    # [
    #     "precursor.Index::::",
    #     "Precursor.Normalised::mean::1",
    #     "Precursor.Normalised::mean::2",
    #     "Precursor.Normalised::std::1",
    #     "Precursor.Normalised::std::2",
    #     "Precursor.Normalised::sem::1",
    #     "Precursor.Normalised::sem::2",
    #     "RT.Start::mean::1",
    #     "RT.Start::mean::2",
    # ]
    # So the right names need to be given and the table can be joined with the other one
    subname_mapper = {
        "precursor.Index::::": "pr_id",
        "Precursor.Normalised::mean": "peptide_abundance_study_variable",
        "Precursor.Normalised::std": "peptide_abundance_stdev_study_variable",
        "Precursor.Normalised::sem": "peptide_abundance_std_error_study_variable",
        "Calculate.Precursor.Mz::mean": "opt_global_mass_to_charge_study_variable",
        "RT.Start::mean": "opt_global_retention_time_study_variable",
    }
    name_mapper = name_mapper_builder(subname_mapper)

    pep_study_grouped.rename(
        columns=name_mapper,
        inplace=True,
    )

    return pep_study_grouped


def calculate_coverage(ref_sequence: str, sequences: Set[str]):
    """
    Calculates the coverage of the reference sequence by the given sequences.

    Examples:
    >>> calculate_coverage("WATEROVERTHEDUCKSBACK", {"WATER", "DUCK"})
    0.42857142857142855
    >>> calculate_coverage("DUCKDUCKDUCK", {"DUCK"})
    1.0
    >>> calculate_coverage("WATEROVERTHEDUCK", {"DUCK"})
    0.25
    >>> calculate_coverage("WATER", {"WAT", "TER"})
    1.0
    >>> calculate_coverage("WATERGLASS", {"WAT", "TER"})
    0.5
    """
    starts = []
    lengths = []
    for sequence in sequences:
        local_start = 0
        while True:
            local_start = ref_sequence.find(sequence, local_start)
            if local_start == -1:
                break
            starts.append(local_start)
            lengths.append(len(sequence))
            local_start += 1

    # merge overlapping intervals
    merged_starts: list = []
    merged_lengths: list = []
    for start, length in sorted(zip(starts, lengths)):
        if merged_starts and merged_starts[-1] + merged_lengths[-1] >= start:
            merged_lengths[-1] = max(merged_starts[-1] + merged_lengths[-1], start + length) - merged_starts[-1]
        else:
            merged_starts.append(start)
            merged_lengths.append(length)

    # calculate coverage
    coverage = sum(merged_lengths) / len(ref_sequence)
    return coverage


def calculate_protein_coverages(report: pd.DataFrame, out_mztab_PRH: pd.DataFrame, fasta_df: pd.DataFrame) -> List[str]:
    """Calculates protein coverages for the PRH table.

    The protein coverage is calculated as the fraction of the protein sequence
    in the fasta df, covered by the peptides in the report table, for every
    protein in the PRH table (defined by accession, not protein.ids).
    """
    nested_df = (
        report[["Protein.Ids", "Stripped.Sequence"]]
        .groupby("Protein.Ids")
        .agg({"Stripped.Sequence": set})
        .reset_index()
    )
    #                      Protein.Ids                                  Stripped.Sequence
    # 0     A0A024RBG1;Q9NZJ9;Q9NZJ9-2                                   {SEQEDEVLLVSSSR}
    # 1        A0A096LP49;A0A096LP49-2                                  {SPWAMTERKHSSLER}
    # 2                A0AVT1;A0AVT1-2  {EDFTLLDFINAVK, KPDHVPISSEDER, QDVIITALDNVEAR,...
    ids_to_seqs = dict(zip(nested_df["Protein.Ids"], nested_df["Stripped.Sequence"]))
    acc_to_ids = dict(zip(out_mztab_PRH["accession"], out_mztab_PRH["Protein.Ids"]))
    fasta_id_to_seqs = dict(zip(fasta_df["id"], fasta_df["seq"]))
    acc_to_fasta_ids: dict = {}

    # Since fasta ids are something like sp|P51451|BLK_HUMAN but
    # accessions are something like Q9Y6V7-2, we need to find a
    # partial string match between the two (the best one)
    for acc in acc_to_ids:
        # I am pretty sure this is the slowest part of the code
        matches = fasta_df[fasta_df["id"].str.contains(acc)]["id"]
        if len(matches) == 0:
            logger.warning(f"Could not find fasta id for accession {acc} in the fasta file.")
            acc_to_fasta_ids[acc] = None
        elif len(matches) == 1:
            acc_to_fasta_ids[acc] = matches.iloc[0]
        else:
            # If multiple, find best match. ej. Pick Q9Y6V7 over Q9Y6V7-2
            # This can be acquired by finding the shortest string, since
            # it entails more un-matched characters.
            acc_to_fasta_ids[acc] = min(matches, key=len)

    out: List[str] = [""] * len(out_mztab_PRH["accession"])

    for i, acc in enumerate(out_mztab_PRH["accession"]):
        f_id = acc_to_fasta_ids[acc]
        if f_id is None:
            out_cov = "null"
        else:
            cov = calculate_coverage(fasta_id_to_seqs[f_id], ids_to_seqs[acc_to_ids[acc]])
            out_cov = format(cov, ".03f")

        out[i] = out_cov

    return out


cli.add_command(convert)

if __name__ == "__main__":
    cli()
