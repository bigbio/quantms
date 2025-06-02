//
// Check input sdrf and get read channels
//

include { SAMPLESHEET_CHECK } from '../../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    input_file // file: /path/to/input_file

    main:

    ch_software_versions = Channel.empty()

    if (input_file.toString().toLowerCase().contains("sdrf")) {
        is_sdrf = true
    } else {
        is_sdrf = false
        if (!params.labelling_type || !params.acquisition_method) {
            log.error "If no SDRF was given, specifying --labelling_type and --acquisition_method is mandatory."
            exit 1
        }
    }
    SAMPLESHEET_CHECK ( input_file, is_sdrf, params.validate_ontologies )
    ch_software_versions = ch_software_versions.mix(SAMPLESHEET_CHECK.out.versions)

    emit:
    ch_input_file   = SAMPLESHEET_CHECK.out.checked_file
    is_sdrf         = is_sdrf
    versions	    = ch_software_versions
}
