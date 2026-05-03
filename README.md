# APHL/gas

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.5.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.5.2)

### Table of Contents:
[Usage](#using-the-workflow)  
[Input](#input)  
[Parameters](#parameters)  
[Workflow outline](#workflow-outline)  
[Output](#output-files)  
[Credits](#credits)  
[Contributions and Support](#contributions-and-support)  
[Citations](#citations) 

### Using the workflow
The pipeline is designed to start from raw, paired-end Illumina reads. Start the pipeline using:
```
nextflow run APHLInfectious-Disease/Group4/main.nf --input [path-to-samplesheet] --outdir [path-to-outdir] -profile [docker,singularity,aws]
```

or from github using:
```
nextflow run APHLInfectious-Disease/Group4 -r [version] --input [path-to-samplesheet] --outdir [path-to-outdir] -profile [docker,singularity,aws]
```

### Input
GAS's inputs are paired Illumina FASTQ files for each sample and a comma separated sample sheet containing the sample name, the path to the forward reads file, and the path to the reverse reads file for each sample. A sample sheet can be created using the [fastq_dir_to_samplesheet.py](https://github.com/wslh-bio/SPNtypeID/blob/main/bin/fastq_dir_to_samplesheet.py) script or by hand.  An example of the sample sheet's format can be seen in the table below and found [here](https://raw.githubusercontent.com/wslh-bio/SPNtypeID/main/samplesheets/workflow_test.csv).

| sample  | fastq_1 | fastq_2 |
| ------------- | ------------- | ------------- |
| sample_name  | /path/to/sample_name_R1.fastq.gz | /path/to/sample_name_R2.fastq.gz |


### Parameters

| Parameter | Parameter description and defaults | Example usage |
| ------------- | ------------- | ------------- |
| input | Path to comma-separated file containing information about the samples in the experiment | --input <PATH_TO_SAMPLESHEET> |
| outdir | Output directory where the results will be saved. Absolute path must be used for storage on cloud infrastructure | --outdir <DESIRED_OUTPUT_PATH> |
| profile | Denotes how to access containerized software. | -profile aws |
| fasta | Reference fasta used for alignment based comparisons. Default is random fasta from outbreak group. | --fasta <PATH_TO_REF_FASTA> |
| task.cpus | Denotes how many cpus to use for Mashtree. Default task.cpus is 2. |--task.cpus 4 |
| cg_tree_model | Tells IQ-TREE what [model](http://www.iqtree.org/doc/Substitution-Models) to use. Default cg_tree_model is GTR+G | --cg_tree_model "GTR+G" |
| parsnp_partition | Tells parsnp the minimum partition amount or to not partition. Default is --no-partition.* | --parsnp_partition "--min-partition-size 50" |
| add_reference | Used to include reference in outputs. This option should not be used if you are using --fasta random. Default is false | --add_reference |
| minimum_reads | Minimum amount of reads for fastp | --minimum_reads 1000 |

*If you are running an alignment based workflow on >100 samples, it may be beneficial to take into account a higher partitioning value than the default of 100. More information can be found in parsnp 2.0's [paper](https://pubmed.ncbi.nlm.nih.gov/38352342/#:~:text=Parsnp%20v2%20provides%20users%20with,combined%20into%20a%20final%20alignment.).

### Workflow outline

![workflow]('/assets/GAS_Workflow.png')

### Output files
Example of pipeline output:
```
live_demo/
├── compare
│   └── sample_exclusion_status.csv
├── emm
│   ├── emmtyper
│   │   ├── SAMPLE1_emmtyper.tsv
│   └── logs
│       └── APHL_GAS:GAS:EMM_MLST:EMM_TYPER
│           └── SAMPLE1.log
├── fastp
│   ├── fastp
│   │   ├── SAMPLE1_fastp.html
│   │   ├── SAMPLE1_fastp.json
│   │   ├── SAMPLE1_fastp_R1.fastq.gz
│   │   ├── SAMPLE1_fastp_R2.fastq.gz
│   └── logs
│       └── APHL_GAS:GAS:FASTP
│           ├── SAMPLE1.log
│           └── SAMPLE1.err
├── mlst
│   └── mlst
│       └── SAMPLE1.tsv
├── par
│   └── parsnp.snps.mblocks.treefile
├── parse
│   └── aligner_log.tsv
├── parsnp
│   └── parsnp_output
│       ├── config
│       │   ├── all.mumi
│       │   └── all_mumi.ini
│       ├── log
│       ├── parsnpAligner.ini
│       ├── parsnp.ggr
│       ├── parsnp.maf
│       ├── parsnp.snps.mblocks
│       ├── parsnp.tree
│       ├── parsnp.xmfa
│       └── REFERENCE.contigs.fa.ref
├── pipeline_info
├── quast
│   ├── quast_results.tsv
│   ├── SAMPLE1.quast.report.tsv
│   └── SAMPLE1.transposed.quast.report.tsv
├── rejected
│   └── GAS_empty_samples.csv
├── remove
│   └── cleaned_parsnp.snps.mblocks
├── shovill
│   ├── SAMPLE1.contigs.fa
│   ├── SAMPLE1.sam
│   ├── SAMPLE1
│   │   ├── shovill.corrections
│   │   ├── shovill.log
│   │   └── skesa.fasta
├── ska
│   └── ska_alignment.aln.treefile
├── ska2
│   ├── logs
│   │   └── APHL_GAS:GAS:EMM_MLST:SKA2
│   │       └── ska.log
│   └── ska
│       ├── ska_alignment.aln
│       └── ska_index.skf
└── snpdists
    └── snp_dists_matrix.tsv
```
> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

## Credits
APHL_InfectiousDisease/gas was originally written by Eva Gunawan, April Estrada., and Erin Young

We thank the following people for their extensive assistance in the development of this pipeline:
APHL Hackathon 2026
Matthew Geniza
Michael Ige
Nick Rhoades

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use APHL/gas for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
