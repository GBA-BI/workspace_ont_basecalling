version 1.0

workflow fast5GuppyCPU {
    input {
        String fast5_path
        String sample_name

        String? CONFIG_FILE = "dna_r9.4.1_450bps_hac"
        Int? READ_BATCH_SIZE = 250000
        String? dockerImage = "registry-vpc.miracle.ac.cn/gznl/guppy:latest" 
        String? additionalArgs
        Int? preempts = 3
        Int? memSizeGB = 64
        Int? threadCount = 12
        Int? extraDisk = 5
        Int? maxRetries = 4
    }

    parameter_meta {
        fast5_path: "path to fast5s"
        sample_name: "Name of sample, used for output file names"
        desired_size_GB: "Choose size to split input tar file by. With a 300GB fast5_tar_file and 30GB desired_size_GB, the fast5_tar_file will be split in 10 pieces."
    }

    call guppyCPU {
        input:
            sample_name = sample_name,
            fast5_path = fast5_path,
            CONFIG_FILE = CONFIG_FILE,
            READ_BATCH_SIZE = READ_BATCH_SIZE,
            dockerImage = dockerImage,
            additionalArgs = additionalArgs,
            preempts = preempts,
            memSizeGB = memSizeGB,
            threadCount = threadCount,
            extraDisk = extraDisk,
            maxRetries = maxRetries
    }

    call MinIONQC {
        input:
            sample_name = sample_name,
            summary_txt = guppyCPU.summary
    }

    output {
        File pass_bam = guppyCPU.pass_bam
        File pass_fastq = guppyCPU.pass_fastq
        File fail_bam = guppyCPU.fail_bam
        File fail_fastq = guppyCPU.fail_fastq
        File summary = guppyCPU.summary
        File channel_summary = MinIONQC.channel_summary
        File flowcell_overview = MinIONQC.flowcell_overview
        File gb_per_channel_overview = MinIONQC.gb_per_channel_overview
        File length_by_hour = MinIONQC.length_by_hour
        File length_histogram = MinIONQC.length_histogram
        File length_vs_q = MinIONQC.length_vs_q
        File q_by_hour = MinIONQC.q_by_hour
        File q_histogram = MinIONQC.q_histogram
        File reads_per_hour = MinIONQC.reads_per_hour
        File yield_by_length = MinIONQC.yield_by_length
        File yield_over_time = MinIONQC.yield_over_time
    }

    meta {
        author: "Jimin Park"
        email: "jpark621@ucsc.edu"
        description: "Calls guppy_basecaller with GPUs. Takes in fast5 files and outputs unaligned bam with methylation calls, fastq and sequencing summary text file."
    }

}

task guppyCPU {
    
    input {
        String sample_name
        File fast5_path

        String? CONFIG_FILE
        Int? READ_BATCH_SIZE
        String? dockerImage
        String? additionalArgs
        Int? preempts
        Int? memSizeGB
        Int? threadCount
        Int? extraDisk
        Int? maxRetries
    }

    # calculate needed disk size
    Int file_size = ceil(size(fast5_path, "GB"))
    Int diskSizeGB = 3 * file_size + extraDisk


    command <<<
        # Set the exit code of a pipeline to that of the rightmost command
        # to exit with a non-zero status, or zero if all commands of the pipeline exit
        set -o pipefail
        # cause a bash script to exit immediately when a command fails
        set -e
        # cause the bash shell to treat unset variables as an error and exit immediately
        set -u
        # echo each line of the script to stdout so we can see what is happening
        # to turn off echo do 'set +o xtrace'
        set -o xtrace

        ## Extract tar file to 
        mkdir input
        
        # place all extracted files into directory input
        cp "~{fast5_path}" input

        mkdir res

        # check if length of "additionalArgs" is zero

        if [[ "~{additionalArgs}" == "" ]]
        then
            ADDITIONAL_ARGS=""
        else
            ADDITIONAL_ARGS="~{additionalArgs}"
        fi

        guppy_basecaller --compress_fastq \
            -i input/ \
            -s res/ \
            --bam_out \
            --cpu_threads_per_caller "~{threadCount}" \
            --num_callers 1 \
            -c /opt/ont/guppy/data/"~{CONFIG_FILE}".cfg \
            ${ADDITIONAL_ARGS}

        mv res/pass/*.bam "~{sample_name}"_pass.bam
        mv res/pass/*.fastq.gz "~{sample_name}"_pass.fastq.gz
        mv res/fail/*.bam "~{sample_name}"_fail.bam
        mv res/fail/*.fastq.gz "~{sample_name}"_fail.fastq.gz
        mv res/sequencing_summary.txt "~{sample_name}"_sequencing_summary.txt

    >>>

    output {
        File pass_bam = "~{sample_name}_pass.bam"
        File pass_fastq = "~{sample_name}_pass.fastq.gz"
        File fail_bam = "~{sample_name}_fail.bam"
        File fail_fastq = "~{sample_name}_fail.fastq.gz"
        File summary = "~{sample_name}_sequencing_summary.txt"
    }

    runtime {
        memory: "~{memSizeGB} GB"
        cpu: "~{threadCount}"
        disks: "local-disk ~{diskSizeGB} SSD"
        maxRetries : "~{maxRetries}"
        preemptible : "~{preempts}"
        docker: "~{dockerImage}"
    }
}

task MinIONQC {
    
    input {
        String sample_name
        File summary_txt
    }

    command <<<
        cp "~{summary_txt}" summary.txt
        MinIONQC.R -i summary.txt
        mv channel_summary.png "~{sample_name}"_channel_summary.png
        mv flowcell_overview.png "~{sample_name}"_flowcell_overview.png
        mv gb_per_channel_overview.png "~{sample_name}"_gb_per_channel_overview.png
        mv length_by_hour.png "~{sample_name}"_length_by_hour.png
        mv length_histogram.png "~{sample_name}"_length_histogram.png
        mv length_vs_q.png "~{sample_name}"_length_vs_q.png
        mv q_by_hour.png "~{sample_name}"_q_by_hour.png
        mv q_histogram.png "~{sample_name}"_q_histogram.png
        mv reads_per_hour.png "~{sample_name}"_reads_per_hour.png
        mv yield_by_length.png "~{sample_name}"_yield_by_length.png
        mv yield_over_time.png "~{sample_name}"_yield_over_time.png
    >>>

    output {
        File channel_summary = "~{sample_name}_channel_summary.png"
        File flowcell_overview = "~{sample_name}_flowcell_overview.png"
        File gb_per_channel_overview = "~{sample_name}_gb_per_channel_overview.png"
        File length_by_hour = "~{sample_name}_length_by_hour.png"
        File length_histogram = "~{sample_name}_length_histogram.png"
        File length_vs_q = "~{sample_name}_length_vs_q.png"
        File q_by_hour = "~{sample_name}_q_by_hour.png"
        File q_histogram = "~{sample_name}_q_histogram.png"
        File reads_per_hour = "~{sample_name}_reads_per_hour.png"
        File yield_by_length = "~{sample_name}_yield_by_length.png"
        File yield_over_time = "~{sample_name}_yield_over_time.png"
    }

    runtime {
        docker: "registry-vpc.miracle.ac.cn/gznl/minionqc:1.4.2"
        memory: "12 GB"
        cpu: "4"
        disks: "local-disk 10 SSD"
    }
}