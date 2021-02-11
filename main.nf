#!/usr/bin/env nextflow
/*
========================================================================================
                         mpozuelo/MGI_demux
========================================================================================
mpozuelo/MGI_demux Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/mpozuelo/MGI_demux
----------------------------------------------------------------------------------------
*/

def helpMessage() {
    log.info mpozueloHeader()
    log.info """

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run mpozuelo/MGI_demux --input '*.txt' -profile docker

    Mandatory arguments:
      --input [file]                Samplesheet with indexes and samples information
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: conda, docker, singularity.
      --cluster_path                Cluster path to store data and to search for input data (Default: /datos/ngs/dato-activo)

    Optional:
      --single_index                In case the sequencing has been done single index although there were two indexes (i5 and i7). Only run with i7 and avoid the second index2 removal

    Demultiplexing parameters:
      --save_untrimmed              Saves untrimmed reads when demultiplexing (Default: FALSE)

    QC:
      --skipQC                      Skip all QC steps apart from MultiQC
      --skipFastQC                  Skip FastQC

    Other options
      --outdir                      The output directory where the results will be saved
      -w/--work-dir                 The temporary directory where intermediate data will be saved
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic
    """.stripIndent()
}


// Show help message
if (params.help) {
    helpMessage()
    exit 0
}


/*
 * SET UP CONFIGURATION VARIABLES
 */


 // Has the run name been specified by the user?
 //  this has the bonus effect of catching both -name and --name
 custom_runName = params.name
 if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
   custom_runName = workflow.runName
 }
 else{
   workflow.runName = params.user + " " + params.timestamp
   custom_runName = workflow.runName
 }



// Validate inputs

if (params.input) { ch_input = file(params.input, checkIfExists: true) } else { exit 1, "Input samplesheet file not specified!" }

if (!params.outdir) {
  params.outdir = params.run
}

cluster_path = params.cluster_path


// Header log info
log.info mpozueloHeader()
def summary = [:]
if (workflow.revision) summary['Pipeline Release'] = workflow.revision
summary['Run Name'] = custom_runName ?: workflow.runName
summary['Input'] = params.input
summary['Single index'] = params.single_index
summary['Max Resources'] = "$params.max_memory memory, $params.max_cpus cpus, $params.max_time time per job"
if (workflow.containerEngine) summary['Container'] = "$workflow.containerEngine - $workflow.container"
summary['User'] = workflow.userName

summary['Config Profile'] = workflow.profile
if (params.config_profile_description) summary['Config Description'] = params.config_profile_description
if (params.config_profile_contact)     summary['Config Contact']     = params.config_profile_contact
if (params.config_profile_url)         summary['Config URL']         = params.config_profile_url
log.info summary.collect { k,v -> "${k.padRight(18)}: $v" }.join("\n")
log.info "-\033[2m--------------------------------------------------\033[0m-"


// Check the hostnames against configured profiles
checkHostname()

def create_workflow_summary(summary) {
    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'mpozuelo-MGI_demux-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'mpozuelo/MGI_demux Workflow Summary'
    section_href: 'https://github.com/mpozuelo/MGI_demux'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}



/*
 * LOAD SAMPLESHEET and assign get the columns we will use for demultiplexing

 /*
  * LOAD SAMPLESHEET and assign get the columns we will use for demultiplexing
  It contains the following columns:
 1- Name given to the sample
 2- Index
 3- Index2
 4- Barcode
 5- Run ID
 6- Lane
 7- Sequencing date
 8- Protocol
 9- Platform
 10- Sample Source (place where the samples come from)
 11- Genome
 12- User
 13- Coverage
 */



 process modify_samplesheet {
   publishDir "${params.outdir}/samplesheet/", mode: params.publish_dir_mode

   input:
   path samplesheet from ch_input

   output:
   path "samplesheet_validated.csv" into ch_samplesheet

   script:
   out = "samplesheet_validated.csv"

   """
   modify_samplesheet.py $samplesheet $out
   """
 }



 def validate_input(LinkedHashMap sample) {
   def sample_id = sample.sampleID
   def index = sample.index
   def index2 = sample.index2
   def barcode = sample.barcode
   def run = sample.run
   def lane = sample.lane
   def date = sample.date
   def protocol = sample.protocol
   def platform = sample.platform
   def source = sample.source
   def genome = sample.genome
   def user = sample.user
   def transcriptome = sample.transcriptome
   def fastq1 = sample.fastq1
   def fastq2 = sample.fastq2




   def array = []
   array = [ sample_id, [file(fastq1, checkIfExists: true), file(fastq2, checkIfExists: true)], index, run, lane, platform, user, file(transcriptome, checkIfExists: true) ]

   return array
 }

 /*
 * Create channels for input fastq files
 */
 ch_samplesheet
 .splitCsv(header:true, sep:',')
 .map { validate_input(it) }
 .into { ch_cell_ranger
         ch_fastq }


/*
 * STEP 1 - Change header and cell ranger
 */
//Detect index in the end of read2


