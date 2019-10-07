#!/usr/bin/env cwl-runner
#
# Run Docker Submission
#
cwlVersion: v1.0
class: CommandLineTool
baseCommand: python

inputs:
  - id: submissionid
    type: int
  - id: docker_repository
    type: string
  - id: docker_digest
    type: string
  - id: docker_registry
    type: string
  - id: docker_authentication
    type: string
  - id: parentid
    type: string
  - id: status
    type: string
  - id: synapse_config
    type: File
  - id: input_dir
    type: string

arguments: 
  - valueFrom: runDocker.py
  - valueFrom: $(inputs.submissionid)
    prefix: -s
  - valueFrom: $(inputs.docker_repository)
    prefix: -p
  - valueFrom: $(inputs.docker_digest)
    prefix: -d
  - valueFrom: $(inputs.status)
    prefix: --status
  - valueFrom: $(inputs.parentid)
    prefix: --parentid
  - valueFrom: $(inputs.synapse_config.path)
    prefix: -c
  - valueFrom: $(inputs.input_dir)
    prefix: -i

requirements:
  - class: InitialWorkDirRequirement
    listing:
      - entryname: .docker/config.json
        entry: |
          {"auths": {"$(inputs.docker_registry)": {"auth": "$(inputs.docker_authentication)"}}}
      - entryname: runDocker.py
        entry: |
          from __future__ import print_function
          import sys
          import docker
          import argparse
          import os
          import json
          import logging
          import synapseclient
          import time
          import requests
          import subprocess
          from threading import Event
          import signal
          from functools import partial

          logger = logging.getLogger()
          logger.setLevel(logging.INFO)

          exit = Event()

          def main(args):
            if args.status == "INVALID":
              raise Exception("Docker image is invalid")

            syn = synapseclient.Synapse(configPath=args.synapse_config)
            syn.login()

            client = docker.from_env()
            api_client = docker.APIClient(base_url='unix://var/run/docker.sock')

            import getpass
            print (getpass.getuser())

            #Add docker.config file
            docker_image = args.docker_repository + "@" + args.docker_digest

            #These are the volumes that you want to mount onto your docker container
            dir = "/data/common/DREAM Challenge/data/submissions"
            scratch_dir = os.path.join(os.getcwd(), "scratch")
            model_dir = os.path.join(os.getcwd(), "model")
            input_dir = args.input_dir

            print ("mounting volumes")

            #These are the locations on the docker that you want your mounted volumes to be + permissions in docker (ro, rw)
            #It has to be in this format '/output:rw'
            mounted_volumes = {scratch_dir:'/scratch:z',
                               input_dir:'/train:ro',
                               model_dir:'/model:z'}
            #All mounted volumes here in a list
            all_volumes = [scratch_dir,input_dir,model_dir]
            #Mount volumes
            volumes = {}
            for vol in all_volumes:
              volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0], 'mode': mounted_volumes[vol].split(":")[1]}

            #Look for if the container exists already, if so, reconnect 
            print ("checking for containers")
            container=None
            errors = None
            for cont in client.containers.list(all=True):
              if args.submissionid in cont.name:
                #Must remove container if the container wasn't killed properly
                if cont.status == "exited":
                  cont.remove()
                else:
                  container = cont
            # If the container doesn't exist, make sure to run the docker image
            if container is None:
              #Run as detached, logs will stream below
              print ("running container")
              try:
                container = client.containers.run(docker_image, 'bash /app/train.sh', detach=True, volumes = volumes, name=args.submissionid, network_disabled=True, mem_limit='250g', stderr=True)
              except docker.errors.APIError as e:
                cont = client.containers.get(args.submissionid)
                cont.remove()
                errors = str(e) + "\n"
              
            print ("creating logfile")
            #Create the logfile
            
            log_filename = str(args.submissionid) + "_training_log.txt"
            open(log_filename,'w').close()

            # If the container doesn't exist, there are no logs to write out and no container to remove
            if container is not None:
              #Check if container is still running
              while container in client.containers.list():
                log_text = container.logs()
                with open(log_filename,'w') as log_file:
                  log_file.write(log_text)
                statinfo = os.stat(log_filename)
                if statinfo.st_size > 0:# and statinfo.st_size/1000.0 <= 50:
                  ent = synapseclient.File(log_filename, parent = args.parentid)
                  try:
                    #logs = syn.store(ent)
                    print("don't store")
                  except synapseclient.exceptions.SynapseHTTPError as e:
                    print (e)
                    pass
                  time.sleep(60)
              #Must run again to make sure all the logs are captured
              log_text = container.logs()
              with open(log_filename,'w') as log_file:
                log_file.write(log_text)
              
              subprocess.check_call(["docker", "exec", "logging", "mkdir", "logs/" + str(args.submissionid)])
              subprocess.check_call(["docker", "cp", os.path.abspath(log_filename), "logging:/logs/" + str(args.submissionid) + "/"])

              statinfo = os.stat(log_filename)
              #Only store log file if > 0 bytes
              # if statinfo.st_size > 0 and statinfo.st_size/1000.0 <= 50:
              if statinfo.st_size > 0:
                ent = synapseclient.File(log_filename, parent = args.parentid)
                try:
                  #logs = syn.store(ent)
                  print("don't store")
                except synapseclient.exceptions.SynapseHTTPError as e:
                  pass

              #Collect runtime
              inspection = api_client.inspect_container(container.id)
              inspection_path = str(args.submissionid) + "_training_inspection.txt"
              inspection_output = open(inspection_path)
              inspection_output.write(json.dumps(inspection)).close()

              subprocess.check_call(["docker", "cp", os.path.abspath(inspection_output), "logging:/logs/" + str(args.submissionid) + "/"])

              #Remove container and image after being done
              container.remove()

            statinfo = os.stat(log_filename)
            if statinfo.st_size == 0:
              with open(log_filename,'w') as log_file:
                if errors is not None:
                  log_file.write(errors)
                else:
                  log_file.write("No Logs")
              ent = synapseclient.File(log_filename, parent = args.parentid)
              try:
                #logs = syn.store(ent)
                print("don't store")
              except synapseclient.exceptions.SynapseHTTPError as e:
                pass

            print ("finished training")
            #Try to remove the image
            try:
              client.images.remove(docker_image, force=True)
            except:
              print("Unable to remove image")
            
            list_model = os.listdir(model_dir)
            if len(list_model) == 0:
              raise Exception("No model generated, please check training docker")
            
            list_scratch = os.listdir(scratch_dir)
            if len(list_scratch) == 0:
              scratch_fill = os.path.join(scratch_dir, "scratch_fill.txt")
              open(scratch_fill,'w').close()

          def quit(signo, _frame, submissionid=None, docker_image=None):
            print("Interrupted by %d, shutting down" % signo)
            client = docker.from_env()
            try:
              cont = client.containers.get(submissionid)
              cont.remove()
            except Exception as e:
              pass
            try:
              client.images.remove(docker_image, force=True)
            except Exception as e:
              pass
            exit.set()

          if __name__ == '__main__':
            parser = argparse.ArgumentParser()
            parser.add_argument("-s", "--submissionid", required=True, help="Submission Id")
            parser.add_argument("-p", "--docker_repository", required=True, help="Docker Repository")
            parser.add_argument("-d", "--docker_digest", required=True, help="Docker Digest")
            parser.add_argument("-i", "--input_dir", required=True, help="Input Directory")
            parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
            parser.add_argument("--parentid", required=True, help="Parent Id of submitter directory")
            parser.add_argument("--status", required=True, help="Docker image status")
            args = parser.parse_args()
            client = docker.from_env()
            docker_image = args.docker_repository + "@" + args.docker_digest

            quit_sub = partial(quit, submissionid=args.submissionid, docker_image=docker_image)
            for sig in ('TERM', 'HUP', 'INT'):
              signal.signal(getattr(signal, 'SIG'+sig), quit_sub)

            main(args)

  - class: InlineJavascriptRequirement



outputs:
  model:
    type:
      type: array
      items: File
    outputBinding:
      glob: model/*
      
  scratch:
    type:
      type: array
      items: File
    outputBinding:
      glob: scratch/*
  
  status:
    type: string
    outputBinding:
      outputEval: $("TRAINED")