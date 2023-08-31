//
// Extract psm feature and ReScoring psm
//

include { EXTRACTPSMFEATURES             } from '../../modules/local/openms/extractpsmfeatures/main'
include { PERCOLATOR                     } from '../../modules/local/openms/thirdparty/percolator/main'
include { FALSEDISCOVERYRATE as FDRIDPEP } from '../../modules/local/openms/falsediscoveryrate/main'
include { IDPEP                          } from '../../modules/local/openms/idpep/main'

workflow PSMRESCORING {
    take:
    ch_id_files

    main:
    ch_versions = Channel.empty()
    ch_results  = Channel.empty()
    ch_fdridpep = Channel.empty()

    if (params.posterior_probabilities == 'percolator') {
        ch_id_files.branch{ meta, filename ->
            sage: filename.name.contains('sage')
                return [meta, filename]
            nosage: true
                return [meta, filename]
        }.set{ch_id_files_branched}
        EXTRACTPSMFEATURES(ch_id_files_branched.nosage)
        ch_id_files_feats = ch_id_files_branched.sage.mix(EXTRACTPSMFEATURES.out)
        ch_versions = ch_versions.mix(EXTRACTPSMFEATURES.out.version)
        PERCOLATOR(ch_id_files_feats)
        ch_versions = ch_versions.mix(PERCOLATOR.out.version)
        ch_results = PERCOLATOR.out.id_files_perc
    }

    if (params.posterior_probabilities != 'percolator') {
        if (params.search_engines.split(",").size() == 1) {
            FDRIDPEP(ch_id_files)
            ch_versions = ch_versions.mix(FDRIDPEP.out.version)
            ch_id_files = Channel.empty()
            ch_fdridpep = FDRIDPEP.out.id_files_idx_ForIDPEP_FDR
        }
        IDPEP(ch_fdridpep.mix(ch_id_files))
        ch_versions = ch_versions.mix(IDPEP.out.version)
        ch_results = IDPEP.out.id_files_ForIDPEP
    }

    emit:
    results = ch_results

    versions = ch_versions
}
