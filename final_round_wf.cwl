#!/usr/bin/env cwl-runner
#
# Sample workflow
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# there are no output at the workflow engine level.  Everything is uploaded to Synapse
outputs: []

steps:

  set_permissions:
    run: set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        valueFrom: "3386536"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  get_submissionid:
    run: get_linked_submissionid.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: submissionid
  
  download_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/download_from_synapse.cwl
    in:
      - id: synapseid
        #valueFrom: "syn21741751"
        valueFrom: "syn21042019"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  final_download_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/download_from_synapse.cwl
    in:
      - id: synapseid
        valueFrom: "syn21741754"
        #valueFrom: "syn21741754"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

  #notify_participants:
  #  run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/notification_email.cwl
  #  in:
  #    - id: submissionid
  #      source: "#get_submissionid/submissionid"
  #    - id: synapse_config
  #      source: "#synapseConfig"
  #    - id: parentid
  #      source: "#submitterUploadSynId"
  #  out: []

  get_docker_submission:
    run: uw_get_submission_docker.cwl
    in:
      - id: submissionid
        source: "#get_submissionid/submissionid"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: docker_repository
      - id: docker_digest
      - id: entityid
      - id: results

  annotate_submission_main_userid:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#get_docker_submission/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  validate_docker:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/validate_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  annotate_docker_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_submission_main_userid/finished"
    out: [finished]

  run_docker_train:
    run: run_training_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: input_dir
        valueFrom: "uw_omop_validation_training"
      - id: docker_script
        default:
          class: File
          location: "run_training_docker.py"
    out:
      - id: model
      - id: scratch
      - id: status

  run_docker_infer:
    run: run_infer_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: model
        source: "#run_docker_train/model"
      - id: scratch
        source: "#run_docker_train/scratch"
      - id: input_dir
        valueFrom: "uw_omop_evaluation"
      - id: stage
        valueFrom: "evaluation"
      - id: docker_script
        default:
          class: File
          location: "run_infer_docker.py"
    out:
      - id: predictions
      - id: status

  validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#run_docker_infer/predictions"
      - id: entity_type
        valueFrom: "none"
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
        #source: "#final_download_goldstandard/filepath"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  #validation_email:
  #  run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/validate_email.cwl
  #  in:
  #    - id: submissionid
  #      source: "#get_submissionid/submissionid"
  #    - id: synapse_config
  #      source: "#synapseConfig"
  #    - id: status
  #      source: "#validation/status"
  #    - id: invalid_reasons
  #      source: "#validation/invalid_reasons"
  #
  #  out: []

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validation/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#run_docker_infer/predictions"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
        #source: "#final_download_goldstandard/filepath"
      - id: submissionid
        source: "#submissionId"
      - id: status
        source: "#validation/status"
    out:
      - id: results

#  score_email:
#    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/score_email.cwl
#    in:
#      - id: submissionid
#        source: "#get_submissionid/submissionid"
#      - id: synapse_config
#        source: "#synapseConfig"
#      - id: results
#        source: "#scoring/results"
#    out: []

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#scoring/results"
      - id: to_public
        default: false
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  final_run_docker_infer:
    run: run_infer_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validation/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: model
        source: "#run_docker_train/model"
      - id: scratch
        source: "#run_docker_train/scratch"
      - id: input_dir
        valueFrom: "uw_omop_validation_validation"
      - id: stage
        valueFrom: "validation"
      - id: docker_script
        default:
          class: File
          location: "run_infer_docker.py"
    out:
      - id: predictions
      - id: status

  final_validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#final_run_docker_infer/predictions"
      - id: entity_type
        valueFrom: "none"
      - id: submissionid
        source: "#submissionId"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: goldstandard
        source: "#final_download_goldstandard/filepath"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  final_validation_results:
    run: create_final_json.cwl
    in:
      - id: input_json
        source: "#final_validation/results"
    out: [results]

#  final_validation_email:
#    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/validate_email.cwl
#    in:
#      - id: submissionid
#        source: "#get_submissionid/submissionid"
#      - id: synapse_config
#        source: "#synapseConfig"
#      - id: status
#        source: "#final_validation/status"
#      - id: invalid_reasons
#        source: "#final_validation/invalid_reasons"
#    out: []

  final_annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#final_validation/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  final_scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#final_run_docker_infer/predictions"
      - id: goldstandard
        source: "#final_download_goldstandard/filepath"
      - id: submissionid
        source: "#submissionId"
      - id: status
        source: "#final_validation/status"
    out:
      - id: results

  final_scoring_results:
    run: create_final_json.cwl
    in:
      - id: input_json
        source: "#final_scoring/results"
    out: [results]

#  final_score_email:
#    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/score_email.cwl
#    in:
#      - id: submissionid
#        source: "#get_submissionid/submissionid"
#      - id: synapse_config
#        source: "#synapseConfig"
#      - id: results
#        source: "#final_scoring_results/results"
#    out: []

  final_annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v2.7/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#final_scoring_results/results"
      - id: to_public
        default: false
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]
 
 