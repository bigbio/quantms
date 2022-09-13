#!/usr/bin/env python

import os
import re

import click
import numpy as np
import pandas as pd
from pyopenms import AASequence, FASTAFile, ModificationsDB

CONTEXT_SETTINGS = dict(help_option_names=["-h", "--help"])


@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass


@click.command("convert")
@click.option(
    "--diann_report",
    "-r",
)
@click.option("--exp_design", "-e")
@click.option("--pg_matrix", "-pg")
@click.option("--pr_matrix", "-pr")
@click.option("--dia_params", "-p")
@click.option("--diann_version", "-v")
@click.option("--fasta", "-f")
@click.option("--charge", "-c")
@click.option("--missed_cleavages", "-m")
@click.option("--qvalue_threshold", "-q", type=float)
@click.pass_context
def convert(
    ctx,
    diann_report,
    exp_design,
    pg_matrix,
    pr_matrix,
    dia_params,
    diann_version,
    fasta,
    charge,
    missed_cleavages,
    qvalue_threshold,
):
    """This function is designed to convert the DIA-NN output into three standard formats: MSstats, Triqler and mzTab. These documents are
    used for quality control and downstream analysis.

    :param diann_report: Path to the main report output by DIA-NN
    :type diann_report: str
    :param exp_design: Path to the experimental design file
    :type exp_design: str
    :param pg_matrix: Path to a DIA-NN matrix file containing protein groups
    :type pg_matrix: str
    :param pr_matrix: Path to a DIA-NN matrix file containing precursors
    :type pr_matrix: str
    :param dia_params: A list contains DIA parameters
    :type dia_params: list
    :param diann_version: Version of DIA-NN
    :type diann_version: str
    :param fasta: Path to the fasta file
    :type fasta: str
    :param charge: The charge assigned by DIA-NN(max_precursor_charge)
    :type charge: int
    :param missed_cleavages: Allowed missed cleavages assigned by DIA-NN
    :type missed_cleavages: int
    :param qvalue_threshold: Threshold for filtering q value
    :type qvalue_threshold: float
    """
    pg = pd.read_csv(pg_matrix, sep="\t", header=0, dtype="str")
    pr = pd.read_csv(pr_matrix, sep="\t", header=0, dtype="str")
    report = pd.read_csv(diann_report, sep="\t", header=0, dtype="str")
    report["Calculate.Precursor.Mz"] = report.apply(
        lambda x: AASequence.fromString(x["Stripped.Sequence"]).getMZ(int(x["Precursor.Charge"])), axis=1
    )

    precursor_list = list(report["Precursor.Id"].unique())
    report["precursor.Index"] = report.apply(lambda x: precursor_list.index(x["Precursor.Id"]), axis=1)

    col = ["Q.Value", "Precursor.Normalised", "RT", "Global.Q.Value", "Lib.Q.Value", "PG.MaxLFQ"]
    for i in col:
        report.loc[:, i] = report.loc[:, i].astype("float")

    # filter based on qvalue parameter for downstream analysiss
    report = report[report["Q.Value"] < qvalue_threshold]

    with open(exp_design, "r") as f:
        data = f.readlines()
        empty_row = data.index("\n")
        f_table = [i.replace("\n", "").split("\t") for i in data[1:empty_row]]
        f_header = data[0].replace("\n", "").split("\t")
        f_table = pd.DataFrame(f_table, columns=f_header)
        f_table.loc[:, "run"] = f_table.apply(
            lambda x: os.path.splitext(os.path.basename(x["Spectra_Filepath"]))[0], axis=1
        )

        s_table = [i.replace("\n", "").split("\t") for i in data[empty_row + 1 :]][1:]
        s_header = data[empty_row + 1].replace("\n", "").split("\t")
        s_DataFrame = pd.DataFrame(s_table, columns=s_header)

    # Convert to MSstats
    out_msstats = pd.DataFrame()
    out_msstats = report[
        ["Protein.Names", "Modified.Sequence", "Precursor.Charge", "Precursor.Quantity", "File.Name", "Run"]
    ]
    out_msstats.columns = ["ProteinName", "PeptideSequence", "PrecursorCharge", "Intensity", "Reference", "Run"]
    out_msstats.loc[:, "PeptideSequence"] = out_msstats.apply(
        lambda x: AASequence.fromString(x["PeptideSequence"]).toString(), axis=1
    )
    out_msstats.loc[:, "FragmentIon"] = "NA"
    out_msstats.loc[:, "ProductCharge"] = "0"
    out_msstats.loc[:, "IsotopeLabelType"] = "L"
    out_msstats["Reference"] = out_msstats.apply(lambda x: os.path.basename(x["Reference"]), axis=1)

    out_msstats[["Fraction", "BioReplicate", "Condition"]] = out_msstats.apply(
        lambda x: query_expdesign_value(x["Run"], f_table, s_DataFrame), axis=1, result_type="expand"
    )

    # Convert to Triqler
    out_triqler = pd.DataFrame()
    out_triqler = out_msstats[["ProteinName", "PeptideSequence", "PrecursorCharge", "Intensity", "Run", "Condition"]]
    out_triqler.columns = ["proteins", "peptide", "charge", "intensity", "run", "condition"]

    out_triqler.loc[:, "searchScore"] = report["Q.Value"]
    out_triqler.loc[:, "searchScore"] = 1 - out_triqler["searchScore"]

    out_msstats = out_msstats[out_msstats["Intensity"] != 0]
    out_msstats.to_csv(os.path.splitext(os.path.basename(exp_design))[0] + "_msstats_in.csv", sep=",", index=False)
    out_triqler = out_triqler[out_triqler["intensity"] != 0]
    out_triqler.to_csv(os.path.splitext(os.path.basename(exp_design))[0] + "_triqler_in.tsv", sep="\t", index=False)

    # Convert to mzTab
    if diann_version == "1.8.1":
        fasta_df = pd.DataFrame()
        entries = []
        f = FASTAFile()
        f.load(fasta, entries)
        line = 0
        for e in entries:
            fasta_df.loc[line, "id"] = e.identifier
            fasta_df.loc[line, "seq"] = e.sequence
            fasta_df.loc[line, "len"] = len(e.sequence)
            line += 1

        index_ref = f_table
        index_ref.loc[:, "ms_run"] = index_ref.apply(lambda x: x["Fraction_Group"], axis=1)
        index_ref.loc[:, "study_variable"] = index_ref.apply(lambda x: x["Sample"], axis=1)
        index_ref.loc[:, "ms_run"] = index_ref.loc[:, "ms_run"].astype("int")
        index_ref.loc[:, "study_variable"] = index_ref.loc[:, "study_variable"].astype("int")
        report[["ms_run", "study_variable"]] = report.apply(
            lambda x: add_info(x["Run"], index_ref), axis=1, result_type="expand"
        )

        (MTD, database) = mztab_MTD(index_ref, dia_params, fasta, charge, missed_cleavages)
        PRH = mztab_PRH(report, pg, index_ref, database, fasta_df)
        PEH = mztab_PEH(report, pr, precursor_list, index_ref, database, fasta_df)
        PSH = mztab_PSH(report, database, fasta_df)
        MTD.loc["", :] = ""
        PRH.loc[len(PRH) + 1, :] = ""
        PEH.loc[len(PEH) + 1, :] = ""
        with open(os.path.splitext(os.path.basename(exp_design))[0] + "_out.mztab", "w", newline="") as f:
            MTD.to_csv(f, mode="w", sep="\t", index=False, header=False)
            PRH.to_csv(f, mode="w", sep="\t", index=False, header=True)
            PEH.to_csv(f, mode="w", sep="\t", index=False, header=True)
            PSH.to_csv(f, mode="w", sep="\t", index=False, header=True)


