#!/usr/bin/env python

import pandas as pd
import click
import os
import re

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])
@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass

@click.command('convert_msstats')
@click.option("--diann_report", "-r",)
@click.option("--exp_design", "-e")
@click.option("--unimod_csv", "-u")
@click.pass_context
def convert_msstats(ctx, diann_report, exp_design, unimod_csv):
    report = pd.read_csv(diann_report, sep = "\t", header = 0, dtype = 'str')
    unimod_data = pd.read_csv(unimod_csv, sep = ",", header = 0, dtype = 'str')
    with open(exp_design, 'r') as f:
        data = f.readlines()
        empty_row = data.index('\n')
        f_table = [i.replace("\n", '').split("\t") for i in data[1:empty_row]]
        f_header = data[0].replace("\n", "").split("\t")
        f_table = pd.DataFrame(f_table, columns=f_header)
        f_table.loc[:,"run"] = f_table.apply(lambda x: os.path.basename(x["Spectra_Filepath"].split(".")[-2]), axis=1)

        s_table = [i.replace("\n", '').split("\t") for i in data[empty_row + 1:]][1:]
        s_header = data[empty_row + 1].replace("\n", "").split("\t")
        s_DataFrame = pd.DataFrame(s_table, columns=s_header)

    out_msstats = pd.DataFrame()
    out_msstats = report[['Protein.Names', 'Modified.Sequence', 'Precursor.Charge', 'Precursor.Quantity', 'Run']]
    out_msstats.columns = ['ProteinName', 'PeptideSequence', 'PrecursorCharge', 'Intensity', 'Reference']
    out_msstats.loc[:,"PeptideSequence"] = out_msstats.apply(lambda x: convert_modification(x["PeptideSequence"], unimod_data), axis=1)
    out_msstats.loc[:,"FragmentIon"] = 'NA'
    out_msstats.loc[:,"ProductCharge"] = '0'
    out_msstats.loc[:,"IsotopeLabelType"] = "L"
    out_msstats.loc[:,"Run"] = out_msstats["Reference"]

    out_msstats[["Fraction", "BioReplicate", "Condition"]] = out_msstats.apply(lambda x: query_expdesign_value(x["Reference"], f_table, s_DataFrame),
                                                axis=1, result_type="expand")
    out_msstats = out_msstats[out_msstats["Intensity"] != 0]

    out_msstats.to_csv('./out_msstats.csv', sep=',', index=False)

def query_expdesign_value(reference, f_table, s_table):
    query_reference = f_table[f_table["run"] == reference]
    Fraction = query_reference["Fraction"].values[0]
    row = s_table[s_table["Sample"] == query_reference['Sample'].values[0]]
    BioReplicate = row["MSstats_BioReplicate"].values[0]
    Condition = row["MSstats_Condition"].values[0]

    return Fraction, BioReplicate, Condition


def convert_modification(peptide, unimod_data):
    pattern = re.compile(r"\((.*?)\)")
    origianl_mods = re.findall(pattern, peptide)
    for mod in set(origianl_mods):
        name = unimod_data[unimod_data["id"] == mod]["name"].values[0]
        peptide = peptide.replace(mod, name)
    if peptide.startswith("("):
        peptide = peptide + "."
    return peptide


cli.add_command(convert_msstats)

if __name__ == "__main__":
    cli()
