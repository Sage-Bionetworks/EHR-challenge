#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: status
    type: string
  - id: submissionid
    type: int
  - id: synapse_config
    type: File
  - id: parentid
    type: string
  - id: evaluationid
    type: string
  - id: previous_annotation_finished
    type: boolean?
  - id: previous_email_finished
    type: boolean?

arguments:
  - valueFrom: submit.py
  - valueFrom: $(inputs.status)
    prefix: -s
  - valueFrom: submission.json
    prefix: -r
  - valueFrom: $(inputs.submissionid)
    prefix: -i
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.evaluationid)
    prefix: -e

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: submit.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import os
          import json
          import pandas as pd
          import numpy as np

          parser = argparse.ArgumentParser()
          parser.add_argument("-s", "--status", required=True, help="Submission status")
          parser.add_argument("-r", "--results", required=True, help="Scoring results")
          parser.add_argument("-i", "--submissionid", required=True, help="Submission ID")
          parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
          parser.add_argument("--parentid", required=True, help="Parent Id of submitter directory")
          parser.add_argument("-e", "--evaluationid", required=True, help="Internal evaluation id")

          args = parser.parse_args()
          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()
          if args.status == "VALIDATED":
            result = {"submissionid": args.submissionid}
            with open(args.results, 'w') as o:
              o.write(json.dumps(result))
            submission_file = synapseclient.File(args.result)
            submission_file_ent = syn.store(submission_file)
            syn.submit(evaluation=args.evaluationid, entity=submission_file_ent)
          else:
            raise ValueError("Submission not valid")
outputs: []