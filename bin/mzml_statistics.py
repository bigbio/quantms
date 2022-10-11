from pyopenms import MzMLFile, MSExperiment
import os
import pandas as pd
import click

CONTEXT_SETTINGS = dict(help_option_names=["-h", "--help"])


@click.group(context_settings=CONTEXT_SETTINGS)
def cli():
    pass


@click.command("mzml_dataframe")
@click.option("--mzml_folder", "-d")
@click.pass_context
def mzml_dataframe(ctx, mzml_folder):

    file_columns = ["File_Name", "SpectrumID", "MSLevel", "Charge", "MS2_peaks", "Base_Peak_Intensity"]
    mzml_paths = list(i for i in os.listdir(mzml_folder) if i.endswith(".mzML"))
    mzml_count = 1

    def parse_mzml(file_name, file_columns):
        info = []
        exp = MSExperiment()
        MzMLFile().load(file_name, exp)
        for i in exp:
            name = os.path.split(file_name)[1]
            id = i.getNativeID()
            MSLevel = i.getMSLevel()
            if MSLevel == 2:
                charge_state = i.getPrecursors()[0].getCharge()
                peaks_tuple = i.get_peaks()
                peak_per_ms2 = len(peaks_tuple[0])
                if i.getMetaValue("base peak intensity"):
                    base_peak_intensity = i.getMetaValue("base peak intensity")
                else:
                    base_peak_intensity = max(peaks_tuple[1]) if len(peaks_tuple[1]) > 0 else "null"
                info_list = [name, id, 2, charge_state, peak_per_ms2, base_peak_intensity]
            else:
                info_list = [name, id, MSLevel, "null", "null", "null"]

            info.append(info_list)

        return pd.DataFrame(info, columns=file_columns)

    for i in mzml_paths:
        mzml_df = parse_mzml(mzml_folder + i, file_columns)
        tsv_header = True if mzml_count == 1 else False
        mzml_df.to_csv("mzml_info.tsv", mode="a", sep="\t", index=False, header=tsv_header)
        mzml_count += 1


cli.add_command(mzml_dataframe)

if __name__ == "__main__":
    cli()
