//
// fdr control based on psm/peptide
//

include { ID_SCORE_SWITCHER as ID_SCORE_SWITCHER } from '../../../modules/local/openms/id_score_switcher/main'
include { FALSE_DISCOVERY_RATE as FDR_CONSENSUSID } from '../../../modules/local/openms/false_discovery_rate/main'
include { ID_FILTER as ID_FILTER                } from '../../../modules/local/openms/id_filter/main'

workflow PSM_FDR_CONTROL {

    take:
    ch_id_files

    main:
    ch_version = Channel.empty()
    ch_idfilter = Channel.empty()

    if (params.search_engines.split(",").size() == 1) {
        ID_SCORE_SWITCHER(ch_id_files)
        ch_version = ch_version.mix(ID_SCORE_SWITCHER.out.versions)
        ch_idfilter = ID_SCORE_SWITCHER.out.id_score_switcher
    } else {
        FDR_CONSENSUSID(ch_id_files)
        ch_version = ch_version.mix(FDR_CONSENSUSID.out.versions)
        ch_idfilter = FDR_CONSENSUSID.out.id_files_idx_ForIDPEP_FDR
    }
    ID_FILTER(ch_idfilter)
    ch_version = ch_version.mix(ID_FILTER.out.versions)

    emit:
    id_filtered =ID_FILTER.out.id_filtered
    versions = ch_version
}
