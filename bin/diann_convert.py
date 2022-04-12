#!/usr/bin/env python

import pandas as pd
import click
import os
import re
from sdrf_pipelines.openms.unimod import UnimodDatabase

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])
@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass

@click.command('convert')
@click.option("--diann_report", "-r",)
@click.option("--exp_design", "-e")
@click.pass_context
def convert(ctx, diann_report, exp_design):
    # Convert to MSstats
    report = pd.read_csv(diann_report, sep = "\t", header = 0)
    unimod_data = UnimodDatabase()
    with open(exp_design, 'r') as f:
        data = f.readlines()
        empty_row = data.index('\n')
        f_table = [i.replace("\n", '').split("\t") for i in data[1:empty_row]]
        f_header = data[0].replace("\n", "").split("\t")
        f_table = pd.DataFrame(f_table, columns=f_header)
        f_table.loc[:,"run"] = f_table.apply(lambda x: os.path.basename(x["Spectra_Filepath"]), axis=1)

        s_table = [i.replace("\n", '').split("\t") for i in data[empty_row + 1:]][1:]
        s_header = data[empty_row + 1].replace("\n", "").split("\t")
        s_DataFrame = pd.DataFrame(s_table, columns=s_header)

    out_msstats = pd.DataFrame()
    out_msstats = report[['Protein.Names', 'Modified.Sequence', 'Precursor.Charge', 'Precursor.Quantity', 'File.Name','Run']]
    out_msstats.columns = ['ProteinName', 'PeptideSequence', 'PrecursorCharge', 'Intensity', 'Reference', 'Run']
    out_msstats.loc[:,"PeptideSequence"] = out_msstats.apply(lambda x: convert_modification(x["PeptideSequence"], unimod_data), axis=1)
    out_msstats.loc[:,"FragmentIon"] = 'NA'
    out_msstats.loc[:,"ProductCharge"] = '0'
    out_msstats.loc[:,"IsotopeLabelType"] = "L"
    out_msstats["Reference"] = out_msstats.apply(lambda x: os.path.basename(x['Reference']), axis=1)

    out_msstats[["Fraction", "BioReplicate", "Condition"]] = out_msstats.apply(lambda x: query_expdesign_value(x["Reference"], f_table, s_DataFrame),
                                                axis=1, result_type="expand")

    # Convert to Triqler
    out_triqler = pd.DataFrame()
    out_triqler = out_msstats[['ProteinName', 'PeptideSequence', 'PrecursorCharge', 'Intensity', 'Run', 'Condition']]
    out_triqler.columns = ['proteins', 'peptide', 'charge', 'intensity', 'run', 'condition']
    out_triqler.loc[:, "searchScore"] = 1 - report['PEP']

    out_msstats = out_msstats[out_msstats["Intensity"] != 0]
    out_msstats.to_csv('./out_msstats.csv', sep=',', index=False)
    out_triqler = out_triqler[out_triqler["intensity"] != 0]
    out_triqler.to_csv('./out_triqler.tsv', sep='\t', index=False)

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
        name = unimod_data.get_by_accession(mod.upper()).get_name()
        peptide = peptide.replace(mod, name)
    if peptide.startswith("("):
        peptide = peptide + "."
    return peptide


cli.add_command(convert)

if __name__ == "__main__":
    cli()
