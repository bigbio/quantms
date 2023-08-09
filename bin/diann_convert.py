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
from dataclasses import dataclass
from pathlib import Path
from typing import Any, List, Tuple, Dict
from functools import lru_cache

import click
import numpy as np
import pandas as pd
from pyopenms import AASequence, FASTAFile, ModificationsDB

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 500)
pd.set_option("display.width", 1000)

CONTEXT_SETTINGS = dict(help_option_names=["-h", "--help"])

logging.basicConfig(format="%(asctime)s - %(message)s", level=logging.DEBUG)
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
     The output formats are
    used for quality control and downstream analysis.

    :param folder: DiannConvert specifies the folder where the required file resides. The folder contains
        the DiaNN main report, protein matrix, precursor matrix, experimental design file, protein sequence
        FASTA file, version file of DiaNN and mzml_info TSVs
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

    out_msstats = report[msstats_columns_keep]
    out_msstats.columns = ["ProteinName", "PeptideSequence", "PrecursorCharge", "Intensity", "Reference", "Run"]
    out_msstats = out_msstats[out_msstats["Intensity"] != 0]
    out_msstats.loc[:, "PeptideSequence"] = out_msstats.apply(
        lambda x: AASequence.fromString(x["PeptideSequence"]).toString(), axis=1
    )
    out_msstats.loc[:, "FragmentIon"] = "NA"
    out_msstats.loc[:, "ProductCharge"] = "0"
    out_msstats.loc[:, "IsotopeLabelType"] = "L"
    out_msstats["Reference"] = out_msstats.apply(lambda x: os.path.basename(x["Reference"]), axis=1)

    # TODO remove this if not debugging
    logger.debug("\n\nReference Column >>>")
    logger.debug(out_msstats["Reference"])

    logger.debug(f"\n\nout_msstats ({out_msstats.shape}) >>>")
    logger.debug(out_msstats.head(5))

    logger.debug(f"\n\nf_table ({f_table.shape})>>>")
    logger.debug(f_table.head(5))

    logger.debug(f"\n\ns_DataFrame ({s_DataFrame.shape})>>>")
    logger.debug(s_DataFrame.head(5))
    ## END TODO

    logger.debug("Adding Fraction, BioReplicate, Condition columns")
    design_looker = ExpDesignLooker(f_table=f_table, s_table=s_DataFrame)
    out_msstats[["Fraction", "BioReplicate", "Condition"]] = out_msstats.apply(
        lambda x: design_looker.query_expdesign_value(x["Run"]), axis=1, result_type="expand"
    )
    del design_looker
    exp_out_prefix = str(Path(exp_design).stem)
    out_msstats.to_csv(exp_out_prefix + "_msstats_in.csv", sep=",", index=False)
    logger.info(f"MSstats input file is saved as {exp_out_prefix}_msstats_in.csv")

    # Convert to Triqler
    trinqler_cols = ["ProteinName", "PeptideSequence", "PrecursorCharge", "Intensity", "Run", "Condition"]
    out_triqler = out_msstats[trinqler_cols]
    del out_msstats
    out_triqler.columns = ["proteins", "peptide", "charge", "intensity", "run", "condition"]
    out_triqler = out_triqler[out_triqler["intensity"] != 0]

    out_triqler.loc[:, "searchScore"] = report["Q.Value"]
    out_triqler.loc[:, "searchScore"] = 1 - out_triqler["searchScore"]
    out_triqler.to_csv(exp_out_prefix + "_triqler_in.tsv", sep="\t", index=False)
    logger.info(f"Triqler input file is saved as {exp_out_prefix}_triqler_in.tsv")
    del out_triqler

    mztab_out = f"{str(Path(exp_design).stem)}_out.mzTab"
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


