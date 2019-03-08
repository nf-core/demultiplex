#!/usr/bin/env python

import pandas as pd
import argparse
import csv

""" Function to alert if there is a problem sample sheet"""

argparser = argparse.ArgumentParser()
argparser.add_argument('--samplesheet', type=str)
argparser.add_argument('--pathway', type=str)
ARGS = argparser.parse_args()
samplesheet = ARGS.samplesheet
pathway = ARGS.pathway

# get idx of Data tag
data_tag_search = '[Data]'
data_index = 0
with open(samplesheet, 'r') as f:
    reader = csv.reader(f, delimiter=',')
    for idx, row in enumerate(reader):
        if data_tag_search in row:
            data_index = idx

# if parameters are met return value indicating mixed batch on sample sheet
def check_samplesheet(samplesheet):
    sample_pd = pd.read_csv(samplesheet, skiprows=range(0, data_index + 1))
    sample_pd['index'] = sample_pd['index'].astype('str')
    sample_pd['index2'] = sample_pd['index2'].astype('str')

    # find unique lanes and remove lanes that only have one sample (iClip lanes)
    # will have to change and find iclip in data type col and collapse them 
    iclip_lanes_removed = sample_pd.groupby('Lane').filter(lambda x: len(x) > 1)
    iclip_lanes_removed_set = iclip_lanes_removed['Lane'].unique()

    # check if single index samples  are on the same lane as dual index
    sample_pd_empty_remove = sample_pd[sample_pd["index2"].notnull()]
    empty_index2 = sample_pd[sample_pd["index"].notnull()]
    empty_index2 = empty_index2[empty_index2["index2"].isnull()]

    result = set(empty_index2['Lane']).intersection(set(sample_pd_empty_remove['Lane']))

    # single indexes on same lane as dual indexes
    if result:
        samplesheet_check = "fail"
        return samplesheet_check

    elif not result:
        lane_length_dict = {}
        for x in iclip_lanes_removed_set:
            # select lane that match current lane
            lane_select = sample_pd.loc[sample_pd['Lane'] == x]

            # if string length does not equal most common
            index1_len = list(lane_select['index'].str.len())
            index2_len = list(lane_select['index2'].str.len())
            lane_length_dict.update({x: max(max(index1_len), max(index2_len))})

            # find which samples do not have same idx len as most common idx len in Lane
            for k, v in lane_length_dict.items():
                for index, row in lane_select.iterrows():
                    if k == row['Lane']:
                        # first index short
                        if v != len(row['index']):
                            samplesheet_check = "fail"
                            return samplesheet_check
                        # second index short
                        elif v != len(row['index2']) and row['index2'] != 'nan':
                            samplesheet_check = "fail"
                            return samplesheet_check
                        # if no problems are detected
                        else:
                            samplesheet_check = "pass"
                            return samplesheet_check

results_ss = check_samplesheet(samplesheet)

x = open (results_ss + ".txt", "w")
x.close()
