#!/usr/bin/env python

import sys
from pathlib import Path

import pandas as pd
from pyopenms import MSExperiment, MzMLFile


def mzml_dataframe(mzml_path: str) -> None:
    file_columns = [
        "SpectrumID",
        "MSLevel",
        "Charge",
        "MS2_peaks",
        "Base_Peak_Intensity",
        "Retention_Time",
        "Exp_Mass_To_Charge",
    ]

    def parse_mzml(file_name: str, file_columns: list):
        info = []
        exp = MSExperiment()
        MzMLFile().load(file_name, exp)
        for spectrum in exp:
            id = spectrum.getNativeID()
            MSLevel = spectrum.getMSLevel()
            rt = spectrum.getRT() if spectrum.getRT() else None
            if MSLevel == 2:
                charge_state = spectrum.getPrecursors()[0].getCharge()
                emz = spectrum.getPrecursors()[0].getMZ() if spectrum.getPrecursors()[0].getMZ() else None
                peaks_tuple = spectrum.get_peaks()
                peak_per_ms2 = len(peaks_tuple[0])
                if spectrum.getMetaValue("base peak intensity"):
                    base_peak_intensity = spectrum.getMetaValue("base peak intensity")
                else:
                    base_peak_intensity = max(peaks_tuple[1]) if len(peaks_tuple[1]) > 0 else None
                info_list = [id, 2, charge_state, peak_per_ms2, base_peak_intensity, rt, emz]
            else:
                info_list = [id, MSLevel, None, None, None, rt, None]

            info.append(info_list)

        return pd.DataFrame(info, columns=file_columns)

    mzml_df = parse_mzml(mzml_path, file_columns)
    mzml_df.to_csv(
        f"{Path(mzml_path).stem}_mzml_info.tsv",
        mode="a",
        sep="\t",
        index=False,
        header=True,
    )


def main():
    mzml_path = sys.argv[1]
    mzml_dataframe(mzml_path)


if __name__ == "__main__":
    sys.exit(main())
