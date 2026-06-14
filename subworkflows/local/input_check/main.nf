//
// Check input SDRF and get read channels
//

include { SAMPLESHEET_CHECK } from '../../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    input_file

    main:

    ch_software_versions = channel.empty()

    SAMPLESHEET_CHECK ( input_file, params.validate_ontologies )
    ch_software_versions = ch_software_versions.mix(SAMPLESHEET_CHECK.out.versions)

    emit:
    ch_input_file   = SAMPLESHEET_CHECK.out.checked_file
    versions	    = ch_software_versions
}
