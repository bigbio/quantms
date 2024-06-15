//
// MODULE: Local to the pipeline
//
include { DECOYDATABASE } from '../../modules/local/openms/decoydatabase/main'
include { CONSENSUSID   } from '../../modules/local/openms/consensusid/main'
include { EXTRACTPSMFEATURES } from '../../modules/local/openms/extractpsmfeatures/main'
include { PERCOLATOR         } from '../../modules/local/openms/thirdparty/percolator/main'
include { IDMERGER           } from '../../modules/local/openms/idmerger/main'
include { IDRIPPER           } from '../../modules/local/openms/idripper/main'
include { FALSEDISCOVERYRATE as FDRIDPEP } from '../../modules/local/openms/falsediscoveryrate/main'
include { IDPEP                          } from '../../modules/local/openms/idpep/main'
include { PSMCONVERSION                  } from '../../modules/local/extract_psm/main'
include { MS2RESCORE                     } from '../../modules/local/ms2rescore/main'
include { IDSCORESWITCHER                } from '../../modules/local/openms/idscoreswitcher/main'
include { GETSAMPLE                      } from '../../modules/local/extract_sample/main'
include { SAGEFEATURE                    } from '../../modules/local/add_sage_feat/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { DATABASESEARCHENGINES } from './databasesearchengines'
include { PSMFDRCONTROL         } from './psmfdrcontrol'

