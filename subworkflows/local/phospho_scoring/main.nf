//
// Phospho modification site localisation and scoring.
//

include { ID_SCORE_SWITCHER } from '../../../modules/local/openms/id_score_switcher/main'
include { ONSITE            } from '../../../modules/bigbio/onsite/main'

workflow PHOSPHO_SCORING {
    take:
    ch_mzml_files
    ch_id_files

    main:
    ch_version = channel.empty()

    ONSITE(ch_mzml_files.join(ch_id_files))
    ch_version = ch_version.mix(ONSITE.out.versions)


    emit:
    id_onsite = ONSITE.out.ptm_in_id_onsite

    versions = ch_version
}
