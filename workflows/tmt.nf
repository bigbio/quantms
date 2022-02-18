/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { CONSENSUSID } from '../modules/local/openms/consensusid/main' addParams( options: modules['consensusid'] )
include { FILEMERGE } from '../modules/local/openms/filemerge/main' addParams( options: modules['filemerge'] )

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
def epi_filter = modules['idfilter'].clone()

epi_filter.args += Utils.joinModuleArgs(["-score:prot \"$params.protein_level_fdr_cutoff\"",
                "-delete_unreferenced_peptide_hits", "-remove_decoys"])
epi_filter.suffix = ".consensusXML"

include { FEATUREMAPPER } from '../subworkflows/local/featuremapper' addParams( isobaric: modules['isobaricanalyzer'], idmapper: modules['idmapper'])
include { PROTEININFERENCE } from '../subworkflows/local/proteininference' addParams( epifany: modules['epifany'], protein_inference: modules['proteininference'], epifilter: epi_filter)
include { PROTEINQUANT } from '../subworkflows/local/proteinquant' addParams( resolve_conflict: modules['idconflictresolver'], pro_quant: modules['proteinquantifier'], msstatsconverter: modules['msstatsconverter'])


/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow TMT {

    //
    // SUBWORKFLOW: FEATUREMAPPER
    //
    FEATUREMAPPER(FILE_PREPARATION.out.results, ptmt_in_id)
    ch_software_versions = ch_software_versions.mix(FEATUREMAPPER.out.version.ifEmpty(null))

    //
    // MODULE: FILEMERGE
    //
    FILEMERGE(FEATUREMAPPER.out.id_map.collect())
    ch_software_versions = ch_software_versions.mix(FILEMERGE.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEININFERENCE
    //
    PROTEININFERENCE(FILEMERGE.out.id_merge)
    ch_software_versions = ch_software_versions.mix(PROTEININFERENCE.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEINQUANT
    //
    PROTEINQUANT(PROTEININFERENCE.out.epi_idfilter, CREATE_INPUT_CHANNEL.out.ch_expdesign)
    ch_software_versions = ch_software_versions.mix(PROTEINQUANT.out.version.ifEmpty(null))
}