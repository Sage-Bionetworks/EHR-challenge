"""Stop and remove Docker containers of invalid submissions
Submissions that are cancelled or exceed time quota aren't
stopped and removed because docker kill does not send a
termination signal that can be caught"""
import docker
import synapseclient


def stop_hanging_docker_submissions():
    """Stops hanging docker submissions"""
    syn = synapseclient.login()
    client = docker.from_env()
    running_containers = client.containers.list()
    for container in running_containers:
        try:
            status = syn.getSubmissionStatus(container.name)
            if status.status == "INVALID":
                print("stopping: " + container.name)
                container.stop()
                container.remove()
        except Exception:
            print("Not a synapse submission / unable to remove container")


if __name__ == "__main__":
    stop_hanging_docker_submissions()
