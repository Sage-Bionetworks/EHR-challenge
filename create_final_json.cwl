#!/usr/bin/env cwl-runner
#
# Example score submission file
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: input_json
    type: File

arguments:
  - valueFrom: create_final_json.py
  - valueFrom: $(inputs.input_json.path)
    prefix: -i
  - valueFrom: results.json
    prefix: -r

requirements:
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entryname: create_final_json.py
        entry: |
          #!/usr/bin/env python
          import json
          import argparse

          parser = argparse.ArgumentParser()
          parser.add_argument("-r", "--results", required=True, help="New result json")
          parser.add_argument("-i", "--input_json", required=True, help="Initial json")
          args = parser.parse_args()

          with open(args.input_json, "r") as json_file:
            data = json.load(json_file)
          final = {}
          for key in data:
            final["final_" + key] = data[key]
          with open(args.results, 'w') as o:
            o.write(json.dumps(final))
outputs:

  - id: results
    type: File
    outputBinding:
      glob: results.json   