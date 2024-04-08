#!/usr/bin/env python
"""
This script parse the mass spectrum file and generates a set of statistics about the file.
License: Apache 2.0
Authors: Hong Wong, Yasset Perez-Riverol
"""
import sys
from pathlib import Path
import sqlite3
import re
import pandas as pd
from pyopenms import MSExperiment, MzMLFile


def ms_dataframe(ms_path: str, id_only: bool = False) -> None:
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

    def parse_mzml(file_name: str, file_columns: list, id_only: bool = False):
        info = []
        psm_part_info = []
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
                mz_array = peaks_tuple[0]
                intensity_array = peaks_tuple[1]
            else:
                info_list = [id_, MSLevel, None, None, None, None, rt, None, acquisition_datetime]

            if id_only and MSLevel == 2:
                psm_part_info.append([re.findall(r"[scan|spectrum]=(\d+)", id_)[0], MSLevel, mz_array, intensity_array])
            info.append(info_list)

        if id_only and len(psm_part_info) > 0:
            pd.DataFrame(psm_part_info, columns=["scan", "ms_level", "mz", "intensity"]).to_csv(
                f"{Path(ms_path).stem}_spectrum_df.csv",
                mode="w",
                index=False,
                header=True,
            )

        return pd.DataFrame(info, columns=file_columns)

    def parse_bruker_d(file_name: str, file_columns: list):
        sql_filepath = f"{file_name}/analysis.tdf"
        if not Path(sql_filepath).exists():
            msg = f"File '{sql_filepath}' not found"
            raise FileNotFoundError(msg)
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
        else:
            msg = f"Unrecognized ms type '{df['MsMsType'].values}'"
            raise ValueError(msg)
        df["MsMsType"] = df["MsMsType"].map(mslevel_map)

        try:
            # This line raises an sqlite error if the table does not exist
            _ = conn.execute("SELECT * from Precursors LIMIT 1").fetchall()
            precursor_df = pd.read_sql_query("SELECT * from Precursors", conn)
        except sqlite3.OperationalError as e:
            if "no such table: Precursors" in str(e):
                print(f"No precursers recorded in {file_name}, This is normal for DIA data.")
                precursor_df = pd.DataFrame()
            else:
                raise

        if len(df) == len(precursor_df):
            df = pd.concat([df, precursor_df["Charge", "MonoisotopicMz"]], axis=1)
            df["Charge"] = df["Charge"].fillna(0)
        else:
            df[["Charge", "Exp_Mass_To_Charge"]] = None, None

        df = df[
            [
                "Id",
                "MsMsType",
                "Charge",
                "NumPeaks",
                "MaxIntensity",
                "SummedIntensities",
                "Time",
                "Exp_Mass_To_Charge",
                "AcquisitionDateTime",
            ]
        ]
        df.columns = pd.Index(file_columns)

        return df

    if not (Path(ms_path).exists()):
        print(f"Not found '{ms_path}', trying to find alias")
        ms_path_path = Path(ms_path)
        path_stem = str(ms_path_path.stem)
        candidates = (
            list(ms_path_path.parent.glob("*.d"))
            + list(ms_path_path.parent.glob("*.mzml"))
            + list(ms_path_path.parent.glob("*.mzML"))
        )

        candidates = [c for c in candidates if path_stem in str(c)]

        if len(candidates) == 1:
            ms_path = str(candidates[0].resolve())
        else:
            raise FileNotFoundError()

    if Path(ms_path).suffix == ".d" and Path(ms_path).is_dir():
        ms_df = parse_bruker_d(ms_path, file_columns)
    elif Path(ms_path).suffix in [".mzML", ".mzml"]:
        ms_df = parse_mzml(ms_path, file_columns, id_only)
    else:
        msg = f"Unrecognized or inexistent mass spec file '{ms_path}'"
        raise RuntimeError(msg)

    ms_df.to_csv(
        f"{Path(ms_path).stem}_ms_info.tsv",
        mode="w",
        sep="\t",
        index=False,
        header=True,
    )


def main():
    ms_path = sys.argv[1]
    id_only = sys.argv[2]
    ms_dataframe(ms_path, id_only)


if __name__ == "__main__":
    sys.exit(main())