process cell_ranger {
  tag "$sample"
  label 'process_high'
  publishDir "${cluster_path}/04_pfastq/${platform}/${run_id}/${lane}/${user}/cell_ranger/", mode: 'copy',
  saveAs: { filename ->
    filename.endsWith(".fq.gz") ? "fastq/$filename" : filename
  }

  input:
  set val(sample), file(reads), val(index), val(run_id), val(lane), val(platform), val(user), file(transcriptome) from ch_cell_ranger

  output:
  path("*_S1_L00*.fq.gz")
  path("${sample}/")


  script:
  fqheader1 = "${sample}_${run_id}_${lane}_R1_BC.fq"
  fqheader2 = "${sample}_${run_id}_${lane}_R2_BC.fq"
  gzheader1 = "${sample}_${run_id}_${lane}_R1_BC.fq.gz"
  gzheader2 = "${sample}_${run_id}_${lane}_R2_BC.fq.gz"

  // Re-write reads header to Illumina format, taking info from MGI headers
  // For this step, BC sequence is collected from header (BC was incuded in the header in previous step)

  """
  zcat ${reads[0]} | awk -v var="$index" '{if (NR%4 == 1){print \$1"_"var} else{print \$1}}' > $fqheader1 &
  zcat ${reads[1]} | awk -v var="$index" '{if (NR%4 == 1){print \$1"_"var} else{print \$1}}' > $fqheader2
  pigz -p $task.cpus $gzheader1
  pigz -p $task.cpus $gzheader2
  File_ID_new=\$(echo "${sample}" | rev | cut -c 3- | rev)
  File_ID_number=\$(echo "${sample}" | rev | cut -c 1 | rev)
  Lane_ID_number=\$(echo "${lane}" | rev | cut -c 1 | rev)
  convertHeaders.py -i $fqheader1 -o \${File_ID_new}_S1_L00\${Lane_ID_number}_R1_00\${File_ID_number}.fq.gz &
  convertHeaders.py -i $fqheader2 -o \${File_ID_new}_S1_L00\${Lane_ID_number}_R2_00\${File_ID_number}.fq.gz

  cellranger count --id=\${File_ID_new} \\
  --fastqs=./ \\
  --sample=\${File_ID_new} \\
  --transcriptome="${transcriptome}" \\
  --chemistry=SC3Pv3 \\
  --expect-cells=8000 \\
  --localcores=$task.cpus \\
  --localmem=64

  """
}


/*
process fastqc {
   tag "$sample"
   label 'process_low'
   publishDir "${cluster_path}/04_pfastq/${platform}/${run_id}/${lane}/${user}/fastqc/${sample}", mode: 'copy',
   saveAs: { filename ->
     filename.endsWith(".zip") ? "zips/$filename" : filename
   }

   input:
   set val(sample), file(reads), val(index), val(run_id), val(lane), val(platform), val(user), file(transcriptome) from ch_fastq

   output:
   path("*_fastqc.{zip,html}") into fastqc_results //multiqc

   script:
   """
   fastqc --quiet --threads $task.cpus $reads
   """
 }



/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[mpozuelo/MGI_demux] Successful: $workflow.runName"

    if (!workflow.success) {
      subject = "[mpozuelo/MGI_demux] FAILED: $workflow.runName"
    }



    c_reset = params.monochrome_logs ? '' : "\033[0m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_red = params.monochrome_logs ? '' : "\033[0;31m";


    if (workflow.stats.ignoredCount > 0 && workflow.success) {
        log.info "${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}"
        log.info "${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCount} ${c_reset}"
        log.info "${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCount} ${c_reset}"
    }

    if (workflow.success) {
        log.info "${c_purple}[mpozuelo/MGI_demux]${c_green} Pipeline completed successfully${c_reset}"
    } else {
        checkHostname()
        log.info "${c_purple}[mpozuelo/MGI_demux]${c_red} Pipeline completed with errors${c_reset}"
    }

}

// Check file extension
def hasExtension(it, extension) {
    it.toString().toLowerCase().endsWith(extension.toLowerCase())
}

def mpozueloHeader() {
  // Log colors ANSI codes
  c_blue = params.monochrome_logs ? '' : "\033[0;34m";
  c_dim = params.monochrome_logs ? '' : "\033[2m";
  c_white = params.monochrome_logs ? '' : "\033[0;37m";
  c_reset = params.monochrome_logs ? '' : "\033[0m";


  return """    -${c_dim}--------------------------------------------------${c_reset}-
  ${c_blue}  __  __  __   __  ___         ${c_reset}
  ${c_blue}  | \\/ | |__| |  |  /  |  |     ${c_reset}
  ${c_blue}  |    | |    |__| /__ |__|         ${c_reset}
  ${c_white}  mpozuelo/MGI_demux v${workflow.manifest.version}${c_reset}
  -${c_dim}--------------------------------------------------${c_reset}-
  """.stripIndent()
}


def checkHostname() {
  def c_reset = params.monochrome_logs ? '' : "\033[0m"
  def c_white = params.monochrome_logs ? '' : "\033[0;37m"
  def c_red = params.monochrome_logs ? '' : "\033[1;91m"
  def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
  if (params.hostnames) {
    def hostname = "hostname".execute().text.trim()
    params.hostnames.each { prof, hnames ->
      hnames.each { hname ->
        if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
          log.error "====================================================\n" +
          "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
          "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
          "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
          "============================================================"
        }
      }
    }
  }
}
