version 1.0

workflow fast5GuppyGPU {
    input {
        String fast5_path
        String sample_name
        String? CONFIG_FILE = "dna_r9.4.1_450bps_hac"
        Int? READ_BATCH_SIZE = 250000
        String? dockerImage = "registry-vpc.miracle.ac.cn/gznl/guppy-gpu:latest" 
        String? additionalArgs
        Int? preempts = 3
        Int? memSizeGB = 64
        Int? threadCount = 12
        Int? extraDisk = 5
        Int? gpuCount = 1
        Int? maxRetries = 4
        String gpuType = "Tesla-V100"
    }

    parameter_meta {
        fast5_path: "path to fast5s"
        sample_name: "Name of sample, used for output file names"
        desired_size_GB: "Choose size to split input tar file by. With a 300GB fast5_tar_file and 30GB desired_size_GB, the fast5_tar_file will be split in 10 pieces."
    }

    # # create list of all fast5 gs bucket paths
    # call pathToList {
    #     input:
    #         folder_path = fast5_folder_path
    # }

    # # read lines in list file to Array
    # File fast5_paths = read_lines(pathToList.path_list)

    # call splitFast5s {
    #     input:
    #         files_to_split = fast5_paths,
    #         desired_size_GB = desired_size_GB
    # }

    # call guppyGPU on each of the smaller "split" tar files
    # scatter (split_fast5 in splitFast5s.split_fast5s) {
    call guppyGPU {
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
            gpuCount = gpuCount,
            maxRetries = maxRetries,
            gpuType = gpuType
            # nvidiaDriverVersion = nvidiaDriverVersion
    }

    call MinIONQC {
        input:
            sample_name = sample_name,
            summary_txt = guppyGPU.summary
    }

    # }

    # call concatenateBam as passBam {
    #     input:
    #         files = flatten(guppyGPU.pass_bam),
    #         sample_name = sample_name,
    #         guppy_version = guppy_version,
    #         pass_fail = "pass"
    # }

    # call concatenateFastq as passFastq {
    #     input:
    #         files = flatten(guppyGPU.pass_fastq),
    #         sample_name = sample_name,
    #         guppy_version = guppy_version,
    #         pass_fail = "pass"
    # }

    # call concatenateBam as failBam {
    #     input:
    #         files = flatten(guppyGPU.fail_bam),
    #         sample_name = sample_name,
    #         guppy_version = guppy_version,
    #         pass_fail = "fail"
    # }

    # call concatenateFastq as failFastq {
    #     input:
    #         files = flatten(guppyGPU.fail_fastq),
    #         sample_name = sample_name,
    #         guppy_version = guppy_version,
    #         pass_fail = "fail"
    # }


    # call concatenateSummary {
    #     input:
    #         files = guppyGPU.summary,
    #         sample_name = sample_name,
    #         guppy_version = guppy_version
    # }


    output {
        File pass_bam = guppyGPU.pass_bam
        File pass_fastq = guppyGPU.pass_fastq
        File fail_bam = guppyGPU.fail_bam
        File fail_fastq = guppyGPU.fail_fastq
        File summary = guppyGPU.summary
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

# task pathToList {
#     input {
#         String folder_path
#         String dockerImage = "google/cloud-sdk:latest"
#         Int preempts = 3
#         Int memSizeGB = 8
#         Int extraDisk = 5
#         Int threadCount = 2
#         Int diskSizeGB = 5
#     }

#     command <<<
#         gsutil ls ~{folder_path} > "fast5.list"
#     >>>

#     output {
#         File path_list = "fast5.list"
#     }

#     runtime {
#         memory: memSizeGB + " GB"
#         cpu: threadCount
#         disks: "local-disk " + diskSizeGB + " SSD"
#         docker: dockerImage
#         preemptible : preempts
#     }
# }


# task splitFast5s {
#     input {
#         File files_to_split
#         Int desired_size_GB

#         String dockerImage = "registry-vpc.miracle.ac.cn/gznl/guppy-gpu:latest" 

#         Int preempts = 3
#         Int memSizeGB = 8
#         Int extraDisk = 5
#         Int threadCount = 2
#     }

#     Int file_size = ceil(size(files_to_split, "GB"))
#     Int diskSizeGB = 3 * file_size + extraDisk

#     command <<<
#         # move files into folder until exceeds desired_size_GB
#         # then tar contents of folder
#         OUTPUT_IDX=0
#         OUTPUT_DIR=fast5_tar_$OUTPUT_IDX
#         mkdir $OUTPUT_DIR
#         for FILE in ~{sep=' ' files_to_split}
#         do
#             size=$(du -s -BG $OUTPUT_DIR | sed 's/G.*//')
#             if (( $size > ~{desired_size_GB} ))
#             then
#                 tar -cvf fast5_tarball_$OUTPUT_IDX.tar $OUTPUT_DIR/*
#                 rm -r $OUTPUT_DIR
#                 OUTPUT_IDX=$(($OUTPUT_IDX + 1))
#                 OUTPUT_DIR=fast5_tar_$OUTPUT_IDX
#                 mkdir $OUTPUT_DIR
#             fi
#             mv $FILE $OUTPUT_DIR
#         done
#         tar -cvf fast5_tarball_$OUTPUT_IDX.tar $OUTPUT_DIR/*
#         rm -r $OUTPUT_DIR

#     >>>

#     output {
#         File split_fast5s = glob("*tar")
#     }

#     runtime {
#         memory: memSizeGB + " GB"
#         cpu: threadCount
#         disks: "local-disk " + diskSizeGB + " SSD"
#         docker: dockerImage
#         preemptible : preempts
#     }
# }


task guppyGPU {
    
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
        Int? gpuCount
        Int? maxRetries
        String gpuType
        # String? nvidiaDriverVersion = "418.87.00"
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

        mkdir output

        # check if length of "additionalArgs" is zero

        if [[ "~{additionalArgs}" == "" ]]
        then
            ADDITIONAL_ARGS=""
        else
            ADDITIONAL_ARGS="~{additionalArgs}"
        fi

        guppy_basecaller --compress_fastq \
            -i input/ \
            -s output/ \
            -c /opt/ont/guppy/data/"~{CONFIG_FILE}".cfg \
            --bam_out \
            -x cuda:all:100% \
            -r \
            --read_batch_size "~{READ_BATCH_SIZE}" \
            ${ADDITIONAL_ARGS}
        
        mv output/pass/*.bam "~{sample_name}_pass.bam"
        mv output/pass/*.fastq.gz "~{sample_name}_pass.fastq.gz"
        mv output/fail/*.bam "~{sample_name}_fail.bam"
        mv output/fail/*.fastq.gz "~{sample_name}_fail.fastq.gz"
        mv output/sequencing_summary.txt "~{sample_name}_sequencing_summary.txt"

    >>>

    output {
        File pass_bam = "~{sample_name}_pass.bam"
        File pass_fastq = "~{sample_name}_pass.fastq"
        File fail_bam = "~{sample_name}_fail.bam"
        File fail_fastq = "~{sample_name}_fail.fastq"
        File summary = "~{sample_name}_sequencing_summary.txt"
    }

    runtime {
        memory: "~{memSizeGB} GB"
        cpu: "~{threadCount}"
        disks: "local-disk ~{diskSizeGB} SSD"
        gpuCount: "~{gpuCount}"
        gpuType: "~{gpuType}"
        maxRetries : "~{maxRetries}"
        # nvidiaDriverVersion: nvidiaDriverVersion
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
    >>>

    output {
        File channel_summary = "channel_summary.png"
        File flowcell_overview = "flowcell_overview.png"
        File gb_per_channel_overview = "gb_per_channel_overview.png"
        File length_by_hour = "length_by_hour.png"
        File length_histogram = "length_histogram.png"
        File length_vs_q = "length_vs_q.png"
        File q_by_hour = "q_by_hour.png"
        File q_histogram = "q_histogram.png"
        File reads_per_hour = "reads_per_hour.png"
        File yield_by_length = "yield_by_length.png"
        File yield_over_time = "yield_over_time.png"
    }

    runtime {
        docker: "registry-vpc.miracle.ac.cn/gznl/minionqc:1.4.2"
        memory: "12 GB"
        cpu: "4"
        disks: "local-disk 10 SSD"
    }
}
# task concatenateBam {
#     input {
#         File files
        
#         String sample_name
#         String guppy_version
#         String pass_fail

#         String dockerImage = "registry-vpc.miracle.ac.cn/gznl/megalodon:latest"

#         Int preempts = 3
#         Int memSizeGB = 8
#         Int threadCount = 3
#         Int diskSizeGB = 500
#     }
    
#     command {
#         samtools merge -o "${sample_name}_${guppy_version}_${pass_fail}.bam" ${sep=" " files}
#     }

#     output {
#         File concatenatedBam = "${sample_name}_${guppy_version}_${pass_fail}.bam"
#     }

#     runtime {
#         memory: memSizeGB + " GB"
#         cpu: threadCount
#         disks: "local-disk " + diskSizeGB + " SSD"
#         docker: dockerImage
#         preemptible : preempts
#     }
# }


# task concatenateFastq {
#     input {
#         File files
#         String sample_name
#         String guppy_version
#         String pass_fail

#         String dockerImage = "registry-vpc.miracle.ac.cn/gznl/megalodon:latest"

#         # runtime
#         Int preempts = 3
#         Int memSizeGB = 8
#         Int threadCount = 3
#         Int diskSizeGB = 500
#     }
    
#     command {
#         cat ${sep=" " files} | gzip -c > "${sample_name}_${guppy_version}_${pass_fail}.fastq.gz"
#     }

#     output {
#         File concatenatedFastq = "${sample_name}_${guppy_version}_${pass_fail}.fastq.gz"
#     }

#     runtime {
#         memory: memSizeGB + " GB"
#         cpu: threadCount
#         disks: "local-disk " + diskSizeGB + " SSD"
#         docker: dockerImage
#         preemptible : preempts
#     }
# }


# task concatenateSummary {
#     input {
#         File files
#         String sample_name
#         String guppy_version

#         String dockerImage = "registry-vpc.miracle.ac.cn/gznl/megalodon:latest"

#         # runtime
#         Int preempts = 3
#         Int memSizeGB = 8
#         Int threadCount = 3
#         Int diskSizeGB = 50
#     }
    
#     command {
#         cat ${sep=" " files} > "tmp.txt"
#         # remove duplicate headers
#         awk 'NR==1 || !/^filename/' "tmp.txt" > "${sample_name}_${guppy_version}_sequencing_summary.txt"
#     }

#     output {
#         File concatenatedSummary = "${sample_name}_${guppy_version}_sequencing_summary.txt"
#     }

#     runtime {
#         memory: memSizeGB + " GB"
#         cpu: threadCount
#         disks: "local-disk " + diskSizeGB + " SSD"
#         docker: dockerImage
#         preemptible : preempts
#     }
# }