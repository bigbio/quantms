#!/usr/bin/env python

import re

import click
from sdrf_pipelines.openms.unimod import UnimodDatabase

CONTEXT_SETTINGS = dict(help_option_names=["-h", "--help"])


@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass


@click.command("generate")
@click.option("--enzyme", "-e", help="")
@click.option("--fix_mod", "-f", help="")
@click.option("--var_mod", "-v", help="")
@click.pass_context
def generate_cfg(ctx, enzyme, fix_mod, var_mod):
    cut = enzyme_cut(enzyme)
    unimod_database = UnimodDatabase()
    fix_ptm, var_ptm = convert_mod(unimod_database, fix_mod, var_mod)

    var_ptm_str = " --var-mod "
    fix_ptm_str = " --fixed-mod "
    diann_fix_ptm = ""
    diann_var_ptm = ""
    for mod in fix_ptm:
        diann_fix_ptm += fix_ptm_str + mod
    for mod in var_ptm:
        diann_var_ptm += var_ptm_str + mod

    with open("diann_config.cfg", "w") as file:
        file.write("--cut " + cut + diann_fix_ptm + diann_var_ptm)


def convert_mod(unimod_database, fix_mod, var_mod):
    pattern = re.compile(r"\((.*?)\)")
    var_ptm = []
    fix_ptm = []

    if fix_mod != "":
        for mod in fix_mod.split(","):
            tag = 0
            for modification in unimod_database.modifications:
                if modification.get_name() == mod.split(" ")[0]:
                    diann_mod = modification.get_name() + "," + str(modification._delta_mono_mass)
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
            for modification in unimod_database.modifications:
                if modification.get_name() == mod.split(" ")[0]:
                    diann_mod = modification.get_name() + "," + str(modification._delta_mono_mass)
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


_ENZYME_SPECIFICITY = {
    "Trypsin": "K*,R*,!*P",
    "Trypsin/P": "K*,R*,*P",
    "Arg-C": "R*,!*P",
    "Asp-N": "*B,*D",
    "Chymotrypsin": "F*,W*,Y*,L*,!*P",
    "Lys-C": "K*,!*P",
}


def enzyme_cut(enzyme: str) -> str:
    return _ENZYME_SPECIFICITY.get(enzyme) or "--cut"


cli.add_command(generate_cfg)

if __name__ == "__main__":
    cli()
