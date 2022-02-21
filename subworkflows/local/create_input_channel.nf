//
// Create channel for input file
//
include { SDRFPARSING } from '../../modules/local/sdrfparsing/main'
include { PREPROCESS_EXPDESIGN } from '../../modules/local/preprocess_expdesign'

workflow CREATE_INPUT_CHANNEL {
    take:
    ch_sdrf_or_design
    is_sdrf

    main:
    ch_versions = Channel.empty()

    if (is_sdrf.toString().toLowerCase().contains("true")) {
        SDRFPARSING ( ch_sdrf_or_design )
        ch_versions = ch_versions.mix(SDRFPARSING.out.version)
        ch_in_design = SDRFPARSING.out.ch_sdrf_config_file

        ch_expdesign    = SDRFPARSING.out.ch_expdesign
    } else {
        PREPROCESS_EXPDESIGN( ch_sdrf_or_design )
        ch_in_design = PREPROCESS_EXPDESIGN.out.process_ch_expdesign

        ch_expdesign    = PREPROCESS_EXPDESIGN.out.ch_expdesign
    }

    Set enzymes = []
    Set files = []
    // quant_type = ""

    ch_in_design.splitCsv(header: true, sep: '\t')
            .map { create_meta_channel(it, is_sdrf, enzymes, files) }
            .set { ch_meta_config }

    emit:
    ch_meta_config                     // [meta, [spectra_files ]]
    ch_expdesign

    version         = ch_versions
}

// Function to get list of [meta, [ spectra_files ]]
def create_meta_channel(LinkedHashMap row, is_sdrf, enzymes, files) {
    def meta = [:]
    def array = []


    if (is_sdrf.toString().toLowerCase().contains("false")) {
        filestr                         = row.Spectra_Filepath.toString()
    } else {
        if (!params.root_folder) {
            filestr                     = row.URI.toString()
        } else {
            filestr                     = row.Filename.toString()
        }
    }

    meta.id                             = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))

    // apply transformations given by specified root_folder and type
    if (params.root_folder) {
        filestr = params.root_folder + File.separator + filestr
    }

    filestr = (params.local_input_type ? filestr.take(filestr.lastIndexOf('.'))
                                            + '.' + params.local_input_type
                                            : filestr)

    // existance check
    if ((!file(filestr).exists())) {
        exit 1, "ERROR: Please check input file -> File Uri does not exist!\n${filestr}"
    }

    // for sdrf read from config file, without it, read from params
    if (is_sdrf.toString().toLowerCase().contains("false")) {
        meta.labelling_type             = params.labelling_type
        meta.dissociationmethod         = params.fragment_method
        meta.fixedmodifications         = params.fixed_mods
        meta.variablemodifications      = params.variable_mods
        meta.precursormasstolerance     = params.precursor_mass_tolerance
        meta.precursormasstoleranceunit = params.precursor_mass_tolerance_unit
        meta.fragmentmasstolerance      = params.fragment_mass_tolerance
        meta.fragmentmasstoleranceunit  = params.fragment_mass_tolerance_unit
        meta.enzyme                     = params.enzyme
    } else {
        meta.labelling_type             = row.Label
        meta.dissociationmethod         = row.DissociationMethod
        meta.fixedmodifications         = row.FixedModifications
        meta.variablemodifications      = row.VariableModifications
        meta.precursormasstolerance     = row.PrecursorMassTolerance
        meta.precursormasstoleranceunit = row.PrecursorMassToleranceUnit
        meta.fragmentmasstolerance      = row.FragmentMassTolerance
        meta.fragmentmasstoleranceunit  = row.FragmentMassToleranceUnit
        meta.enzyme                     = row.Enzyme

        enzymes += row.Enzyme
        if (enzymes.size() > 1)
        {
            log.error "Currently only one enzyme is supported for the whole experiment. Specified was '${enzymes}'. Check or split your SDRF."
            log.error filestr
            exit 1
        }
    }
        if (meta.labelling_type.contains("tmt") || meta.labelling_type.contains("itraq")) {
            quant_type = "iso"
        } else if (meta.labelling_type.contains("label free")) {
            quant_type = "lfq"
        } else {
            log.error "Unsupported quantification type '${meta.labelling_type}'."
            exit 1
        }

    if (quant_type == "lfq") {
        if (filestr in files) {
            log.error "Currently only one search engine setting per file is supported for the whole experiment. ${filestr} has multiple entries in your SDRF. Maybe you have a (isobaric) labelled experiment? Otherwise, consider splitting your design into multiple experiments."
            exit 1
        }
        files += filestr
    }

    return [meta, filestr]
}
