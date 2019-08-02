#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:

  - id: entity_type
    type: string
  - id: inputfile
    type: File?
  - id: submissionid
    type: int
  - id: parentid
    type: string
  - id: synapse_config
    type: File
  - id: goldstandard
    type: File

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.inputfile)
    prefix: -s
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.entity_type)
    prefix: -e
  - valueFrom: $(inputs.submissionid)
    prefix: -i
  - valueFrom: $(inputs.parentid)
    prefix: -p
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.goldstandard.path)
    prefix: -g

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate.py
        entry: |
          #!/usr/bin/env python
          import synapseclient
          import argparse
          import os
          import json
          import pandas as pd

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="validation results")
          parser.add_argument("-e", "--entity_type", required=True, help="synapse entity type downloaded")
          parser.add_argument("-s", "--submission_file", help="Submission File")
          parser.add_argument("-i", "--submissionid", help="Submission ID")
          parser.add_argument("-p", "--parentid", help="Parent ID")
          parser.add_argument("-c", "--synapse_config", help="Parent ID")
          parser.add_argument("-g", "--goldstandard", required=True, help="Goldstandard for scoring")

          args = parser.parse_args()

          syn = synapseclient.Synapse(configPath=args.synapse_config)
          syn.login()

          #Create the logfile
          log_text = "empty"
          if args.submission_file is None:
              prediction_file_status = "INVALID"
              invalid_reasons = ['Expected FileEntity type but found ' + args.entity_type]
          else:
              subdf = pd.read_csv(args.submission_file)
              invalid_reasons = []
              prediction_file_status = "VALIDATED"


              if subdf.get("person_id") is None:
                invalid_reasons.append("Submission must have 'person_id' column")
                prediction_file_status = "INVALID"
              if subdf.get("score") is None:
                invalid_reasons.append("Submission must have 'score' column")
                prediction_file_status = "INVALID"
              
              goldstandard = pd.read_csv(args.goldstandard)
              evaluation = goldstandard.merge(subdf, how="inner", on="person_id")
              
              if evaluation.shape[0] < goldstandard.shape[0]:
                invalid_reasons.append("Submission does not have scores for all goldstandard patients.")
                prediction_file_status = "INVALID"
          result = {
            'prediction_file_errors':"\n".join(invalid_reasons),
            'prediction_file_status':prediction_file_status,
            'submission_status': prediction_file_status}
          with open(args.results, 'w') as o:
              o.write(json.dumps(result))
     
outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   

  - id: status
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_status'])

  - id: invalid_reasons
    type: string
    outputBinding:
      glob: results.json
      loadContents: true
      outputEval: $(JSON.parse(self[0].contents)['prediction_file_errors'])
