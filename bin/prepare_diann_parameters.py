#!/usr/bin/env python

import re
import click
import pandas as pd

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])
@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass

@click.command('generate')
@click.option("--unimod_csv", "-u",help="")
@click.option("--enzyme", "-e", help="")
@click.option("--fix_mod", "-f", help="")
@click.option("--var_mod", "-v", help="")
@click.option("--precursor_tolerence", "-p", help="")
@click.option("--precursor_tolerence_unit", "-pu", help="")
@click.option("--fragment_tolerence", "-fr", help="")
@click.option("--fragment_tolerence_unit", "-fu", help="")
@click.pass_context
def generate_cfg(ctx, unimod_csv, enzyme, fix_mod, var_mod, precursor_tolerence, precursor_tolerence_unit, fragment_tolerence, fragment_tolerence_unit):
    cut = enzyme_cut(enzyme)
    fix_ptm, var_ptm = convert_mod(unimod_csv, fix_mod, var_mod)
    mass_acc, mass_acc_ms1 = mass_tolerence(precursor_tolerence, precursor_tolerence_unit, fragment_tolerence, fragment_tolerence_unit)
    mass_acc = " --mass_acc " + str(mass_acc)
    mass_acc_ms1 = " --mass_acc_ms1 " + str(mass_acc_ms1)

    var_ptm_str = " --var-mod "
    fix_ptm_str = " --fixed-mod "
    for mod in fix_ptm:
        fix_ptm_str += mod
    for mod in var_ptm:
        var_ptm_str += mod

    with open("diann_config.cfg", "w") as f:
        f.write("--dir ./mzMLs --cut " + cut + fix_ptm_str + var_ptm_str + mass_acc + mass_acc_ms1 +
                " --fasta-search --matrices --report-lib-info")

def convert_mod(unimod_csv, fix_mod, var_mod):
    pattern = re.compile("\((.*?)\)")
    var_ptm = []
    fix_ptm = []
    unimod = pd.read_csv(unimod_csv, header=0, sep=",")
    for mod in fix_mod.split(","):
        diann_mod = unimod[unimod['name'] == mod.split(" ")[0]]["params"].values[0]
        site = re.findall(pattern, mod.split(" ")[1])[0]
        if site == "Protein N-term":
            site = "*n"
        elif site == "N-term":
            site = "n"

        if "TMT" in diann_mod or "Label" in diann_mod or "iTRAQ" in diann_mod or "mTRAQ" in diann_mod:
            fix_ptm.append(diann_mod + "," + site + "," + "label")
        else:
            fix_ptm.append(diann_mod + "," + site)

    for mod in var_mod.split(","):
        diann_mod = unimod[unimod['name'] == mod.split(" ")[0]]["params"].values[0]
        site = re.findall(pattern, mod.split(" ")[1])[0]
        if site == "Protein N-term":
            site = "*n"
        elif site == "N-term":
            site = "n"

        if "TMT" in diann_mod or "Label" in diann_mod or "iTRAQ" in diann_mod or "mTRAQ" in diann_mod:
            var_ptm.append(diann_mod + "," + site + "," + "label")
        else:
            var_ptm.append(diann_mod + "," + site)

    return fix_ptm, var_ptm

def enzyme_cut(enzyme):
    if enzyme == "Trypsin":
        cut = "K*,R*,!*P"
    elif enzyme == "Trypsin/P":
        cut = "K*,R*,*P"
    elif enzyme == "Arg-C":
        cut = "R*,!*P"
    elif enzyme == "Asp-N":
        cut = "*B,*D"
    elif enzyme == "Chymotrypsin":
        cut = "F*,W*,Y*,L*,!*P"
    elif enzyme == "Lys-C":
        cut="K*,!*P"
    else:
        cut = "--cut"
    return cut

def mass_tolerence(prec, precursor_tolerence_unit, frag, fragment_tolerence_unit):
    if precursor_tolerence_unit == "ppm":
        ms1_tolerence = prec
    else:
        # Default 10 ppm
        print("Warning: " + precursor_tolerence_unit + " unit not supported for DIA-NN. Default 10 ppm")
        ms1_tolerence = 10

    if fragment_tolerence_unit == "ppm":
        ms2_tolerence = frag
    else:
        # Default 20 ppm
        ms2_tolerence = 20
        print("Warning: " + fragment_tolerence_unit + " unit not supported for DIA-NN. Default 20 ppm")

    return ms1_tolerence, ms2_tolerence

cli.add_command(generate_cfg)

if __name__ == "__main__":
    cli()
