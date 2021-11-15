//
// Extract psm feature and ReScoring psm
//

params.extract_psm_feature_options = [:]
params.percolator_options = [:]
params.fdridpep_options = [:]
params.idpep_options = [:]

include { EXTRACTPSMFEATURE } from '../../modules/local/openms/extractpsmfeature/main' addParams( options: params.extract_psm_feature_options )
include { PERCOLATOR } from '../../modules/local/openms/thirdparty/percolator/main' addParams( options: params.percolator_options )
include { FALSEDISCOVERYRATE as FDRIDPEP } from '../../modules/local/openms/falsediscoveryrate/main' addParams( options: params.fdridpep_options )
include { IDPEP } from '../../modules/local/openms/idpep/main' addParams( options: params.idpep_options )

workflow PSMRESCORING {
    take:
    id_files

    main:
    ch_versions = Channel.empty()
    ch_results = Channel.empty()

    if (params.posterior_probabilities == 'percolator') {
        EXTRACTPSMFEATURE(id_files)
        ch_versions = ch_versions.mix(EXTRACTPSMFEATURE.out.version)
        PERCOLATOR(EXTRACTPSMFEATURE.out.id_files_idx_feat)
        ch_versions = ch_versions.mix(PERCOLATOR.out.version)
        ch_results = PERCOLATOR.out.id_files_perc
    }

    if (params.posterior_probabilities != 'percolator') {
        if (params.search_engines.split(",").size() == 1) {
            FDRIDPEP(id_files)
            ch_versions = ch_versions.mix(FDRIDPEP.out.version)
            id_files = Channel.empty()
        }
        IDPEP(FDRIDPEP.out.id_files_idx_ForIDPEP_FDR.mix(id_files))
        ch_versions = ch_versions.mix(IDPEP.out.version)
        ch_results = IDPEP.out.id_files_ForIDPEP
    }

    emit:
    results = ch_results

    versions = ch_versions
}
