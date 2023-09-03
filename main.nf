#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/quantms
========================================================================================
    Github : https://github.com/nf-core/quantms
    Website: https://nf-co.re/quantms
    Slack  : https://nfcore.slack.com/channels/quantms
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

include { validateParameters; paramsHelp } from 'plugin/nf-validation'

// Print help message if needed
if (params.help) {
    def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
    def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
    def String command = "nextflow run ${workflow.manifest.name} --input input_files.sdrf.tsv --database ~/dbs/human_fasta.fasta -profile docker"
    log.info logo + paramsHelp(command) + citation + NfcoreTemplate.dashedLine(params.monochrome_logs)
    System.exit(0)
}

// Validate input parameters
if (params.validate_params) {
    validateParameters()
}

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { QUANTMS } from './workflows/quantms'


//
// WORKFLOW: Run main nf-core/quantms analysis pipeline
//

workflow NFCORE_QUANTMS {
    QUANTMS ()
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_QUANTMS ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
