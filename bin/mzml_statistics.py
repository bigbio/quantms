#!/usr/bin/env python
"""
This script parse the mass spectrum file and generates a set of statistics about the file.
License: Apache 2.0
Authors: Hong Wong, Yasset Perez-Riverol
"""
import sys
from pathlib import Path
import sqlite3

import pandas as pd
from pyopenms import MSExperiment, MzMLFile


def ms_dataframe(ms_path: str) -> None:
    file_columns = [
        "SpectrumID",
        "MSLevel",
        "Charge",
        "MS_peaks",
        "Base_Peak_Intensity",
        "Summed_Peak_Intensities",
        "Retention_Time",
        "Exp_Mass_To_Charge",
        "AcquisitionDateTime",
    ]

    def parse_mzml(file_name: str, file_columns: list):
        info = []
        exp = MSExperiment()
        acquisition_datetime = exp.getDateTime().get()
        MzMLFile().load(file_name, exp)
        for spectrum in exp:
            id_ = spectrum.getNativeID()
            MSLevel = spectrum.getMSLevel()
            rt = spectrum.getRT() if spectrum.getRT() else None

            peaks_tuple = spectrum.get_peaks()
            peak_per_ms = len(peaks_tuple[0])

            if not spectrum.metaValueExists("base peak intensity"):
                bpc = max(peaks_tuple[1]) if len(peaks_tuple[1]) > 0 else None
            else:
                bpc = spectrum.getMetaValue("base peak intensity")

            if not spectrum.metaValueExists("total ion current"):
                tic = sum(peaks_tuple[1]) if len(peaks_tuple[1]) > 0 else None
            else:
                tic = spectrum.getMetaValue("total ion current")

            if MSLevel == 1:
                info_list = [id_, MSLevel, None, peak_per_ms, bpc, tic, rt, None, acquisition_datetime]
            elif MSLevel == 2:
                charge_state = spectrum.getPrecursors()[0].getCharge()
                emz = spectrum.getPrecursors()[0].getMZ() if spectrum.getPrecursors()[0].getMZ() else None
                info_list = [id_, MSLevel, charge_state, peak_per_ms, bpc, tic, rt, emz, acquisition_datetime]
            else:
                info_list = [id_, MSLevel, None, None, None, None, rt, None, acquisition_datetime]

            info.append(info_list)

        return pd.DataFrame(info, columns=file_columns)

    def parse_bruker_d(file_name: str, file_columns: list):
        sql_filepath = f"{file_name}/analysis.tdf"
        conn = sqlite3.connect(sql_filepath)
        c = conn.cursor()

        datetime_cmd = "SELECT Value FROM GlobalMetadata WHERE key='AcquisitionDateTime'"
        AcquisitionDateTime = c.execute(datetime_cmd).fetchall()[0][0]

        df = pd.read_sql_query("SELECT Id, MsMsType, NumPeaks, MaxIntensity, SummedIntensities, Time FROM frames", conn)
        df["AcquisitionDateTime"] = AcquisitionDateTime

        # {8:'DDA-PASEF', 9:'DIA-PASEF'}
        if 8 in df["MsMsType"].values:
            mslevel_map = {0: 1, 8: 2}
        elif 9 in df["MsMsType"].values:
            mslevel_map = {0: 1, 9: 2}
        df["MsMsType"] = df["MsMsType"].map(mslevel_map)

        try:
            precursor_df = pd.read_sql_query("SELECT * from Precursors", conn)
        except Exception as e:
            print(f"No precursers recorded in {file_name}")
            precursor_df = pd.DataFrame()

        if len(df) == len(precursor_df):
            df = pd.concat([df, precursor_df["Charge", "MonoisotopicMz"]], axis=1)
            df["Charge"] = df["Charge"].fillna(0)
        else:
            df[["Charge", "Exp_Mass_To_Charge"]] = None, None

        df = df[
            ["Id", "MsMsType", "Charge", "NumPeaks", "MaxIntensity", "SummedIntensities", "Time", "Exp_Mass_To_Charge",
            "AcquisitionDateTime"]]
        df.columns = file_columns

        return df

    if Path(ms_path).suffix == '.d' and Path(ms_path).is_dir:
        ms_df = parse_bruker_d(ms_path, file_columns)
    elif Path(ms_path).suffix in [".mzML", ".mzml"]:
        ms_df = parse_mzml(ms_path, file_columns)

    ms_df.to_csv(
        f"{Path(ms_path).stem}_ms_info.tsv",
        mode="w",
        sep="\t",
        index=False,
        header=True,
    )


def main():
    ms_path = sys.argv[1]
    ms_dataframe(ms_path)


if __name__ == "__main__":
    sys.exit(main())