workflow DDA_ID {
    take:
    ch_file_preparation_results
    ch_database_wdecoy
    ch_spectrum_data
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    DATABASESEARCHENGINES (
        ch_file_preparation_results,
        ch_database_wdecoy
    )
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versions.ifEmpty(null))
    ch_id_files = DATABASESEARCHENGINES.out.ch_id_files_idx

    ch_id_files.branch{ meta, filename ->
        sage: filename.name.contains('sage')
            return [meta, filename]
        nosage: true
            return [meta, filename, []]
    }.set{ch_id_files_branched}

    ch_pmultiqc_consensus = Channel.empty()
    ch_pmultiqc_ids = Channel.empty()

    //
    // SUBWORKFLOW: Rescoring
    //
    if (params.skip_rescoring == false) {
        if (params.posterior_probabilities == 'percolator') {
            if (params.ms2rescore == true) {
                MS2RESCORE(ch_id_files.combine(ch_file_preparation_results, by: 0))
                ch_software_versions = ch_software_versions.mix(MS2RESCORE.out.versions)

                MS2RESCORE.out.idxml.join(MS2RESCORE.out.feature_names).branch{ meta, idxml, feature_name ->
                    sage: idxml.name.contains('sage')
                        return [meta, idxml, feature_name]
                    nosage: true
                        return [meta, idxml, feature_name]
                }.set{ch_ms2rescore_branched}

                EXTRACTPSMFEATURES(ch_ms2rescore_branched.nosage)
                SAGEFEATURE(ch_ms2rescore_branched.sage)
                ch_id_files_feats = EXTRACTPSMFEATURES.out.id_files_feat.mix(SAGEFEATURE.out.id_files_feat)
                ch_software_versions = ch_software_versions.mix(EXTRACTPSMFEATURES.out.version)
            } else {
                EXTRACTPSMFEATURES(ch_id_files_branched.nosage)
                ch_id_files_feats = ch_id_files_branched.sage.mix(EXTRACTPSMFEATURES.out.id_files_feat)
                ch_software_versions = ch_software_versions.mix(EXTRACTPSMFEATURES.out.version)
            }

            // Rescoring for independent run, Sample or whole experiments
            if (params.rescore_range == "independent_run") {
                PERCOLATOR(ch_id_files_feats)
                ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.version)
                ch_consensus_input = PERCOLATOR.out.id_files_perc
            } else if (params.rescore_range == "by_sample") {
                // Sample map
                GETSAMPLE(ch_expdesign)
                ch_expdesign_sample = GETSAMPLE.out.ch_expdesign_sample
                ch_expdesign_sample.splitCsv(header: true, sep: '\t')
                    .map { get_sample_map(it) }.set{ sample_map_idv }

                sample_map = sample_map_idv.collect().map{ all_sample_map( it ) }

                // Group by search_engines and convert meta
                ch_id_files_feats.combine( sample_map ).branch{ meta, filename, sample_map  ->
                    sage: filename.name.contains('sage')
                        return [convert_exp_meta(meta, "sample_id", filename, sample_map), filename]
                    msgf: filename.name.contains('msgf')
                        return [convert_exp_meta(meta, "sample_id", filename, sample_map), filename]
                    comet: filename.name.contains('comet')
                        return [convert_exp_meta(meta, "sample_id", filename, sample_map), filename]
                }.set{ch_id_files_feat_branched}

                // IDMERGER for samples group
                IDMERGER(ch_id_files_feat_branched.comet.groupTuple(by: 0)
                    .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 0))
                    .mix(ch_id_files_feat_branched.sage.groupTuple(by: 0)))
                ch_software_versions = ch_software_versions.mix(IDMERGER.out.version)

                PERCOLATOR(IDMERGER.out.id_merged)
                ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.version)

                // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
                IDRIPPER(PERCOLATOR.out.id_files_perc)
                IDRIPPER.out.meta.first().combine(IDRIPPER.out.id_rippers.flatten())
                    .map{ [convert_exp_meta(it[0], "mzml_id", it[1], ""), it[1], "MS:1001491"] }
                    .set{ ch_consensus_input }
                ch_software_versions = ch_software_versions.mix(IDRIPPER.out.version)

            } else if (params.rescore_range == "by_project"){
                // Split ch_id_files_feats by search_engines
                ch_id_files_feats.branch{ meta, filename ->
                    sage: filename.name.contains('sage')
                        return [convert_exp_meta(meta, "experiment_id", filename, ""), filename]
                    msgf: filename.name.contains('msgf')
                        return [convert_exp_meta(meta, "experiment_id", filename, ""), filename]
                    comet: filename.name.contains('comet')
                        return [convert_exp_meta(meta, "experiment_id", filename, ""), filename]
                }.set{ch_id_files_feat_branched}

                // IDMERGER for whole experiments
                IDMERGER(ch_id_files_feat_branched.comet.groupTuple(by: 0)
                    .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 0))
                    .mix(ch_id_files_feat_branched.sage.groupTuple(by: 0)))
                ch_software_versions = ch_software_versions.mix(IDMERGER.out.version)

                PERCOLATOR(IDMERGER.out.id_merged)
                ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.version)

                // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
                IDRIPPER(PERCOLATOR.out.id_files_perc)
                IDRIPPER.out.meta.first().combine(IDRIPPER.out.id_rippers.flatten())
                    .map{ [convert_exp_meta(it[0], "mzml_id", it[1], ""), it[1], "MS:1001491"] }
                    .set{ ch_consensus_input }
                ch_software_versions = ch_software_versions.mix(IDRIPPER.out.version)

            }

        ch_rescoring_results = ch_consensus_input

        } else if (params.posterior_probabilities == 'mokapot') {
            MS2RESCORE(ch_id_files.combine(ch_file_preparation_results, by: 0))
            ch_software_versions = ch_software_versions.mix(MS2RESCORE.out.versions)
            IDSCORESWITCHER(MS2RESCORE.out.idxml.combine(Channel.value("PEP")))
            ch_software_versions = ch_software_versions.mix(IDSCORESWITCHER.out.version)
            ch_consensus_input = IDSCORESWITCHER.out.id_score_switcher.combine(Channel.value("MS:1001491"))
            ch_rescoring_results = IDSCORESWITCHER.out.ch_consensus_input
        } else {
            ch_fdridpep = Channel.empty()
            if (params.search_engines.split(",").size() == 1) {
                FDRIDPEP(ch_id_files)
                ch_software_versions = ch_software_versions.mix(FDRIDPEP.out.version)
                ch_id_files = Channel.empty()
                ch_fdridpep = FDRIDPEP.out.id_files_idx_ForIDPEP_FDR
            }
            IDPEP(ch_fdridpep.mix(ch_id_files))
            ch_software_versions = ch_software_versions.mix(IDPEP.out.version)
            ch_consensus_input = IDPEP.out.id_files_ForIDPEP
            ch_rescoring_results = ch_consensus_input
        }

        //
        // SUBWORKFLOW: PSMFDRCONTROL
        //
        ch_psmfdrcontrol     = Channel.empty()
        ch_consensus_results = Channel.empty()
        if (params.search_engines.split(",").size() > 1) {
            CONSENSUSID(ch_consensus_input.groupTuple(size: params.search_engines.split(",").size()))
            ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.version.ifEmpty(null))
            ch_psmfdrcontrol = CONSENSUSID.out.consensusids
            ch_psmfdrcontrol
                .map { it -> it[1] }
                .set { ch_pmultiqc_consensus }
        } else {
            ch_psmfdrcontrol = ch_consensus_input
        }

        PSMFDRCONTROL(ch_psmfdrcontrol)
        ch_software_versions = ch_software_versions.mix(PSMFDRCONTROL.out.version.ifEmpty(null))

        // Extract PSMs and export parquet format
        PSMCONVERSION(PSMFDRCONTROL.out.id_filtered.combine(ch_spectrum_data, by: 0))

        ch_rescoring_results
            .map { it -> it[1] }
            .set { ch_pmultiqc_ids }
    } else {
        PSMCONVERSION(ch_id_files.combine(ch_spectrum_data, by: 0))
    }


    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    version                 = ch_software_versions
}

