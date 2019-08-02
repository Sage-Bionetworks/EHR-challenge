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
  - id: submission_status
    type: string

arguments:
  - valueFrom: progress.py
  - valueFrom: $(inputs.submissionid)
    prefix: -i
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.submission_status)
    prefix: -s

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
            parser.add_argument("-i", "--submissionid", help="Submission ID")
            parser.add_argument("-c", "--synapse_config", help="Parent ID")
            parser.add_argument("-s", "--submission_status", help="Submission Status")

            args = parser.parse_args()

            syn = synapseclient.Synapse(configPath=args.synapse_config)
            syn.login()

            result = {'submission_status': args.submission_status}
            with open(args.results, 'w') as o:
              o.write(json.dumps(result))

outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   