#!/usr/bin/env python

import argparse
import matplotlib.pyplot as plt
import mpld3
import time


def parseArgs() -> tuple:

    parser = argparse.ArgumentParser(description="Generates a Histogram of mass shifts (PTM shepherd output)")
    parser.add_argument('-i', metavar="PATH_TO_TSV", help="Path to global.modsummary.tsv", required=True)
    parser.add_argument('-o', metavar="PATH_TO_OUTPUT", help="Path to '.html' outputfile", required=True)
    args = parser.parse_args()

    tsvfile = args.i
    pngfile = args.o

    return (tsvfile, pngfile)

def parsetsv(tsvfile:str) -> list:

    tsv = open(tsvfile, "r")
    modificationtable = []
    for line in tsv:
        modificationtable.append(line.split("\t"))

    return modificationtable

def makeHistogram(modificationtable: list, outputfile:str):

    mshifts = []
    abundance = []
    labels = []

    for item in modificationtable[1:]:
        mshifts.append(float(item[1]))
        abundance.append(float(item[2]))
        labels.append(str(item[0]))

    fig, ax = plt.subplots()
    bars = ax.bar(mshifts, height=abundance, color='black')
    ax.set_xlabel("Theoretical Mass Shift [Da]")
    ax.set_ylabel("PSMs")
    ax.set_title("Delta-mass Histogram")

    for bar, label in zip(bars, labels):
        tooltip = mpld3.plugins.LineLabelTooltip(bar, label)
    
        mpld3.plugins.connect(fig, tooltip)

    mpld3.save_html(fig, outputfile)


def main():
    st_wall = time.time()
    st_process = time.process_time()
    tsvfile, pngfile = parseArgs()
    globalmods = parsetsv(tsvfile)
    makeHistogram(globalmods, pngfile)
    print("Delta_Mass_Histogram took {} s (wall), {} s (CPU)".format(round(time.time()-st_wall, 2), round(time.process_time()-st_process, 2)))


main()