def query_expdesign_value(reference, f_table, s_table):
    """By matching the "Run" column in f_table or the "Sample" column in s_table, this function returns a tuple containing Fraction,
    BioReplicate and Condition.

     :param reference: The value of "Run" column in out_msstats
     :type reference: str
     :param f_table: A table contains experiment settings(search engine settings etc.)
     :type f_table: pandas.core.frame.DataFrame
     :param s_table: A table contains experimental design
     :type s_table: pandas.core.frame.DataFrame
     :return: A tuple contains Fraction, BioReplicate and Condition
     :rtype: tuple
    """
    query_reference = f_table[f_table["run"] == reference]
    Fraction = query_reference["Fraction"].values[0]
    row = s_table[s_table["Sample"] == query_reference["Sample"].values[0]]
    BioReplicate = row["MSstats_BioReplicate"].values[0]
    Condition = row["MSstats_Condition"].values[0]

    return Fraction, BioReplicate, Condition


def MTD_mod_info(fix_mod, var_mod):
    """Convert fixed and variable modifications to the format required by the MTD sub-table.

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
    """Construct MTD sub-table.

    :param index_ref: On the basis of f_table, two columns "MS_run" and "study_variable" are added for matching
    :type indx_ref: pandas.core.frame.DataFrame
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
    """Construct PRH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param pg: Dataframe for Dia-NN protein groups matrix
    :type pg: pandas.core.frame.DataFrame
    :param index_ref: On the basis of f_table, two columns "ms_run" and "study_variable" are added for matching
    :type indx_ref: pandas.core.frame.DataFrame
    :param database: Path to fasta file
    :type database: str
    :param fasta_df: A dataframe contains protein IDs, sequences and lengths
    :type fasta_df: pandas.core.frame.DataFrame
    :return: PRH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    file = list(pg.columns[5:])
    col = {}
    for i in file:
        col[i] = (
            "protein_abundance_assay["
            + str(index_ref[index_ref["run"] == os.path.splitext(os.path.split(i)[1])[0]]["ms_run"].values[0])
            + "]"
        )

    pg = pg.rename(columns=col)
    pg.loc[:, "opt_global_result_type"] = pg.apply(lambda x: classify_result_type(x), axis=1, result_type="expand")

    out_mztab_PRH = pd.DataFrame()
    out_mztab_PRH = pg.drop(["Protein.Names"], axis=1)
    out_mztab_PRH = out_mztab_PRH.rename(
        columns={"Protein.Group": "accession", "First.Protein.Description": "description"}
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
    out_mztab_PRH.loc[:, "accession"] = out_mztab_PRH.apply(lambda x: x["accession"].split(";")[0], axis=1)

    protein_details_df = out_mztab_PRH[out_mztab_PRH["opt_global_result_type"] == "indistinguishable_protein_group"]
    prh_series = protein_details_df["Protein.Ids"].str.split(";", expand=True).stack().reset_index(level=1, drop=True)
    prh_series.name = "accession"
    protein_details_df = (
        protein_details_df.drop("accession", axis=1).join(prh_series).reset_index().drop(columns="index")
    )
    protein_details_df.loc[:, "opt_global_result_type"] = protein_details_df.apply(lambda x: "protein_details", axis=1)
    # protein_details_df = protein_details_df[-protein_details_df["accession"].str.contains("-")]
    out_mztab_PRH = pd.concat([out_mztab_PRH, protein_details_df]).reset_index(drop=True)

    out_mztab_PRH.loc[:, "protein_coverage"] = out_mztab_PRH.apply(
        lambda x: calculate_protein_coverage(report, x["accession"], x["Protein.Ids"], fasta_df),
        axis=1,
        result_type="expand",
    )

    out_mztab_PRH.loc[:, "ambiguity_members"] = out_mztab_PRH.apply(
        lambda x: x["Protein.Ids"] if x["opt_global_result_type"] == "indistinguishable_protein_group" else "null",
        axis=1,
    )

    out_mztab_PRH[["modifiedSequence", "best_search_engine_score[1]"]] = out_mztab_PRH.apply(
        lambda x: PRH_match_report(report, x["accession"]), axis=1, result_type="expand"
    )

    out_mztab_PRH.loc[:, "modifications"] = out_mztab_PRH.apply(
        lambda x: find_modification(x["modifiedSequence"]), axis=1, result_type="expand"
    )

    ## quantity at protein level: PG.MaxLFQ
    max_study_variable = max(index_ref["study_variable"])
    PRH_params = []
    for i in range(1, max_study_variable + 1):
        PRH_params.extend(
            [
                "protein_abundance_study_variable[" + str(i) + "]",
                "protein_abundance_stdev_study_variable[" + str(i) + "]",
                "protein_abundance_std_error_study_variable[" + str(i) + "]",
            ]
        )

    out_mztab_PRH[PRH_params] = out_mztab_PRH.apply(
        lambda x: match_in_report(report, x["accession"], max_study_variable, 1, "protein"),
        axis=1,
        result_type="expand",
    )

    out_mztab_PRH = out_mztab_PRH.drop(["Genes", "modifiedSequence", "Protein.Ids"], axis=1)
    out_mztab_PRH.fillna("null", inplace=True)
    out_mztab_PRH.loc[:, "PRH"] = "PRT"
    index = out_mztab_PRH.loc[:, "PRH"]
    out_mztab_PRH.drop(labels=["PRH"], axis=1, inplace=True)
    out_mztab_PRH.insert(0, "PRH", index)
    # out_mztab_PRH.to_csv("./out_protein.mztab", sep=",", index=False)

    return out_mztab_PRH


def mztab_PEH(report, pr, precursor_list, index_ref, database, fasta_df):
    """Construct PEH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param pr: Dataframe for Dia-NN precursors matrix
    :type pr: pandas.core.frame.DataFrame
    :param precursor_list: A list contains all precursor IDs
    :type precursor_list: list
    :param index_ref: On the basis of f_table, two columns "ms_run" and "study_variable" are added for matching
    :type indx_ref: pandas.core.frame.DataFrame
    :param database: Path to fasta file
    :type database: str
    :return: PEH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    out_mztab_PEH = pd.DataFrame()
    out_mztab_PEH = pr.iloc[:, 0:10]
    out_mztab_PEH = out_mztab_PEH.drop(
        ["Protein.Group", "Protein.Names", "First.Protein.Description", "Proteotypic"], axis=1
    )
    out_mztab_PEH = out_mztab_PEH.rename(
        columns={
            "Stripped.Sequence": "sequence",
            "Protein.Ids": "accession",
            "Modified.Sequence": "opt_global_cv_MS:1000889_peptidoform_sequence",
            "Precursor.Charge": "charge",
        }
    )

    out_mztab_PEH.loc[:, "modifications"] = out_mztab_PEH.apply(
        lambda x: find_modification(x["opt_global_cv_MS:1000889_peptidoform_sequence"]), axis=1, result_type="expand"
    )

    out_mztab_PEH.loc[:, "opt_global_cv_MS:1000889_peptidoform_sequence"] = out_mztab_PEH.apply(
        lambda x: AASequence.fromString(x["opt_global_cv_MS:1000889_peptidoform_sequence"]).toString(), axis=1
    )

    out_mztab_PEH.loc[:, "unique"] = out_mztab_PEH.apply(
        lambda x: "0" if ";" in str(x["accession"]) else "1", axis=1, result_type="expand"
    )

    null_col = ["database_version", "search_engine", "retention_time_window", "mass_to_charge"]
    for i in null_col:
        out_mztab_PEH.loc[:, i] = "null"
    out_mztab_PEH.loc[:, "opt_global_cv_MS:1002217_decoy_peptide"] = "0"

    ## average value of each study_variable
    ## quantity at peptide level: Precursor.Normalised
    out_mztab_PEH.loc[:, "pr_id"] = out_mztab_PEH.apply(
        lambda x: precursor_list.index(x["Precursor.Id"]), axis=1, result_type="expand"
    )
    max_assay = max(index_ref["ms_run"])
    max_study_variable = max(index_ref["study_variable"])

    ms_run_score = []
    for i in range(1, max_assay + 1):
        ms_run_score.append("search_engine_score[1]_ms_run[" + str(i) + "]")
    out_mztab_PEH[ms_run_score] = out_mztab_PEH.apply(
        lambda x: match_in_report(report, x["pr_id"], max_assay, 0, "pep"), axis=1, result_type="expand"
    )

    PEH_params = []
    for i in range(1, max_study_variable + 1):
        PEH_params.extend(
            [
                "peptide_abundance_study_variable[" + str(i) + "]",
                "peptide_abundance_stdev_study_variable[" + str(i) + "]",
                "peptide_abundance_std_error_study_variable[" + str(i) + "]",
                "opt_global_mass_to_charge_study_variable[" + str(i) + "]",
                "opt_global_retention_time_study_variable[" + str(i) + "]",
            ]
        )
    out_mztab_PEH[PEH_params] = out_mztab_PEH.apply(
        lambda x: match_in_report(report, x["pr_id"], max_study_variable, 1, "pep"), axis=1, result_type="expand"
    )

    out_mztab_PEH[
        [
            "best_search_engine_score[1]",
            "retention_time",
            "opt_global_q-value",
            "opt_global_SpecEValue_score",
            "mass_to_charge",
        ]
    ] = out_mztab_PEH.apply(lambda x: PEH_match_report(report, x["pr_id"]), axis=1, result_type="expand")

    out_mztab_PEH[["opt_global_feature_id", "spectra_ref"]] = out_mztab_PEH.apply(
        lambda x: ("null", "null"), axis=1, result_type="expand"
    )
    out_mztab_PEH = out_mztab_PEH.drop(["Precursor.Id", "Genes", "pr_id"], axis=1)
    out_mztab_PEH.fillna("null", inplace=True)
    out_mztab_PEH.loc[:, "PEH"] = "PEP"
    index = out_mztab_PEH.loc[:, "PEH"]
    out_mztab_PEH.drop(labels=["PEH"], axis=1, inplace=True)
    out_mztab_PEH.insert(0, "PEH", index)
    out_mztab_PEH.loc[:, "database"] = database
    # out_mztab_PEH.to_csv("./out_peptide.mztab", sep=",", index=False)

    return out_mztab_PEH


