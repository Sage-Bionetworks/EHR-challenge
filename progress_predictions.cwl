#!/usr/bin/env cwl-runner
#
# Example validate submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: submissionid
    type: int
  - id: synapse_config
    type: File

arguments:
  - valueFrom: $(inputs.submissionid)
    prefix: -i
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: progress.py
        entry: |
            #!/usr/bin/env python
            import synapseclient
            import argparse
            import json

            parser = argparse.ArgumentParser()
            parser.add_argument("-r", "--results", required=True, help="validation results")
            parser.add_argument("-i", "--submissionid", help="Submission ID")
            parser.add_argument("-c", "--synapse_config", help="Parent ID")

            args = parser.parse_args()

            syn = synapseclient.Synapse(configPath=args.synapse_config)
            syn.login()

            result = {'submission_status': 'SCORING IN PROGRESS'}
            with open(args.results, 'w') as o:
                o.write(json.dumps(result))

outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   