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
  - id: submissionid
    type: int

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
  - valueFrom: $(inputs.submissionid)
    prefix: -i

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
          from sklearn.metrics import precision_recall_curve
          import matplotlib
          matplotlib.use("agg")
          import seaborn as sns
          import matplotlib.pyplot as plt

          parser = argparse.ArgumentParser()
          parser.add_argument("-f", "--submissionfile", required=True, help="Submission File")
          parser.add_argument("-s", "--status", required=True, help="Submission status")
          parser.add_argument("-r", "--results", required=True, help="Scoring results")
          parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")
          parser.add_argument("-i", "--submissionid", required=True, help="Submission ID")

          args = parser.parse_args()
          if args.status == "VALIDATED":
            goldstandard = pd.read_csv(args.goldstandard)
            predictions = pd.read_csv(args.submissionfile)

            evaluation = goldstandard.merge(predictions, how="inner", on="person_id")

            # compute the AUROC
            fpr, tpr, thresholds = roc_curve(evaluation["status"], evaluation["score"], pos_label=1)

            output_auc = open("/data/common/DREAM\ Challenge/data/AUCs/" + str(args.submissionid) + "_auc.json")
            output = json.dumps({"fpr": fpr, "tpr", tpr})
            output_auc.write(output)
            output_auc.close()

            #sns.lineplot(fpr, tpr)
            #plt.savefig(f"/data/common/DREAM Challenge/Images_Char/{args.submissionid}_AUC.png")
            
            roc_auc = auc(fpr, tpr)
            auroc_score = round(roc_auc, 5)

            # compute the AUPRC
            precision, recall, thresholds = precision_recall_curve(evaluation["status"], evaluation["score"])
            pr_auc = auc(recall, precision)
            prauc_score = round(pr_auc, 5)


            # compute the precision
            precision = round(precision_score(evaluation["status"], evaluation["score"].round()), 5)

            prediction_file_status = "SCORED"

          else:
            prediction_file_status = args.status
            precision = -1
            auroc_score = -1
            prauc_score = -1
          result = {
            'score':auroc_score,
            'prediction_file_status':prediction_file_status, 
            'submission_status': prediction_file_status,
            'score_AUC': auroc_score, 
            'score_prec': precision,
            'score_PRAUC': prauc_score}
          with open(args.results, 'w') as o:
            o.write(json.dumps(result))
     
outputs:
  - id: results
    type: File
    outputBinding:
      glob: results.json