#!/usr/bin/env python


import pandas as pd
import argparse
import sys

def parse_args(args=None):
    Description = 'Check samplesheet and add files to bed file'
    Epilog = """Example usage: python modify_samplesheet.py <FILE_IN> <FILE_OUT>"""

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument('FILE_IN', help="Input samplesheet.")
    parser.add_argument('FILE_OUT', help="Output samplesheet.")
    return parser.parse_args(args)


def add_bed_file(FileIn,FileOut):
    #Open input file
    fi = open(FileIn, 'r')

    # Load mosdepth thresholds.bed.gz into a pandas dataframe
    cov = pd.read_csv(fi, delimiter=',', index_col=False, low_memory=False)

    # Open output file
    fo = open(FileOut, 'w')

    basefolder = '/datos/ngs/dato-activo/References/cellRanger/'
    # Dictionary for bed files
    bed = {'hg38': basefolder + 'refdata-cellranger-GRCh38-3.0.0/', 'mm10': basefolder + 'refdata-gex-mm10-2020-A/'}

    # Write header
    #fo.write("%s\n" %('\t'.join(l_th[1:])))

    # Compute percentages
    cov['transcriptome'] = cov['genome'].map(bed)
    cov['fastq1'] = "/datos/ngs/dato-activo/data/04_pfastq/" + cov['platform'] + '/' + cov['run'] + '/' + cov['lane'] + '/' + cov['user'] + '/demux_fastq/' + cov['sampleID'] + '_' + cov['run'] + '_' + cov['lane'] + '_R1.fq.gz'
    cov['fastq2'] = "/datos/ngs/dato-activo/data/04_pfastq/" + cov['platform'] + '/' + cov['run'] + '/' + cov['lane'] + '/' + cov['user'] + '/demux_fastq/' + cov['sampleID'] + '_' + cov['run'] + '_' + cov['lane'] + '_R2.fq.gz'


    cov.to_csv(fo, index = False)
    fi.close()


def main(args=None):
    args = parse_args(args)
    add_bed_file(args.FILE_IN,args.FILE_OUT)


if __name__ == '__main__':
    sys.exit(main())
