//
// Phospho modification site localisation and scoring.
//

params.idscoreswitcher_for_luciphor = [:]
params.luciphor = [:]

include { IDSCORESWITCHER as IDSCORESWITCHERFORLUCIPHOR } from '../../modules/local/openms/idscoreswitcher/main' addParams( options: params.idscoreswitcher_for_luciphor)
include { LUCIPHORADAPTER } from '../../modules/local/openms/thirdparty/luciphoradapter/main' addParams( options: params.luciphor )

workflow PHOSPHOSCORING {
    take:
    mzml_files
    id_files

    main:
    ch_version = Channel.empty()

    IDSCORESWITCHERFORLUCIPHOR(id_files.combine(val("Posterior Error Probability_score")))
    ch_version = ch_version.mix(IDSCORESWITCHERFORLUCIPHOR.out.version)

    LUCIPHORADAPTER(mzml_files.join(IDSCORESWITCHERFORLUCIPHOR.out.id_score_switcher))
    ch_version = ch_version.mix(LUCIPHORADAPTER.out.version)

    emit:
    id_luciphor = LUCIPHORADAPTER.out.ptm_in_id_luciphor

    version = ch_version
}
