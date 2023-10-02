#!/usr/bin/env python
GENERAL_HELP = """
Converts .d files to multiqc compatible files.

This script can be used either as standalone or as part of a larger workflow
with pmultiqc as a plugin.

For the standalone usage follow the instructions in the usage section.
If you want to use the output of this script as part of a larger workflow
you will have to modify the `multiqc_config.yaml` file used as te input
for multiqc. Please refer to the multiqc documentation for more information.

Generates the following files:
    - tic_<basename>.tsv
    - bpc_<basename>.tsv
    - ms1_peaks_<basename>.tsv
    - general_stats_<basename>.tsv
    - dotd_mqc.yml

Usage:
    $ python dotd_2_mqc.py single <input1.d> <output>
    $ python dotd_2_mqc.py single <input2.d> <output>
    $ python dotd_2_mqc.py aggregate <output> <output>

    # These last steps can also be
    $ python dotd_2_mqc.py single <input_dir> <output>
    # If the input directory contains multiple .d files.

    $ cd <output>
    $ multiqc -c dotd_mqc.yml . 
"""

from typing import List, Tuple  # noqa: E402
import os  # noqa: E402
import sqlite3  # noqa: E402
import argparse  # noqa: E402
from pathlib import Path  # noqa: E402
from dataclasses import dataclass  # noqa: E402
from logging import getLogger  # noqa: E402
import logging  # noqa: E402

VERSION = "0.0.2"
logging.basicConfig(level=logging.DEBUG)
logger = getLogger(__name__)

# The time resulution in seconds.
# Larger values will result in smaller data files as outputs
# and will slightly smooth the data. 5 seconds seems to be
# a good value for qc purposes.
SECOND_RESOLUTION = 5
# This string is used as a template for the multiqc config file.
# Check the module docstring for more information.
MQC_YML = """
custom_data:
    total_ion_chromatograms:
        file_format: 'tsv'
        section_name: 'MS1 TIC'
        description: 'MS1 total ion chromatograms extracted from the .d files'
        plot_type: 'linegraph'
        pconfig:
            id: 'ms1_tic'
            title: 'MS1 TIC'
            ylab: 'Ion Count'
            ymin: 0
    base_peak_chromatograms:
        file_format: 'tsv'
        section_name: 'MS1 BPC'
        description: 'MS1 base peak chromatograms extracted from the .d files'
        plot_type: 'linegraph'
        pconfig:
            id: 'ms1_bpc'
            title: 'MS1 BPC'
            ylab: 'Ion Count'
            ymin: 0
    number_of_peaks:
        file_format: 'tsv'
        section_name: 'MS1 Peaks'
        description: 'MS1 Peaks from the .d files'
        plot_type: 'linegraph'
        pconfig:
            id: 'ms1_peaks'
            title: 'MS1 Peaks'
            ylab: 'Peak Count'
            ymin: 0
    general_stats:
        file_format: 'tsv'
        section_name: 'General Stats'
        description: 'General stats from the .d files'
        plot_type: 'table'
sp:
    total_ion_chromatograms:
        fn: 'tic_*'
    base_peak_chromatograms:
        fn: 'bpc_*'
    number_of_peaks:
        fn: 'ms1_peaks_*'
    general_stats:
        fn: 'general_stats.tsv'
"""