@dataclass
class DiannDirectory:
    base_path: os.PathLike
    diann_version_file: str

    def __post_init__(self):
        self.base_path = Path(self.base_path)
        if not self.base_path.exists() and not self.base_path.is_dir():
            raise NotADirectoryError(f"Path {self.base_path} does not exist")
        self.diann_version_file = Path(self.diann_version_file)
        if not self.diann_version_file.is_file():
            raise FileNotFoundError(f"Path {self.diann_version_file} does not exist")

    def find_suffix_file(self, suffix: str, only_first=True) -> os.PathLike:
        """Finds a file with a given suffix in the directory.

        :param suffix: The suffix to search for
        :type suffix: str
        :param only_first: Whether to return only the first file found, if false returns all, defaults to True
        :type only_first: bool, optional

        :raises FileNotFoundError: If no file with the given suffix is found
        """
        matching = self.base_path.glob(f"**/*{suffix}")
        if only_first:
            try:
                return next(matching)
            except StopIteration:
                raise FileNotFoundError(f"Could not find file with suffix {suffix}")
        else:
            out = list(matching)
            if len(out) == 0:
                raise FileNotFoundError(f"Could not find file with suffix {suffix}")
            else:
                return out

    @property
    def report(self) -> os.PathLike:
        return self.find_suffix_file("report.tsv")

    @property
    def pg_matrix(self) -> os.PathLike:
        return self.find_suffix_file("pg_matrix.tsv")

    @property
    def pr_matrix(self) -> os.PathLike:
        return self.find_suffix_file("pr_matrix.tsv")

    @property
    def fasta(self) -> os.PathLike:
        try:
            return self.find_suffix_file(".fasta")
        except FileNotFoundError:
            return self.find_suffix_file(".fa")

    @property
    def mzml_info(self) -> os.PathLike:
        return self.find_suffix_file("mzml_info.tsv")

    @property
    def validate_diann_version(self) -> str:
        logger.debug("Validating DIANN version")
        diann_version_id = None
        with open(self.diann_version_file) as f:
            for line in f:
                if "DIA-NN" in line:
                    logger.debug(f"Found DIA-NN version: {line}")
                    diann_version_id = line.rstrip("\n").split(": ")[1]

        if diann_version_id is None:
            raise ValueError(f"Could not find DIA-NN version in file {self.diann_version_file}")
        elif diann_version_id == "1.8.1":
            return diann_version_id
        else:
            # Maybe this error should be detected beforehand to save time ...
            raise ValueError(f"Unsupported DIANN version {self.diann_version}")

    def convert_to_mztab(
        self, report, f_table, charge: int, missed_cleavages: int, dia_params: List[Any], out: os.PathLike
    ) -> None:
        logger.info("Converting to mzTab")
        # Convert to mzTab
        self.validate_diann_version

        # This could be a branching point if we want to support other versions
        # of DIA-NN, maybe something like this:
        # if diann_version_id == "1.8.1":
        #     self.convert_to_mztab_1_8_1(report, f_table, charge, missed_cleavages, dia_params)
        # else:
        #     raise ValueError(f"Unsupported DIANN version {diann_version_id}, supported versions are 1.8.1 ...")

        logger.info(f"Reading fasta file: {self.fasta}")
        entries = []
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

        (MTD, database) = mztab_MTD(index_ref, dia_params, str(self.fasta), charge, missed_cleavages)
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
        report = report[report["Q.Value"] < qvalue_threshold]
        report["Calculate.Precursor.Mz"] = report.apply(
            lambda x: calculate_mz(x["Stripped.Sequence"], x["Precursor.Charge"]), axis=1
        )

        precursor_list = list(report["Precursor.Id"].unique())
        report["precursor.Index"] = report.apply(lambda x: precursor_list.index(x["Precursor.Id"]), axis=1)
        return report