def mztab_PSH(report, database, fasta_df):
    """Construct PSH sub-table.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param database: Path to fasta file
    :type database: str
    :return: PSH sub-table
    :rtype: pandas.core.frame.DataFrame
    """
    out_mztab_PSH = pd.DataFrame()
    ## Score at PSM level: Q.Value
    out_mztab_PSH = report[
        [
            "Stripped.Sequence",
            "Protein.Ids",
            "Genes",
            "Q.Value",
            "RT",
            "Precursor.Charge",
            "Calculate.Precursor.Mz",
            "Modified.Sequence",
            "PEP",
            "Global.Q.Value",
            "Global.Q.Value",
        ]
    ]
    out_mztab_PSH.columns = [
        "sequence",
        "accession",
        "Genes",
        "search_engine_score[1]",
        "retention_time",
        "charge",
        "calc_mass_to_charge",
        "opt_global_cv_MS:1000889_peptidoform_sequence",
        "opt_global_SpecEValue_score",
        "opt_global_q-value",
        "opt_global_q-value_score",
    ]

    out_mztab_PSH.loc[:, "opt_global_cv_MS:1002217_decoy_peptide"] = "0"
    out_mztab_PSH.loc[:, "PSM_ID"] = out_mztab_PSH.index
    out_mztab_PSH.loc[:, "unique"] = out_mztab_PSH.apply(
        lambda x: "0" if ";" in str(x["accession"]) else "1", axis=1, result_type="expand"
    )
    out_mztab_PSH.loc[:, "database"] = database

    null_col = [
        "database_version",
        "spectra_ref",
        "search_engine",
        "unique",
        "exp_mass_to_charge",
        "pre",
        "post",
        "start",
        "end",
        "opt_global_feature_id",
        "opt_global_map_index",
        "opt_global_spectrum_reference",
    ]
    for i in null_col:
        out_mztab_PSH.loc[:, i] = "null"

    out_mztab_PSH.loc[:, "modifications"] = out_mztab_PSH.apply(
        lambda x: find_modification(x["opt_global_cv_MS:1000889_peptidoform_sequence"]), axis=1, result_type="expand"
    )

    out_mztab_PSH.loc[:, "opt_global_cv_MS:1000889_peptidoform_sequence"] = out_mztab_PSH.apply(
        lambda x: AASequence.fromString(x["opt_global_cv_MS:1000889_peptidoform_sequence"]).toString(),
        axis=1,
        result_type="expand",
    )

    out_mztab_PSH = out_mztab_PSH.drop(["Genes"], axis=1)
    out_mztab_PSH.fillna("null", inplace=True)
    out_mztab_PSH.loc[:, "PSH"] = "PSM"
    index = out_mztab_PSH.loc[:, "PSH"]
    out_mztab_PSH.drop(labels=["PSH"], axis=1, inplace=True)
    out_mztab_PSH.insert(0, "PSH", index)
    # out_mztab_PSH.to_csv("./out_psms.mztab", sep=",", index=False)

    return out_mztab_PSH


