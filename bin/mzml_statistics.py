#!/usr/bin/env python

from pyopenms import MzMLFile, MSExperiment
import os
import pandas as pd
import sys


def mzml_dataframe(mzml_folder):

    file_columns = [
        "SpectrumID",
        "MSLevel",
        "Charge",
        "MS2_peaks",
        "Base_Peak_Intensity",
        "Retention_Time",
        "Exp_Mass_To_Charge",
    ]
    mzml_paths = list(i for i in os.listdir(mzml_folder) if i.endswith(".mzML"))
    mzml_count = 1

    def parse_mzml(file_name, file_columns):
        info = []
        exp = MSExperiment()
        MzMLFile().load(file_name, exp)
        for i in exp:
            id = i.getNativeID()
            MSLevel = i.getMSLevel()
            rt = i.getRT() if i.getRT() else None
            if MSLevel == 2:
                charge_state = i.getPrecursors()[0].getCharge()
                emz = i.getPrecursors()[0].getMZ() if i.getPrecursors()[0].getMZ() else None
                peaks_tuple = i.get_peaks()
                peak_per_ms2 = len(peaks_tuple[0])
                if i.getMetaValue("base peak intensity"):
                    base_peak_intensity = i.getMetaValue("base peak intensity")
                else:
                    base_peak_intensity = max(peaks_tuple[1]) if len(peaks_tuple[1]) > 0 else None
                info_list = [id, 2, charge_state, peak_per_ms2, base_peak_intensity, rt, emz]
            else:
                info_list = [id, MSLevel, None, None, None, rt, None]

            info.append(info_list)

        return pd.DataFrame(info, columns=file_columns)

    for i in mzml_paths:
        mzml_df = parse_mzml(mzml_folder + i, file_columns)
        mzml_df.to_csv(
            "{}_mzml_info.tsv".format(os.path.splitext(os.path.split(i)[1])[0]),
            mode="a",
            sep="\t",
            index=False,
            header=True,
        )


def main():
    mzmls_path = sys.argv[1]
    mzml_dataframe(mzmls_path)


if __name__ == "__main__":
    sys.exit(main())