@dataclass
class ExpDesignLooker:
    """Caches the lookup of values in the experimetal design table."""

    f_table: pd.DataFrame
    s_table: pd.DataFrame

    def __hash__(self):
        # This is not a perfect hash function but it will work
        # for our use case, since we are not going to change
        # the content of f_table and s_table

        # I am using this over a strict hash for performance reasons
        # since the hash is calculated every time a method with cache
        # is called.
        hash_v = hash(self.f_table.values.shape) + hash(self.s_table.values.shape)
        return hash_v

    @lru_cache(maxsize=128)
    def query_expdesign_value(self, reference):
        """
        By matching the "Run" column in f_table or the "Sample" column in s_table, this function
        returns a tuple containing Fraction, BioReplicate and Condition.

        :param reference: The value of "Run" column in out_msstats
        :type reference: str
        :param f_table: A table contains experiment settings(search engine settings etc.)
        :type f_table: pandas.core.frame.DataFrame
        :param s_table: A table contains experimental design
        :type s_table: pandas.core.frame.DataFrame
        :return: A tuple contains Fraction, BioReplicate and Condition
        :rtype: tuple
        """
        f_table = self.f_table
        s_table = self.s_table
        if reference not in f_table["run"].values:
            raise ValueError(f"Reference {reference} not found in f_table;" f" values are {set(f_table['run'].values)}")

        query_reference = f_table[f_table["run"] == reference]
        Fraction = query_reference["Fraction"].values[0]
        row = s_table[s_table["Sample"] == query_reference["Sample"].values[0]]
        BioReplicate = row["MSstats_BioReplicate"].values[0]
        Condition = row["MSstats_Condition"].values[0]

        return Fraction, BioReplicate, Condition


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
    out_mztab_MTD.loc[
        1, "peptide_search_engine_score[1]"
    ] = "[, , DIA-NN Q.Value (minimum of the respective precursor q-values), ]"
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
        out_mztab_MTD.loc[
            1, "ms_run[" + str(i) + "]-id_format"
        ] = "[MS, MS:1000777, spectrum identifier nativeID format, ]"
        out_mztab_MTD.loc[1, "assay[" + str(i) + "]-quantification_reagent"] = "[MS, MS:1002038, unlabeled sample, ]"
        out_mztab_MTD.loc[1, "assay[" + str(i) + "]-ms_run_ref"] = "ms_run[" + str(i) + "]"

    for i in range(1, max(index_ref["study_variable"]) + 1):
        study_variable = []
        for j in list(index_ref[index_ref["study_variable"] == i]["ms_run"].values):
            study_variable.append("assay[" + str(j) + "]")
        out_mztab_MTD.loc[1, "study_variable[" + str(i) + "]-assay_refs"] = ",".join(study_variable)
        out_mztab_MTD.loc[1, "study_variable[" + str(i) + "]-description"] = "no description given"

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
    file = list(pg.columns[5:])
    col = {}
    for i in file:
        col[i] = (
            "protein_abundance_assay[" + str(index_ref[index_ref["Run"] == _true_stem(i)]["ms_run"].values[0]) + "]"
        )

    pg.rename(columns=col, inplace=True)

    logger.debug("Classifying results type ...")
    pg.loc[:, "opt_global_result_type"] = pg.apply(classify_result_type, axis=1, result_type="expand")

    out_mztab_PRH = pd.DataFrame()
    out_mztab_PRH = pg.drop(["Protein.Names"], axis=1)
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
    # Q: how is the next line different from `df.loc[:, "col"] = 'protein_details'` ??
    protein_details_df.loc[:, "opt_global_result_type"] = protein_details_df.apply(lambda x: "protein_details", axis=1)
    # protein_details_df = protein_details_df[-protein_details_df["accession"].str.contains("-")]
    out_mztab_PRH = pd.concat([out_mztab_PRH, protein_details_df]).reset_index(drop=True)

    logger.debug("Calculating protein coverage (bottleneck)...")
    # This is a bottleneck
    out_mztab_PRH.loc[:, "protein_coverage"] = out_mztab_PRH.apply(
        lambda x: calculate_protein_coverage(report, x["accession"], x["Protein.Ids"], fasta_df),
        axis=1,
        result_type="expand",
    )

    logger.debug("Getting ambiguity members...")
    out_mztab_PRH.loc[:, "ambiguity_members"] = out_mztab_PRH.apply(
        lambda x: x["Protein.Ids"] if x["opt_global_result_type"] == "indistinguishable_protein_group" else "null",
        axis=1,
    )

    logger.debug("Matching PRH to best search engine score...")
    score_looker = ModScoreLooker(report)
    out_mztab_PRH[["modifiedSequence", "best_search_engine_score[1]"]] = out_mztab_PRH.apply(
        lambda x: score_looker.get_score(x["accession"]), axis=1, result_type="expand"
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


def mztab_PEH(report, pr, precursor_list, index_ref, database):
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

    logger.debug("Matching precursor IDs... (botleneck)")
    ## average value of each study_variable
    ## quantity at peptide level: Precursor.Normalised
    out_mztab_PEH.loc[:, "pr_id"] = out_mztab_PEH.apply(
        lambda x: precursor_list.index(x["Precursor.Id"]), axis=1, result_type="expand"
    )
    logger.debug("Done Matching precursor IDs...")
    max_assay = max(index_ref["ms_run"])
    max_study_variable = max(index_ref["study_variable"])

    logger.debug("Getting scores per run (bottleneck)")
    ms_run_score = []
    for i in range(1, max_assay + 1):
        ms_run_score.append("search_engine_score[1]_ms_run[" + str(i) + "]")

    out_mztab_PEH[ms_run_score] = out_mztab_PEH.apply(
        lambda x: match_in_report(report, x["pr_id"], max_assay, 0, "pep"), axis=1, result_type="expand"
    )

    logger.debug("Getting peptide abundances per study variable")
    pep_study_report = per_peptide_study_report(report)
    out_mztab_PEH = out_mztab_PEH.merge(pep_study_report, on="pr_id", how="left", validate="one_to_one", copy=True)
    del pep_study_report

    logger.debug("Getting peptide properties")
    out_mztab_PEH[
        [
            "best_search_engine_score[1]",
            "retention_time",
            "opt_global_q-value",
            "opt_global_SpecEValue_score",
            "mass_to_charge",
        ]
    ] = out_mztab_PEH.apply(lambda x: PEH_match_report(report, x["pr_id"]), axis=1, result_type="expand")

    out_mztab_PEH.loc[:, "PEH"] = "PEP"
    out_mztab_PEH.loc[:, "database"] = database
    index = out_mztab_PEH.loc[:, "PEH"]
    out_mztab_PEH.drop(["PEH", "Precursor.Id", "Genes", "pr_id"], axis=1, inplace=True)
    out_mztab_PEH.insert(0, "PEH", index)
    out_mztab_PEH.fillna("null", inplace=True)
    new_cols = [col for col in out_mztab_PEH.columns if not col.startswith("opt_")] + [
        col for col in out_mztab_PEH.columns if col.startswith("opt_")
    ]
    out_mztab_PEH = out_mztab_PEH[new_cols]
    # out_mztab_PEH.to_csv("./out_peptide.mztab", sep=",", index=False)

    return out_mztab_PEH


def mztab_PSH(report, folder, database):
    """
    Construct PSH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param folder: DiannConvert specifies the folder where the required file resides. The folder contains
        the DiaNN main report, protein matrix, precursor matrix, experimental design file, protein sequence
        FASTA file, version file of DiaNN and mzml_info TSVs
    :type folder: str
    :param database: Path to fasta file
    :type database: str
    :return: PSH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    logger.info("Constructing PSH sub-table")

    def __find_info(dir, n):
        # This line matches n="220101_myfile", folder="." to
        # "myfolder/220101_myfile_mzml_info.tsv"
        files = list(Path(dir).glob(f"*{n}*_info.tsv"))
        # Check that it matches one and only one file
        if not files:
            raise ValueError(f"Could not find {n} info file in {dir}")
        if len(files) > 1:
            raise ValueError(f"Found multiple {n} info files in {dir}: {files}")

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


def calculate_protein_coverage(report, target, reference, fasta_df):
    """
    Calculate protein coverage.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param target: The value of "accession" column in out_mztab_PRH
    :type target: str
    :param fasta_df: A dataframe contains protein IDs, sequences and lengths
    :type fasta_df: pandas.core.frame.DataFrame
    :return: Protein coverage
    :rtype: str
    """
    peptide_list = report[report["Protein.Ids"] == reference]["Stripped.Sequence"].drop_duplicates().values
    unique_peptides = [j for i, j in enumerate(peptide_list) if all(j not in k for k in peptide_list[i + 1 :])]
    resultlist = []
    ref = fasta_df[fasta_df["id"].str.contains(target)]["seq"].values[0]

    def findstr(basestr, s, resultlist):
        result = re.finditer(s, basestr)
        if result:
            for i in result:
                resultlist.append([i.span()[0], i.span()[1] - 1])

        return resultlist

    for i in unique_peptides:
        resultlist = findstr(ref, i, resultlist)
    # Sort and merge the interval list
    resultlist.sort()
    left, right = 0, 1
    while right < len(resultlist):
        x1, y1 = resultlist[left][0], resultlist[left][1]
        x2, y2 = resultlist[right][0], resultlist[right][1]
        if x2 > y1:
            left += 1
            right += 1
        else:
            resultlist[left] = [x1, max(y1, y2)]
            resultlist.pop(right)

    coverage_length = np.array([i[1] - i[0] + 1 for i in resultlist]).sum()
    protein_coverage = format(coverage_length / len(ref), ".3f")

    return protein_coverage


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
            row["Protein.Ids"]: (row["Global.PG.Q.Value"], row["Modified.Sequence"]) for _, row in grouped_df.iterrows()
        }
        return out

    def get_score(self, protein_id: str) -> float:
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


def PEH_match_report(report, target):
    """
    Returns a tuple contains the score at peptide level, retain time, q_score, spec_e and mz.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param target: The value of "pr_id" column in report
    :type target: str
    :return: A tuple contains multiple information to construct PEH sub-table
    :rtype: tuple
    """
    match = report[report["precursor.Index"] == target]
    ## Score at peptide level: the minimum of the respective precursor q-values (minimum of Q.Value per group)
    search_score = match["Q.Value"].min()
    time = match["RT.Start"].mean()
    q_score = match["Global.Q.Value"].values[0] if match["Global.Q.Value"].values.size > 0 else np.nan
    spec_e = match["Lib.Q.Value"].values[0] if match["Lib.Q.Value"].values.size > 0 else np.nan
    mz = match["Calculate.Precursor.Mz"].mean()

    return search_score, time, q_score, spec_e, mz


# Pre-compiling the regex makes the next function 2x faster
# in myu benchmarking - JSPP
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


def calculate_mz(seq, charge):
    """
    Calculate the precursor m/z based on the peptide sequence and charge state.

    :param seq: Peptide sequence
    :type seq: str
    :param charge: charge state
    :type charge: int
    :return:
    """
    # Q: is this faster if we make it a set? and maybe make it a global variable?
    ref = "ARNDBCEQZGHILKMFPSTWYV"

    # Q: Does this mean that all modified peptides will have a wrong m/z?
    seq = "".join([i for i in seq if i in ref])
    if charge == "":
        return None
    else:
        return AASequence.fromString(seq).getMZ(int(charge))


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
    3. The original implementation, missing values had the string 'null', here
       they have the value np.nan.
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
    pep_study_grouped.columns = ["::".join([str(s) for s in col]).strip() for col in pep_study_grouped.columns.values]
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


cli.add_command(convert)

if __name__ == "__main__":
    cli()
