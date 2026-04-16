process PBP_TYPER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pbptyper:1.0.2--hdfd78af_0':
        'biocontainers/pbptyper:1.0.2--hdfd78af_0' }"

    input:
    tuple val(meta), path(fasta)
    path(db)

    output:
    tuple val(meta), path("${prefix}.tsv"), emit: tsv
    tuple val(meta), path("*.tblastn.tsv"), emit: blast
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def db_args = db ? '--db ${db}' : ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    pbptyper \\
        $db_args \\
        $args \\
        --prefix $prefix \\
        --assembly $fasta \\
        --min_pident 95 \\
        --min_coverage 95 \\
        --outdir .
    cut -f 2 $prefix.tsv | tail -n 1 > pbptype.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbptyper: \$(echo \$(pbptyper --version 2>&1) | sed 's/^.*pbptyper, version //;' )
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    touch ${prefix}-1A.tblastn.tsv
    touch ${prefix}-2B.tblastn.tsv
    touch ${prefix}-2X.tblastn.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbptyper: \$(echo \$(pbptyper --version 2>&1) | sed 's/^.*pbptyper, version //;' )
    END_VERSIONS
    """
}
