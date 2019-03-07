#!/usr/bin/env python

#!/usr/bin/env python

import pandas as pd
import argparse
import csv
import numpy

""" Function to alert if there is a problem sample sheet"""

argparser = argparse.ArgumentParser()
argparser.add_argument('--samplesheet', type=str)
argparser.add_argument('--newsamplesheet', type=str)
argparser.add_argument('--problemsamples', type=str)

ARGS = argparser.parse_args()
samplesheet = ARGS.samplesheet
newsamplesheet = ARGS.newsamplesheet
problem_samples = ARGS.problemsamples

# import sample sheet as not fixed path when in pipeline
prob_file = open(problem_samples, 'r')
problem_samples_list = prob_file.read().splitlines()

# import sample sheet as not fixed path when in pipeline
# samplesheet = "/camp/stp/sequencing/inputs/instruments/sequencers/190201_K00102_0307_AH3KTVBBXY/H3KTVBBXY.csv"

# get idx of Data tag
def getdatatag(samplesheet):
    data_tag_search = '[Data]'
    data_index = 0
    with open(samplesheet, 'r') as f:
        reader = csv.reader(f, delimiter=',')
        for idx, row in enumerate(reader):
            if data_tag_search in row:
                data_index = idx
    return data_index

# if parameters are met return value indicating mixed batch on rechecked sample sheet
#read in original samplesheet and get idx of Data tag
ss_idx = getdatatag(samplesheet)
sample_pd = pd.read_csv(samplesheet, skiprows=range(0, ss_idx + 1))

#read in newly made samplesheet and get idx of Data tag
new_ss_idx = getdatatag(newsamplesheet)
newsample_pd = pd.read_csv(newsamplesheet, skiprows=range(0, new_ss_idx + 1))
SS_new_problem_ids = newsample_pd.loc[newsample_pd['Sample_ID'].isin(problem_samples_list)].copy()

test_result = 'pass'

# compare problem sample rows and if the same return fail
for index, row in SS_new_problem_ids.iterrows():
    update_idx_val = sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID']]
    if update_idx_val['Sample_ID'].values == row['Sample_ID'] and update_idx_val['index'].values == row['index']:
            if update_idx_val['index2'].values == row['index2'] or (numpy.isnan(update_idx_val['index2'].values) and numpy.isnan(row['index2'])):
                test_result = 'fail'

print(test_result)

