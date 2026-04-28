process MLST {
  tag           "${meta.id}"
  label         "process_medium"
  container     'staphb/mlst:2.32.2'

  input:
  tuple val(meta), file(contig)

  output:
  tuple val(meta), file("mlst/*_mlst.tsv"), emit: mlst_files, optional: true
  path "versions.yml", emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def args   = task.ext.args   ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
    mkdir -p mlst

    #create output header
    echo -e "Filename\tScheme\tSequence_Type\tgki\tgtr\tmurI\tmutS\trecP\txpt\tyqiL" > mlst/${prefix}_ts_mlst.tsv

    mlst \
        --nopath \
        --scheme spyogenes \
        --novel ${prefix}_novel_mlst_alleles.fasta \
        ${contig} \
        >> mlst/${prefix}_ts_mlst.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$( echo \$(mlst --version 2>&1) | sed 's/mlst //' )
        scheme_db_date: 2026-01-13
    END_VERSIONS
  """
}
