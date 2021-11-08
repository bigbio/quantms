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

if (params.quant_method == 'TMT') {
    include { TMT } from './workflows/tmt'
} else if (params.quant_method == 'LFQ') {
    include { LFQ } from './workflows/lfq'
}


//
// WORKFLOW: Run main nf-core/quantms analysis pipeline
//

workflow NFCORE_QUANTMS {
    if (params.quant_method == 'TMT') {
        TMT()
    } else if (params.quant_method == 'LFQ') {
        LFQ()
    }
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
