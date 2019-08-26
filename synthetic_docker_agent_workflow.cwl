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

  annotate_results_received:
    run: annotate_submission_status.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: submission_status
        valueFrom: "EVALUATION STARTED"
      - id: pipe_status
        valueFrom: "RECEIVED"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  notify_participants:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/notification_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: parentid
        source: "#submitterUploadSynId"
    out: []

  get_docker_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/get_submission_docker.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: docker_repository
      - id: docker_digest
      - id: entityid
      
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
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  annotate_results_validated:
    run: annotate_submission_status.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: submission_status
        valueFrom: "TRAINING"
      - id: pipe_status
        source: "#validate_docker/status"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

  run_docker_train:
    run: run_synthetic_training_docker.cwl
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
        valueFrom: "/home/thomasyu/train"
    out:
      - id: model
      - id: scratch
      - id: status

  annotate_results_trained:
    run: annotate_submission_status.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: submission_status
        valueFrom: "INFERRING"
      - id: pipe_status
        source: "#run_docker_train/status"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  run_docker_infer:
    run: run_synthetic_infer_docker.cwl
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
        valueFrom: "/home/thomasyu/validation"
    out:
      - id: predictions
      - id: status

  upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#run_docker_infer/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entityid"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  annotate_docker_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#upload_results/results"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  annotate_results_inferred:
    run: annotate_submission_status.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: submission_status
        valueFrom: "VALIDATING PREDICTIONS"
      - id: pipe_status
        source: "#run_docker_infer/status"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

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
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"

    out: []

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v1.6/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validation/results"
      - id: to_public
        valueFrom: "true"
      - id: force_change_annotation_acl
        valueFrom: "true"
      - id: synapse_config
        source: "#synapseConfig"
    out: []
