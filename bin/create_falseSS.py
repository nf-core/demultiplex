#!/usr/bin/env python

import pandas as pd
import argparse
import csv


"""
Script to parse a sample sheet and make a fake samplesheet so that during demultiplexing 
there will be no errors causing the process to stop
"""

argparser = argparse.ArgumentParser()
argparser.add_argument('--samplesheet', type=str)
argparser.add_argument('--pathway', type=str)

ARGS = argparser.parse_args()
samplesheet = ARGS.samplesheet
pathway =  ARGS.pathway

# get idx of Data tag
data_tag_search = '[Data]'
data_index = 0
with open(samplesheet, 'r') as f:
    reader = csv.reader(f, delimiter=',')
    for idx, row in enumerate(reader):
        if data_tag_search in row:
            data_index = idx

# import sample sheet as not fixed path when in pipeline
sample_pd = pd.read_csv(samplesheet, skiprows=range(0, data_index + 1))

# find unique lanes and remove lanes that only have one sample (iClip lanes)
iclip_lanes_removed = sample_pd.groupby('Lane').filter(lambda x: len(x) > 1)
iclip_lanes_removed_set = iclip_lanes_removed['Lane'].unique()

samplesheet_new = sample_pd.copy()

# check sample sheet for single and dual indexes mixed
# get single indexes
ss_check = sample_pd.loc[(sample_pd['index2'].isnull()) & (sample_pd['index'].notnull())]

# get location of dual indexes
sample_pd_empty_remove = sample_pd[sample_pd["index2"].notnull()]

# create new columns in dataframe
samplesheet_new['index1_len'] = ""
samplesheet_new['index2_len'] = ""

samplesheet_new['index'] = samplesheet_new['index'].astype('str')
samplesheet_new['index2'] = samplesheet_new['index2'].astype('str')

for idx, item in samplesheet_new.iterrows():
    if item['Sample_ID'] in ss_check['Sample_ID'].values:
        samplesheet_new.at[idx,'index1_len'] = len(item['index'])
        samplesheet_new.at[idx, 'index2_len'] = 0
    elif item['Sample_ID'] in sample_pd_empty_remove['Sample_ID'].values:
        samplesheet_new.at[idx,'index1_len'] = len(item['index'])
        samplesheet_new.at[idx,'index2_len'] = len(item['index2'])

short_long_lane_mixed_ids = []
lane_length_dict ={}
for x in iclip_lanes_removed_set:
    # select lane that match current lane
    lane_select = samplesheet_new.loc[samplesheet_new['Lane'] == x]

    # get longest index length on each lane
    index1_len = list(lane_select['index'].str.len())
    index2_len = list(lane_select['index2'].str.len())
    lane_length_dict.update({x: max(max(index1_len), max(index2_len))})

# create a list of sample ID's to pass to the process that parses json file
problem_sample_ids = []
# create a list of indexes to drop from false sample sheet
indexes_to_drop = []

# compare index len and missing vals and make them as the same as max idx len
for k, v in lane_length_dict.items():
    for index, row in samplesheet_new.iterrows():
        if k == row['Lane']:
            # get index of current sample ID on original sample sheet
            update_idx_val = sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID']].index[0]
            # sample with idx the same len as the max idx len
            if v == row['index1_len'] and v == row['index2_len']:
                continue
            # samples with single idx not on same lane as dual
            elif v == row['index1_len'] and row['index2_len'] == 0 and row['Lane'] not in sample_pd_empty_remove['Lane']:
                continue
            # samples with single idx shorter than max len idx and not on same lane as dual
            elif v != row['index1_len'] and row['index2_len'] == 0 and row['Lane'] not in sample_pd_empty_remove['Lane']:
                problem_sample_ids.append(row['Sample_ID'])
                indexes_to_drop.append(update_idx_val)
                #sample_pd.at[update_idx_val, 'index'] = 'N' * v
            # samples with dual shorter idx lens than max idx len
            elif v != row['index1_len'] and v != row['index2_len'] and row['Lane'] in sample_pd_empty_remove['Lane']:
                problem_sample_ids.append(row['Sample_ID'])
                indexes_to_drop.append(update_idx_val)
                #sample_pd.at[update_idx_val, 'index'] = 'N' * v
                #sample_pd.at[update_idx_val, 'index2'] = 'N' * v
            # samples with idx1 shorter than max idx len
            elif v != row['index1_len'] and v == row['index2_len'] and row['Lane'] in sample_pd_empty_remove['Lane']:
                problem_sample_ids.append(row['Sample_ID'])
                indexes_to_drop.append(update_idx_val)
                #sample_pd.at[update_idx_val, 'index'] = 'N' * v
            # samples with idx2 shorter than max idx len
            elif v == row['index1_len'] and v != row['index2_len'] and row['Lane'] in sample_pd_empty_remove['Lane']:
                problem_sample_ids.append(row['Sample_ID'])
                indexes_to_drop.append(update_idx_val)
                #sample_pd.at[update_idx_val, 'index2'] = 'N' * v

sample_pd.drop(sample_pd.index[indexes_to_drop], inplace=True )

with open(pathway + 'fake_samplesheet.csv', 'w+') as fp:
    fp.write('[Data]\n')
    sample_pd.to_csv(fp, index=False)

with open(pathway + 'problem_samples_list.txt', 'w+') as f:
    for item in problem_sample_ids:
        f.write("%s\n" % item)
    f.close()
print(pathway + 'fake_samplesheet.csv')
