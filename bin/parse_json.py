#!/usr/bin/env python

import pandas as pd
from collections import Counter
import argparse
import csv


argparser = argparse.ArgumentParser()
argparser.add_argument('--samplesheet', type=str)
argparser.add_argument('--jsonfile', type=str)
argparser.add_argument('--problemsamples', type=str)

ARGS = argparser.parse_args()
samplesheet = ARGS.samplesheet
json_file = ARGS.jsonfile
problem_samples = ARGS.problemsamples

# import and read stats.json file for unknown barcodes list
json_file = pd.read_json(json_file)

# import sample sheet as not fixed path when in pipeline
prob_file = open(problem_samples, 'r')
problem_samples_list = prob_file.read().splitlines()

# remove noise from above the [Data] tag on sample sheet
data_tag_search = '[Data]'
data_index = 0
with open(samplesheet, 'r') as f:
    reader = csv.reader(f, delimiter=',')
    for idx, row in enumerate(reader):
        if data_tag_search in row:
            data_index = idx

sample_pd = pd.read_csv(samplesheet, skiprows=range(0, data_index + 1))
sample_pd['index'] = sample_pd['index'].astype('str')
sample_pd['index2'] = sample_pd['index2'].astype('str')

# slice sample sheet for only problem rows
SS_new_problem_ids = sample_pd.iloc[problem_samples_list].copy()
prob_lanes = SS_new_problem_ids.Lane.unique()

# create new column for read counts
SS_new_problem_ids['read_count'] = 0

# only get the unknown barcodes
json_file = json_file["UnknownBarcodes"]

list_dict_matches = []

for result in json_file:
    if result['Lane'] in prob_lanes:
        for unknown_idx, unknown_count in result['Barcodes'].items():
            for index, row in SS_new_problem_ids.iterrows():
                if result['Lane'] == row['Lane']:
                    # dual indexed lane
                    if "+" in unknown_idx:
                        indexes = unknown_idx.split("+")
                        index1= indexes[0]
                        index2 = indexes[1]
                        # find indexes that are single indexes on dual lanes
                        if index1 == row['index'] and pd.isnull(row['index2']) is True:
                            # ensure its the highest read count of the matches
                            if unknown_count > row['read_count']:
                                sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID'], 'index2'] = index2
                                SS_new_problem_ids.loc[SS_new_problem_ids['Sample_ID'] == row['Sample_ID'], 'read_count'] = unknown_count
                        # find partial matches for short index 1 that is dual indexed
                        elif index1.startswith(row['index']) is True and index2 == row['index2']:
                            if unknown_count > row['read_count']:
                                sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID'], 'index'] = index1
                                SS_new_problem_ids.loc[SS_new_problem_ids['Sample_ID'] == row['Sample_ID'], 'read_count'] = unknown_count
                        # find partial matches for short index 1 that is single indexed
                        elif index1.startswith(row['index']) is True and pd.isnull(row['index2']) is True:
                            if unknown_count > row['read_count']:
                                sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID'], 'index2'] = index2
                                sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID'], 'index'] = index1
                                SS_new_problem_ids.loc[SS_new_problem_ids['Sample_ID'] == row['Sample_ID'], 'read_count'] = unknown_count
                        # find partial matches for short index 2 that is dual indexed
                        elif index2.startswith(row['index2']) is True and index1 == row['index']:
                            if unknown_count > row['read_count']:
                                sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID'], 'index2'] = index2
                                SS_new_problem_ids.loc[SS_new_problem_ids['Sample_ID'] == row['Sample_ID'], 'read_count'] = unknown_count
                    # single indexed lane
                    elif "+" not in unknown_idx:
                        # find partial matches for short index 1 that is single indexed
                        if unknown_idx.startswith(row['index']) is True and pd.isnull(row['index2']) is True:
                            if unknown_count > row['read_count']:
                                sample_pd.loc[sample_pd['Sample_ID'] == row['Sample_ID'], 'index'] = unknown_idx
                                SS_new_problem_ids.loc[SS_new_problem_ids['Sample_ID'] == row['Sample_ID'], 'read_count'] = unknown_count


# delete read count column from dataframe
SS_new_problem_ids.drop('read_count', 1, inplace=True)

with open('json_samplesheet.csv', 'w+') as fp:
    fp.write('[Data]\n')
    sample_pd.to_csv(fp, index=False)
    fp.close()
