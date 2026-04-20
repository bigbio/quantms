//
// Extract psm feature and ReScoring psm
//

include { PERCOLATOR              } from '../../../modules/local/openms/percolator/main'


workflow PSM_RESCORING {
    take:
    ch_file_preparation_results
    ch_id_files_feats
    _ch_expdesign

    main:
    ch_software_versions = channel.empty()

    PERCOLATOR(ch_id_files_feats)
    ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
    ch_rescoring_results = PERCOLATOR.out.id_files_perc

    emit:
    results = ch_rescoring_results
    versions = ch_software_versions
}
