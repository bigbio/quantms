#!/usr/bin/env python
GENERAL_HELP = """
Converts .d files to multiqc compatible files.

Generates the following files:
    - tic_<basename>.tsv
    - bpc_<basename>.tsv
    - ms1_peaks_<basename>.tsv
    - general_stats_<basename>.tsv
    - dotd_mqc.yml

Usage:
    $ python dotd_2_mqc.py <input> <output>
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

VERSION = "0.0.1"
logger = getLogger(__name__)

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
sp:
    total_ion_chromatograms:
        fn: 'tic_*'
    base_peak_chromatograms:
        fn: 'bpc_*'
    number_of_peaks:
        fn: 'ms1_peaks_*'
    general_stats:
        fn: 'general_stats_*'
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
        cmd = """
        SELECT CAST(Time AS INTEGER), AVG(SummedIntensities)
        FROM frames  WHERE MsMsType = '0'
        GROUP BY CAST(Time AS INTEGER)
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
        cmd = """
        SELECT CAST(Time AS INTEGER), MAX(MaxIntensity)
        FROM frames  WHERE MsMsType = '0'
        GROUP BY CAST(Time AS INTEGER)
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
        cmd = """
        SELECT CAST(Time AS INTEGER), AVG(NumPeaks)
        FROM frames  WHERE MsMsType = '0'
        GROUP BY CAST(Time AS INTEGER)
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

    def get_general_stats(self) -> dict:
        """Gets the general stats from the .d file.

        Returns
        -------
        dict
            A dictionary of general stats.
        """
        out = {
            "AcquisitionDateTime": self.get_acquisition_datetime(),
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
        general_stats["TotCurrent"] = sum([i for t, i in tic])

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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, usage=GENERAL_HELP)
    parser.add_argument("input", help="Input .d file or directory of .d files.")
    parser.add_argument("output", help="Output directory.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")

    args, unkargs = parser.parse_known_args()

    if unkargs:
        print(f"Unknown arguments: {unkargs}")
        raise RuntimeError("Unknown arguments.")

    input_path = Path(args.input)
    output_path = Path(args.output)

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
