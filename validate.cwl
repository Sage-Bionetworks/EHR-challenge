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

arguments:
  - valueFrom: validate.py
  - valueFrom: $(inputs.inputfile)
    prefix: -s
  - valueFrom: results.json
    prefix: -r
  - valueFrom: $(inputs.entity_type)
    prefix: -e

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: validate.py
        entry: |
          #!/usr/bin/env python
          from __future__ import print_function
          import sys
          import synapseclient
          import argparse
          import os
          import json
          import pandas as pd

          def eprint(*args, **kwargs):
                print(*args, file=sys.stderr, **kwargs)

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="validation results")
          parser.add_argument("-e", "--entity_type", required=True, help="synapse entity type downloaded")
          parser.add_argument("-s", "--submission_file", help="Submission File")

          args = parser.parse_args()
          
          if args.submission_file is None:
              prediction_file_status = "INVALID"
              invalid_reasons = ['Expected FileEntity type but found ' + args.entity_type]
          else:
              #with open(args.submission_file,"r") as sub_file:
              #    message = sub_file.read()
              subdf = pd.read_csv(args.submission_file)
              invalid_reasons = []
              prediction_file_status = "VALIDATED"

              eprint("\n\n---------------DEBUGGING-----------------")
              eprint (subdf)
              eprint (args.submission_file)
              eprint("---------------------------------------------\n\n")

              if subdf.get("person_id") is None:
                  invalid_reasons.append("Submission must have person_id column")
                  prediction_file_status = "INVALID"
          result = {'prediction_file_errors':"\n".join(invalid_reasons),'prediction_file_status':prediction_file_status}
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
