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
        .map { create_meta_channel(it, is_sdrf) }
        .set { results }
    } else {
        exp_file = Channel.fromPath(exp_file, checkIfExists: true)
        exp_file.splitCsv(header: true, sep: '\t')
        .map { create_meta_channel(it, is_sdrf) }
        .set { results }
    }

    emit:
    results                     // [meta, [spectra_files ]]
    ch_expdesign    = SDRFPARSING.out.ch_expdesign

    version         = ch_versions
}

// Function to get list of [meta, [ spectra_files ]]
//
def create_meta_channel(LinkedHashMap row, is_sdrf) {
    def meta = [:]
    def array = []

    if (!is_sdrf) {
        filestr                         = row.Spectra_Filepath.toString()
        meta.id                         = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))
        meta.label                      = params.label
        meta.dissociationmethod         = params.fragment_method
        meta.fixedmodifications         = params.fixed_mods
        meta.variablemodifications      = params.variable_mods
        meta.precursormasstolerance     = params.precursor_mass_tolerance
        meta.precursormasstoleranceunit = params.precursor_mass_tolerance_unit
        meta.fragmentmasstolerance      = params.fragment_mass_tolerance
        meta.fragmentmasstoleranceunit  = params.fragment_mass_tolerance_unit
        meta.enzyme                     = params.enzyme

        if ((!file(row.Spectra_Filepath).exists())) {
            exit 1, "ERROR: Please check input file -> File Uri does not exist!\n${row.Spectra_Filepath}"
        }
        array = [meta, file(row.Spectra_Filepath)]
    } else {
        meta.id                         = row.toString().md5()
        meta.label                      = row.Label
        meta.dissociationmethod         = row.DissociationMethod
        meta.fixedmodifications         = row.FixedModifications
        meta.variablemodifications      = row.VariableModifications
        meta.precursormasstolerance     = row.PrecursorMassTolerance
        meta.precursormasstoleranceunit = row.PrecursorMassToleranceUnit
        meta.fragmentmasstolerance      = row.FragmentMassTolerance
        meta.fragmentmasstoleranceunit  = row.FragmentMassToleranceUnit
        meta.enzyme                     = row.Enzyme

        if (!params.root_folder){
            if ((!file(row.URI).exists())) {
                exit 1, "ERROR: Please check input file -> File Uri does not exist!\n${row.URI}"
            }
            array = [meta, file(row.URI)]
        } else {
            if (!file(params.root_folder + "/"
                + (params.local_input_type ? row.Filename.take(row.Filename.lastIndexOf('.'))
                + '.' + params.local_input_type : row.Filename))) {
                exit 1, "ERROR: Please check input file -> File Path does not exist!\n${row.URI}"
            } else {
                array = [meta, file(params.root_folder + "/"
                    + (params.local_input_type ? row.Filename.take(row.Filename.lastIndexOf('.'))
                    + '.' + params.local_input_type : row.Filename))]
            }
        }
    }

    return array
}
