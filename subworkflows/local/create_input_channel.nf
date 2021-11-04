//
// Create channel for input file
//

params.sdrfparsing_options = [:]

include { SDRFPARSING } from '../../modules/local/sdrfparsing/main' addParams( options: params.sdrfparsing_options)

workflow CREATE_INPUT_CHANNEL {
    take:
    sdrf_file
    spectra_files

    main:
    ch_versions = Channel.empty()

    if (sdrf_file) {
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
            luciphor_settings: tuple(id, row.DissociationMethod)
            mzmls: tuple(id, !params.root_folder ? row.URI : params.root_folder + "/"
                + (params.local_input_type ? row.Filename.take(row.Filename.lastIndexOf('.'))
                + '.' + params.local_input_type : row.Filename))
        }
        .set{ results }
    } else {
        ch_spectra = Channel.fromPath(spectra_files, checkIfExists: true)
        ch_spectra
        .multiMap{ it -> id = it.toString().md5()
            isobaricanalyzer_settings: tuple(id, params.label, params.fragment_method)
            comet_settings: msgf_settings: tuple(id, params.fixed_mods, params.variable_mods,
                params.precursor_mass_tolerance, params.precursor_mass_tolerance_unit,
                params.fragment_mass_tolerance, params.fragment_mass_tolerance_unit,
                params.fragment_method, params.enzyme
            )
            idx_settings: tuple(id, params.enzyme)
            luciphor_settings: tuple(id, params.fragment_method)
            mzmls: tuple(id, it)
        }
        .set{ results }
    }

    //
    // Divide mzml files
    //
    results.mzmls
    .branch {
        raw: WorkflowQuantms.hasExtension(it[1], 'raw')
        mzML: WorkflowQuantms.hasExtension(it[1], 'mzML')
    }
    .set {branched_input}

    //TODO we could also check for outdated mzML versions and try to update them
    branched_input.mzML
    .branch {
        nonIndexedMzML: file(it[1]).withReader {
            f = it; 1.upto(5) {
                if (f.readLine().contains("indexedmzML")) return false;
            }
                return true;
        }
        inputIndexedMzML: file(it[1]).withReader {
            f = it; 1.upto(5) {
                if (f.readLine().contains("indexedmzML")) return true;
            }
                return false;
        }
    }
    .set {branched_input_mzMLs}

    emit:
    isobaricanalyzer_settings = results.isobaricanalyzer_settings
    comet_settings            = results.comet_settings
    msgf_settings             = results.msgf_settings
    idx_settings              = results.idx_settings
    luciphor_settings         = results.luciphor_settings
    nonIndexedMzML            = branched_input_mzMLs.nonIndexedMzML
    inputIndexedMzML          = branched_input_mzMLs.inputIndexedMzML
    rawfiles                  = branched_input.raw


    version                   = ch_versions
}
