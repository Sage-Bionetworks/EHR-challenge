#!/usr/bin/env python
import synapseclient
import argparse
import os
import json
import pandas as pd
import numpy as np
from sklearn.metrics import roc_curve
from sklearn.metrics import auc
from sklearn.metrics import precision_score

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
parser.add_argument("-s", "--status", required=True, help="Submission status")
parser.add_argument("-r", "--results", required=True, help="Scoring results")
parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

args = parser.parse_args()

if args.status == "VALIDATED":
    goldstandard = pd.read_csv(args.goldstandard)
    predictions = pd.read_csv(args.submissionfile)

    evaluation = goldstandard.merge(predictions, how="inner", on="person_id")

    fpr, tpr, thresholds = roc_curve(evaluation["status"], evaluation["score"], pos_label=1)
    roc_auc = auc(fpr, tpr)

    #precision = precision_score(evaluation["status"], evaluation["score"].round())

    status = "SCORED"
    score = roc_auc
else:
    status = args.status
    score = -1

result = {'score':score,'status':status}

with open(args.results, 'w') as o:
    o.write(json.dumps(result))