@dataclass
class DotDFile:
    filepath: os.PathLike

    @property
    def sql_filepath(self):
        fp = Path(self.filepath) / "analysis.tdf"
        return fp

    @property
    def basename(self):
        return Path(self.filepath).stem

    @property
    def ms1_tic(self) -> List[Tuple[float, float]]:
        """Gets the MS1 total-ion-chromatogram.

        Returns:
            List[Tuple[float, float]]: List of (time, intensity) tuples.
        """
        # Note that here I am using min and not mean for purely qc reasons.
        # Since the diagnostic aspect here is mainly to see major fluctuations
        # in the intensity, and usually these are scans with very low intensity
        # due to bubbles or ionization issues, thus the mean would hide that.
        cmd = f"""
        SELECT MIN(Time), MIN(SummedIntensities)
        FROM frames  WHERE MsMsType = '0'
        GROUP BY CAST(Time / {SECOND_RESOLUTION} AS INTEGER)
        ORDER BY Time
        """
        conn = sqlite3.connect(self.sql_filepath)
        c = conn.cursor()
        out = c.execute(cmd).fetchall()
        conn.close()
        return out

    @property
    def ms1_bpc(self) -> List[Tuple[float, float]]:
        """Gets the MS1 base-peak-chromatogram.

        Returns:
            List[Tuple[float, float]]: List of (time, intensity) tuples.
        """
        cmd = f"""
        SELECT MIN(Time), MAX(MaxIntensity)
        FROM frames  WHERE MsMsType = '0'
        GROUP BY CAST(Time / {SECOND_RESOLUTION} AS INTEGER)
        ORDER BY Time
        """
        conn = sqlite3.connect(self.sql_filepath)
        c = conn.cursor()
        out = c.execute(cmd).fetchall()
        conn.close()
        return out

    @property
    def ms1_peaks(self) -> List[Tuple[float, float]]:
        """Gets the number of MS1 peaks.

        Returns:
            List[Tuple[float, float]]: List of (time, intensity) tuples.
        """
        cmd = f"""
        SELECT MIN(Time), AVG(NumPeaks)
        FROM frames  WHERE MsMsType = '0'
        GROUP BY CAST(Time / {SECOND_RESOLUTION} AS INTEGER)
        ORDER BY Time
        """
        conn = sqlite3.connect(self.sql_filepath)
        c = conn.cursor()
        out = c.execute(cmd).fetchall()
        conn.close()
        return out

    def get_acquisition_datetime(self) -> str:
        """Gets the acquisition datetime

        Returns
        -------
        str
            The acquisition datetime in ISO 8601 format.
            [('2023-08-06T06:23:19.141-08:00',)]
        """
        cmd = "SELECT Value FROM GlobalMetadata WHERE key='AcquisitionDateTime'"
        conn = sqlite3.connect(self.sql_filepath)
        c = conn.cursor()
        out = c.execute(cmd).fetchall()
        conn.close()
        if not len(out) == 1:
            raise RuntimeError("More than one acquisition datetime found.")

        return out[0][0]

    def get_tot_current(self) -> float:
        """Gets the total current from the ms1 scans.

        Returns
        -------
        float
            The total current.
        """
        cmd = """
        SELECT SUM(CAST(SummedIntensities AS FLOAT))
        FROM frames WHERE MsMsType = '0'
        """
        conn = sqlite3.connect(self.sql_filepath)
        c = conn.cursor()
        out = c.execute(cmd).fetchall()
        conn.close()
        if not len(out) == 1:
            raise RuntimeError("More than one total current found.")

        return out[0][0]

    def get_dia_scan_current(self) -> float:
        """Gets the total current from the ms2 scans.

        Returns
        -------
        float
            The total current.
        """
        cmd = """
        SELECT SUM(CAST(SummedIntensities AS FLOAT))
        FROM frames WHERE MsMsType = '9'
        """
        conn = sqlite3.connect(self.sql_filepath)
        c = conn.cursor()
        out = c.execute(cmd).fetchall()
        conn.close()
        if not len(out) == 1:
            raise RuntimeError("More than one total current found.")

        return out[0][0]

    def get_general_stats(self) -> dict:
        """Gets the general stats from the .d file.

        Returns
        -------
        dict
            A dictionary of general stats.
        """
        out = {
            "AcquisitionDateTime": self.get_acquisition_datetime(),
            "TotalCurrent": self.get_tot_current(),
            "DIA_ScanCurrent": self.get_dia_scan_current(),
        }
        return out

    def write_tables(self, location):
        logger.info(f"Writing tables for {self.basename}")
        logger.info(f"Writing tables to {location}")
        location = Path(location)
        location.mkdir(parents=True, exist_ok=True)
        tic = self.ms1_tic
        bpc = self.ms1_bpc
        npeaks = self.ms1_peaks
        general_stats = self.get_general_stats()

        tic_path = location / f"tic_{self.basename}.tsv"
        bpc_path = location / f"bpc_{self.basename}.tsv"
        peaks_location = location / f"ms1_peaks_{self.basename}.tsv"
        general_stats_location = location / f"general_stats_{self.basename}.tsv"

        logger.info(f"Writing {tic_path}")
        with tic_path.open("w") as f:
            for t, i in tic:
                f.write(f"{t}\t{i}\n")

        logger.info(f"Writing {bpc_path}")
        with bpc_path.open("w") as f:
            for t, i in bpc:
                f.write(f"{t}\t{i}\n")

        logger.info(f"Writing {peaks_location}")
        with peaks_location.open("w") as f:
            for t, i in npeaks:
                f.write(f"{t}\t{i}\n")

        logger.info(f"Writing {general_stats_location}")
        with general_stats_location.open("w") as f:
            for k, v in general_stats.items():
                f.write(f"{k}\t{v}\n")


