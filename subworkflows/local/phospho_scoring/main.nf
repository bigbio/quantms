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
    ch_version = Channel.empty()
    if (params.search_engines.split(",").size() != 1){
        ID_SCORE_SWITCHER(ch_id_files.combine(Channel.value("\"Posterior Error Probability_score\"")))
        ch_version = ch_version.mix(ID_SCORE_SWITCHER.out.versions)
        ONSITE(ch_mzml_files.join(ID_SCORE_SWITCHER.out.id_score_switcher))
        ch_version = ch_version.mix(ONSITE.out.versions)
    } else{
        ONSITE(ch_mzml_files.join(ch_id_files))
        ch_version = ch_version.mix(ONSITE.out.versions)
    }



    emit:
    id_onsite = ONSITE.out.ptm_in_id_onsite

    versions = ch_version
}
