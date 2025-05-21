//
// Phospho modification site localisation and scoring.
//

include { ID_SCORE_SWITCHER as ID_SCORE_SWITCHER_LUCIPHOR } from '../../../modules/local/openms/id_score_switcher/main'
include { LUCIPHOR                               } from '../../../modules/local/openms/thirdparty/luciphor/main'

workflow PHOSPHO_SCORING_WORKFLOW {
    take:
    ch_mzml_files
    ch_id_files

    main:
    ch_version = Channel.empty()

    ID_SCORE_SWITCHER_LUCIPHOR(ch_id_files.combine(Channel.value("\"Posterior Error Probability_score\"")))
    ch_version = ch_version.mix(ID_SCORE_SWITCHER_LUCIPHOR.out.versions)

    LUCIPHOR(ch_mzml_files.join(ID_SCORE_SWITCHER_LUCIPHOR.out.id_score_switcher))
    ch_version = ch_version.mix(LUCIPHOR.out.versions)

    emit:
    id_luciphor = LUCIPHOR.out.ptm_in_id_luciphor

    versions = ch_version
}
