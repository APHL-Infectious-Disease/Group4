/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// Subworkflows
include { INPUT_CHECK           } from '../subworkflows/local/input_check'
include { PBP_EMM               } from '../subworkflows/local/pbp_emm'
include { VIRULENCE_ANALYSIS    } from '../subworkflows/local/virulence'


// Modules
include { REJECTED_SAMPLES       } from '../modules/local/rejected_samples/rejected_samples'
include { FASTP                  } from '../modules/local/fastp/fastp'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_gas_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Containerize just the perl scripts

workflow GAS {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    if (params.input) {
            ch_input = file(params.input)
            }
    else {
        exit 1, 'Input samplesheet not specified!'
        }

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )

    //
    // Removing Empty Samples: set up to be healthomics compatible
    //
    INPUT_CHECK.out.reads
        .branch{ meta, _file ->
            single_end: meta.single_end
            paired_end: !meta.single_end
            }
        .set{ ch_filtered }

    ch_filtered.paired_end
        .map{ meta, file ->
            [meta, file, file[0].countFastq(), file[1].countFastq()]}
        .branch{ _meta, _file, count1, count2 ->
            pass: count1 > 0 && count2 > 0
            fail: count1 == 0 || count2 == 0 || count1 == 0 && count2 == 0
            }
        .set{ ch_paired_end }

    ch_paired_end.pass
        .map { meta, file, _count1, _count2 ->
            [meta, file]
            }
        .set{ ch_fully_filtered }

    ch_paired_end.fail
        .map { meta, _file, _count1, _count2 ->
            [meta.id]
            }
        .set{ ch_paired_end_fail }

    ch_paired_end_fail
        .flatten()
        .set{ ch_failed }

    ch_failed
        .ifEmpty{'NO_EMPTY_SAMPLES'}
        .collectFile(
                name: 'empty_samples.csv',
                newLine: true
            )
        .set{ ch_rejected_file }

    //
    // Rejected samples modules, healthomics compatible
    //
    REJECTED_SAMPLES (
        ch_rejected_file,
        "GAS"
    )

    ch_fully_filtered
        .branch { item ->
            ntc: !!(item[0]['id'] =~ params.ntc_regex)
            sample: true
        }
        .set{ ch_input_reads }

    if (params.ntc_regex != null) {
        ch_paired_end.fail
            .map { meta, _file, _count1, _count2 ->
                [meta.id]
                }
            .set{ ch_ntc_check }

        ch_ntc_check
            .branch { item ->
                ntc: !!(item =~ params.ntc_regex)
                sample: true
                }
            .set { ch_ntc_check }

        ch_ntc_check.ntc
            .collect()
            .ifEmpty("Empty")
            .set { ch_empty_ntc }
        } else  {
        ch_empty_ntc = channel.value("Empty")
    }

    //
    // FASTP on raw reads
    //
    FASTP (
        ch_input_reads
        )
    ch_versions = ch_versions.mix(FASTP.out.versions())

    //
    // SUBWORKFLOW: pbp and emm typing
    //
    PBP_EMM (
        ch_input_reads
    )

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'gas_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
