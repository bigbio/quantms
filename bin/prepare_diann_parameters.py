#!/usr/bin/env python

import re
import click
from sdrf_pipelines.openms.unimod import UnimodDatabase

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])
@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass

@click.command('generate')
@click.option("--enzyme", "-e", help="")
@click.option("--fix_mod", "-f", help="")
@click.option("--var_mod", "-v", help="")
@click.option("--precursor_tolerence", "-p", help="")
@click.option("--precursor_tolerence_unit", "-pu", help="")
@click.option("--fragment_tolerence", "-fr", help="")
@click.option("--fragment_tolerence_unit", "-fu", help="")
@click.pass_context
def generate_cfg(ctx, enzyme, fix_mod, var_mod, precursor_tolerence, precursor_tolerence_unit, fragment_tolerence, fragment_tolerence_unit):
    cut = enzyme_cut(enzyme)
    unimod_database = UnimodDatabase()
    fix_ptm, var_ptm = convert_mod(unimod_database, fix_mod, var_mod)

    var_ptm_str = " --var-mod "
    fix_ptm_str = " --fixed-mod "
    diann_fix_ptm = ""
    diann_var_ptm = ""
    for mod in fix_ptm:
        diann_fix_ptm += (fix_ptm_str + mod)
    for mod in var_ptm:
        diann_var_ptm += (var_ptm_str + mod)

    with open("diann_config.cfg", "w") as f:
        f.write("--cut " + cut + diann_fix_ptm + diann_var_ptm)

def convert_mod(unimod_database, fix_mod, var_mod):
    pattern = re.compile("\((.*?)\)")
    var_ptm = []
    fix_ptm = []

    if fix_mod != "":
        for mod in fix_mod.split(","):
            tag = 0
            for m in unimod_database.modifications:
                if m.get_name() == mod.split(" ")[0]:
                    diann_mod = m.get_name() + "," + str(m._delta_mono_mass)
                    tag = 1
                    break
            if tag == 0:
                print("Warning: Currently only supported unimod modifications for DIA pipeline. Skipped: " + mod)
                continue
            site = re.findall(pattern, " ".join(mod.split(" ")[1:]))[0]
            if site == "Protein N-term":
                site = "*n"
            elif site == "N-term":
                site = "n"

            if "TMT" in diann_mod or "Label" in diann_mod or "iTRAQ" in diann_mod or "mTRAQ" in diann_mod:
                fix_ptm.append(diann_mod + "," + site + "," + "label")
            else:
                fix_ptm.append(diann_mod + "," + site)

    if var_mod != "":
        for mod in var_mod.split(","):
            tag = 0
            for m in unimod_database.modifications:
                if m.get_name() == mod.split(" ")[0]:
                    diann_mod = m.get_name() + "," + str(m._delta_mono_mass)
                    tag = 1
                    break
            if tag == 0:
                print("Warning: Currently only supported unimod modifications for DIA pipeline. Skipped: " + mod)
                continue
            site = re.findall(pattern, " ".join(mod.split(" ")[1:]))[0]
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

cli.add_command(generate_cfg)

if __name__ == "__main__":
    cli()
