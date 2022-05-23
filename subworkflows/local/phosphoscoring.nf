//
// Phospho modification site localisation and scoring.
//

include { IDSCORESWITCHER as IDSCORESWITCHERFORLUCIPHOR } from '../../modules/local/openms/idscoreswitcher/main'
include { LUCIPHORADAPTER } from '../../modules/local/openms/thirdparty/luciphoradapter/main'

workflow PHOSPHOSCORING {
    take:
    ch_mzml_files
    ch_id_files

    main:
    ch_version = Channel.empty()

    IDSCORESWITCHERFORLUCIPHOR(ch_id_files.combine(Channel.value("\"Posterior Error Probability_score\"")))
    ch_version = ch_version.mix(IDSCORESWITCHERFORLUCIPHOR.out.version)

    LUCIPHORADAPTER(ch_mzml_files.join(IDSCORESWITCHERFORLUCIPHOR.out.id_score_switcher))
    ch_version = ch_version.mix(LUCIPHORADAPTER.out.version)

    emit:
    id_luciphor = LUCIPHORADAPTER.out.ptm_in_id_luciphor

    version = ch_version
}