// Function to group by mzML/sample/experiment
def convert_exp_meta(Map meta, value, file_name, sample_map) {
    def exp_meta = [:]

    if (value == "experiment_id") {
        exp_meta.mzml_id = meta.experiment_id
    } else if (value == "mzml_id") {
        position = file(file_name).name.lastIndexOf('_sage_perc.idXML')
        if (position == -1) {
            position = file(file_name).name.lastIndexOf('_comet_perc.idXML')
            if (position == -1) {
                position = file(file_name).name.lastIndexOf('_msgf_perc.idXML')
            }
        }
        exp_meta.mzml_id = file(file_name).name.take(position)
    } else if (value == "sample_id") {
        tag = file(file_name).name.lastIndexOf('_perc.idXML')
        if (tag == -1) {
            position = file(file_name).name.lastIndexOf('_sage.idXML')
            if (position == -1) {
                position = file(file_name).name.lastIndexOf('_comet_feat.idXML')
                if (position == -1) {
                    position = file(file_name).name.lastIndexOf('_msgf_feat.idXML')
                }
            }
        } else {
            position = file(file_name).name.lastIndexOf('_sage_perc.idXML')
            if (position == -1) {
                position = file(file_name).name.lastIndexOf('_comet_perc.idXML')
                if (position == -1) {
                    position = file(file_name).name.lastIndexOf('_msgf_perc.idXML')
                }
            }
        }

        file_name = file(file_name).name.take(position)
        exp_meta.mzml_id = sample_map[file_name]
    }


    exp_meta.experiment_id              = meta.experiment_id
    exp_meta.labelling_type             = meta.labelling_type
    exp_meta.dissociationmethod         = meta.dissociationmethod
    exp_meta.fixedmodifications         = meta.fixedmodifications
    exp_meta.variablemodifications      = meta.variablemodifications
    exp_meta.precursormasstolerance     = meta.precursormasstolerance
    exp_meta.precursormasstoleranceunit = meta.precursormasstoleranceunit
    exp_meta.fragmentmasstolerance      = meta.fragmentmasstolerance
    exp_meta.fragmentmasstoleranceunit  = meta.fragmentmasstoleranceunit
    exp_meta.enzyme                     = meta.enzyme
    exp_meta.acquisition_method         = meta.acquisition_method

    return exp_meta
}

// Function to get sample map
def get_sample_map(LinkedHashMap row) {
    def sample_map = [:]

    filestr               = row.Spectra_Filepath
    file_name             = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))
    sample                = row.Sample
    sample_map[file_name] = sample

    return sample_map

}

def all_sample_map(sample_list) {
    res = [:]
    sample_list.each {
        res = res + it
    }

    return res
}
