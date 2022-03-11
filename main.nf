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
