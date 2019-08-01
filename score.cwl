#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: inputfile
    type: File
  - id: goldstandard
    type: File
  - id: status
    type: string

arguments:
  - valueFrom: score.py
  - valueFrom: $(inputs.inputfile.path)
    prefix: -f
  - valueFrom: $(inputs.status)
    prefix: -s
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: score.py
        entry: |
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

            precision = round(precision_score(evaluation["status"], evaluation["score"].round()), 2)

            prediction_file_status = "SCORED"
            score = round(roc_auc, 2)
          else:
            prediction_file_status = args.status
            score = -1
          result = {'score':score,'prediction_file_status':prediction_file_status, 'score_AUC': score, 'score_prec': precision}
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json