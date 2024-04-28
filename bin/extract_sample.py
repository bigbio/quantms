#!/usr/bin/env python

import argparse
import errno
import os
import sys
from pathlib import Path
import pandas as pd


def parse_args(args=None):
    Description = "Extract sample information from an experiment design file"
    Epilog = "Example usage: python extract_sample.py <EXP>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("EXP", help="Expdesign file to be extracted")
    return parser.parse_args(args)


def extract_sample(expdesign):
    data = pd.read_csv(expdesign, sep="\t", header=0, dtype=str)
    fTable = data.dropna()

    # two table format
    with open(expdesign, "r") as f:
        lines = f.readlines()
        empty_row = lines.index("\n")
        s_table = [i.replace("\n", "").split("\t") for i in lines[empty_row + 1:]][1:]
        s_header = lines[empty_row + 1].replace("\n", "").split("\t")
        s_DataFrame = pd.DataFrame(s_table, columns=s_header)

    sample_dt = pd.DataFrame()
    if "MSstats_Mixture" not in s_DataFrame.columns:
        fTable = fTable[["Spectra_Filepath", "Sample"]]
        fTable.to_csv(f"{Path(expdesign).stem}_sample.csv", sep="\t", index=False)
    else:
        fTable.drop_duplicates(subset=["Spectra_Filepath"], inplace=True)
        for _, row in fTable.iterrows():
            mixture_id = s_DataFrame[s_DataFrame["Sample"] == row["Sample"]]["MSstats_Mixture"]
            sample_dt = sample_dt.append({"Spectra_Filepath": row["Spectra_Filepath"], "Sample": mixture_id},
                                         ignore_index=True)
        sample_dt.to_csv(f"{Path(expdesign).stem}_sample.csv", sep="\t", index=False)


def main(args=None):
    args = parse_args(args)
    extract_sample(args.EXP)


if __name__ == "__main__":
    sys.exit(main())
