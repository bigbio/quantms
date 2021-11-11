//
// Create channel for input file
//

params.sdrfparsing_options = [:]

include { SDRFPARSING } from '../../modules/local/sdrfparsing/main' addParams( options: params.sdrfparsing_options)

workflow CREATE_INPUT_CHANNEL {
    take:
    sdrf_file
    is_sdrf

    main:
    ch_versions = Channel.empty()

    if (is_sdrf) {
        SDRFPARSING ( sdrf_file )
        ch_versions = ch_versions.mix(SDRFPARSING.out.version)
        SDRFPARSING.out.ch_sdrf_config_file
        .splitCsv(header: true, sep: '\t')
        .multiMap{ row -> id = row.toString().md5()
            isobaricanalyzer_settings: tuple(id, row.Label, row.DissociationMethod)
            comet_settings: msgf_settings: tuple(id, row.FixedModifications, row.VariableModifications,
                row.Label, row.PrecursorMassTolerance, row.PrecursorMassToleranceUnit, row.FragmentMassTolerance,
                row.FragmentMassToleranceUnit, row.DissociationMethod, row.Enzyme)
            idx_settings: tuple(id, row.Enzyme)
            enzyme_setting: row.Enzyme
            luciphor_settings: tuple(id, row.DissociationMethod)
            spectra_files: tuple(id, !params.root_folder ? row.URI : params.root_folder + "/"
                + (params.local_input_type ? row.Filename.take(row.Filename.lastIndexOf('.'))
                + '.' + params.local_input_type : row.Filename))
        }
        .set{ results }
    } else {
        exp_file = Channel.fromPath(exp_file, checkIfExists: true)
        exp_file.splitCsv(header: true, sep: '\t')
        .multiMap{ row -> filestr = row.Spectra_Filepath.toString()
            id = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))
            isobaricanalyzer_settings: tuple(id, params.label, params.fragment_method)
            comet_settings: msgf_settings: tuple(id, params.fixed_mods, params.variable_mods,
                params.precursor_mass_tolerance, params.precursor_mass_tolerance_unit,
                params.fragment_mass_tolerance, params.fragment_mass_tolerance_unit,
                params.fragment_method, params.enzyme
            )
            idx_settings: tuple(id, params.enzyme)
            enzyme_setting: params.enzyme
            luciphor_settings: tuple(id, params.fragment_method)
            spectra_files: tuple(id, row.Spectra_Filepath)
        }
        .set{ results }
    }

    emit:
    isobaricanalyzer_settings = results.isobaricanalyzer_settings
    comet_settings            = results.comet_settings
    msgf_settings             = results.msgf_settings
    idx_settings              = results.idx_settings
    enzyme_setting            = results.enzyme_setting
    luciphor_settings         = results.luciphor_settings
    spectra_files             = results.spectra_files


    version                   = ch_versions
}
