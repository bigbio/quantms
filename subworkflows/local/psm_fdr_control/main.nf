//
// fdr control based on psm/peptide
//

include { ID_FILTER               } from '../../../modules/local/openms/id_filter/main'

workflow PSM_FDR_CONTROL {

    take:
    ch_id_files

    main:
    ch_version = channel.empty()
    ch_idfilter = channel.empty()

    ID_FILTER(ch_id_files.combine(channel.value("-score:type_peptide q-value")))
    ch_version = ch_version.mix(ID_FILTER.out.versions)
    ch_idfilter = ID_FILTER.out.id_filtered

    emit:
    id_filtered = ch_idfilter
    versions = ch_version
}