def add_info(target, index_ref):
    """On the basis of f_table, two columns "ms_run" and "study_variable" are added for matching.

    :param target: The value of "Run" column in f_table
    :type target: str
    :param index_ref: A dataframe on the basis of f_table
    :type indx_ref: pandas.core.frame.DataFrame
    :return: A tuple contains ms_run and study_variable
    :rtype: tuple
    """
    match = index_ref[index_ref["run"] == target]
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
    else:
        return "single_protein"


def calculate_protein_coverage(report, target, reference, fasta_df):
    """Calculate protein coverage.
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
    l, r = 0, 1
    while r < len(resultlist):
        x1, y1 = resultlist[l][0], resultlist[l][1]
        x2, y2 = resultlist[r][0], resultlist[r][1]
        if x2 > y1:
            l += 1
            r += 1
        else:
            resultlist[l] = [x1, max(y1, y2)]
            resultlist.pop(r)

    coverage_length = np.array([i[1] - i[0] + 1 for i in resultlist]).sum()
    protein_coverage = format(coverage_length / len(ref), ".3f")

    return protein_coverage


def match_in_report(report, target, max, flag, level):
    """This function is used to match the columns "ms_run" and "study_variable" in the report to get the information.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param target: The value of "pr_id" column in out_mztab_PEH(level="peptide") or the "accession" column in out_mztab_PRH(level="protein")
    :type target: str
    :param max: max_assay or max_study_variable
    :type max: int
    :param flag: Match the "study_variable" column(flag=1) or the "ms_run" column(flag=0) in the filter result
    :type flag: int
    :param level: "pep" or "protein"
    :type level: str
    :return: A tuple contains multiple messages
    :rtype: tuple
    """
    if flag == 1 and level == "pep":
        result = report[report["precursor.Index"] == target]
        PEH_params = []
        for i in range(1, max + 1):
            match = result[result["study_variable"] == i]
            PEH_params.extend([match["Precursor.Normalised"].mean(), "null", "null", "null", match["RT"].mean()])

        return tuple(PEH_params)

    elif flag == 0 and level == "pep":
        result = report[report["precursor.Index"] == target]
        q_value = []
        for i in range(1, max + 1):
            match = result[result["ms_run"] == i]
            q_value.append(match["Q.Value"].values[0] if match["Q.Value"].values.size > 0 else np.nan)

        return tuple(q_value)

    elif flag == 1 and level == "protein":
        result = report[report["Protein.Ids"] == target]
        PRH_params = []
        for i in range(1, max + 1):
            match = result[result["study_variable"] == i]
            PRH_params.extend([match["PG.MaxLFQ"].mean(), "null", "null"])

        return tuple(PRH_params)


def PRH_match_report(report, target):
    """Returns a tuple contains modified sequences and the score at protein level.

    :param report: Dataframe for Dia-NN main report
    :type report: pandas.core.frame.DataFrame
    :param target: The value of "accession" column in report
    :type target: str
    :return: A tuple contains multiple information to construct PRH sub-table
    :rtype: tuple
    """
    match = report[report["Protein.Ids"] == target]
    modSeq = match["Modified.Sequence"].values[0] if match["Modified.Sequence"].values.size > 0 else np.nan
    ## Score at protein level: Global.PG.Q.Value (without MBR)
    score = match["Global.PG.Q.Value"].min()

    return modSeq, score


def PEH_match_report(report, target):
    """Returns a tuple contains the score at peptide level, retain time, q_score, spec_e and mz.

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
    time = match["RT"].mean()
    q_score = match["Global.Q.Value"].values[0] if match["Global.Q.Value"].values.size > 0 else np.nan
    spec_e = match["Lib.Q.Value"].values[0] if match["Lib.Q.Value"].values.size > 0 else np.nan
    mz = match["Calculate.Precursor.Mz"].mean()

    return search_score, time, q_score, spec_e, mz


def find_modification(peptide):
    """Identify the modification site based on the peptide containing modifications.

    :param peptide: Sequences of peptides
    :type peptide: str
    :return: Modification sites
    :rtype: str
    """
    peptide = str(peptide)
    pattern = re.compile(r"\((.*?)\)")
    original_mods = re.findall(pattern, peptide)
    peptide = re.sub(r"\(.*?\)", ".", peptide)
    position = [i.start() for i in re.finditer(r"\.", peptide)]
    for j in range(1, len(position)):
        position[j] -= j

    for k in range(0, len(original_mods)):
        original_mods[k] = str(position[k]) + "-" + original_mods[k].upper()

    original_mods = ",".join(str(i) for i in original_mods) if len(original_mods) > 0 else "null"

    return original_mods


cli.add_command(convert)

if __name__ == "__main__":
    cli()