def main_single(input_path, output_path):
    if input_path.is_dir() and str(input_path).endswith(".d"):
        input_files = [input_path]
    elif input_path.is_dir():
        input_files = list(input_path.glob("*.d"))
    else:
        raise RuntimeError(f"Input path {input_path} is not a file or directory.")

    output_path.mkdir(parents=True, exist_ok=True)

    for f in input_files:
        d = DotDFile(f)
        d.write_tables(output_path)

    logger.info(f"Writing {output_path / 'dotd_mqc.yml'}")
    with (output_path / "dotd_mqc.yml").open("w") as f:
        f.write(MQC_YML)

    if len(input_files) > 1:
        logger.info("Writing aggregate general stats.")
        main_aggregate(output_path, output_path)

    logger.info("Done.")


def main_aggregate(input_path, output_path):
    # Find the general stats files
    if not input_path.is_dir():
        logger.error(f"Input path {input_path} is not a directory.")
        raise ValueError("Input path must be a directory.")

    general_stats_files = list(input_path.glob("general_stats_*.tsv"))
    if not general_stats_files:
        logger.error(f"No general stats files found in {input_path}.")
        raise ValueError("No general stats files found.")

    # Merge them to a single table
    # Effectively transposing the columns and adding column called file,
    # which contains the file name from which the stats were acquired.
    logger.info("Merging general stats files.")
    general_stats = []
    for f in general_stats_files:
        curr_stats = {"file": f.stem.replace("general_stats_", "")}
        with f.open("r") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                k, v = line.split("\t")
                curr_stats[k] = v

        general_stats.append(curr_stats)

    # Write the general stats file
    logger.info("Writing general stats file.")
    with (output_path / "general_stats.tsv").open("w") as f:
        f.write("\t".join(general_stats[0].keys()) + "\n")
        for s in general_stats:
            f.write("\t".join(s.values()) + "\n")


if __name__ == "__main__":
    # create the top-level parser
    parser = argparse.ArgumentParser(add_help=True, usage=GENERAL_HELP)
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    subparsers = parser.add_subparsers(required=True)

    # create the parser for the "single" command
    parser_foo = subparsers.add_parser("single")
    parser_foo.add_argument("input", help="Input .d file or directory of .d files.")
    parser_foo.add_argument("output", help="Output directory.")
    parser_foo.set_defaults(func=main_single)

    # create the parser for the "aggregate" command
    parser_bar = subparsers.add_parser("aggregate")
    parser_bar.add_argument("input", help="Directory that contains the general stats files to aggregate.")
    parser_bar.add_argument("output", help="Output directory.")
    parser_bar.set_defaults(func=main_aggregate)

    # parse the args and call whatever function was selected
    args, unkargs = parser.parse_known_args()
    if unkargs:
        print(f"Unknown arguments: {unkargs}")
        raise RuntimeError("Unknown arguments.")

    input_path = Path(args.input)
    output_path = Path(args.output)

    args.func(input_path, output_path)
