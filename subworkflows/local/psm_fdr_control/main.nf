//
// fdr control based on psm/peptide
//

include { FALSE_DISCOVERY_RATE as FDR_CONSENSUSID } from '../../../modules/local/openms/false_discovery_rate/main'
include { ID_FILTER as ID_FILTER                } from '../../../modules/local/openms/id_filter/main'

workflow PSM_FDR_CONTROL {

    take:
    ch_id_files

    main:
    ch_version = Channel.empty()
    ch_idfilter = Channel.empty()

    if (params.search_engines.split(",").size() == 1) {
        ID_FILTER(ch_id_files.combine(Channel.value("-score:type_peptide q-value")))
        ch_version = ch_version.mix(ID_FILTER.out.versions)
    } else {
        FDR_CONSENSUSID(ch_id_files)
        ch_version = ch_version.mix(FDR_CONSENSUSID.out.versions)
        ch_idfilter = FDR_CONSENSUSID.out.id_files_idx_ForIDPEP_FDR
    }

    emit:
    id_filtered =ID_FILTER.out.id_filtered
    versions = ch_version
}
