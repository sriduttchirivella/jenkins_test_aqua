# Jenkins infra using docker containers

1. #### VM Creation

   - Used [multipass](https://multipass.run/) to create 2 ubuntu 20.04 LTS based VM's on windows using native Hyper-V hypervisor.
   - VM1 is used to run Jenkins master container
   - VM2 is used to run Jenkins build agent containers (Dynamically provisioned)

2. #### Docker Installation

   - Followed official docker install documentation at https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository to install docker on both the VM's

3. #### Enabling docker remote API on docker host (VM2)

   - Edited docker.service file at `/lib/systemd/system/` to add `-H tcp://0.0.0.0:4243` to `ExecStart`

   - ```shell
     ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:4243 -H fd:// --containerd=/run/containerd/containerd.sock
     ```

   - Reload and restart docker service

   - ```shell
     $ sudo systemctl daemon-reload
     $ sudo systemctl restart docker
     ```

4. #### Start Jenkins master container

   - Created a new directory `jenkins_master` in ubuntu user home directory. This directory is used to persist Jenkins master data.

   - Executed following docker run command to start the container as required.

   - ```shell
     docker run -itd -v /home/ubuntu/jenkins_master:/var/jenkins_home -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
     ```

   - As you can see I have exposed both 8080 and 50000 ports to access Web UI and JNLP agent protocols respectively.

5. #### Configure Jenkins master

   - Unlock Jenkins by inputing initial admin password

   - ![jenkins_01](https://user-images.githubusercontent.com/76213115/102697731-1c0e7280-425e-11eb-8654-7da146bbaca0.png)
   - Installed suggested plugins during initial setup
   - ![jenkins_02](https://user-images.githubusercontent.com/76213115/102697732-1d3f9f80-425e-11eb-8590-b4e269a222d5.png)
   - Configured first admin user credentials
   - ![jenkins_03](https://user-images.githubusercontent.com/76213115/102697733-1dd83600-425e-11eb-8730-5faf5b5bb93e.png)
   - After first login I have installed `Docker` plugin which provides integration between Jenkins and Docker
   - ![jenkins_04](https://user-images.githubusercontent.com/76213115/102697734-1dd83600-425e-11eb-907f-c0033562687b.png)
   - Docker plugin will enable you to configure a Docker host as a cloud so that Jenkins can provision build agent containers dynamically as in when needed.
   - In the below screen-shot I have provided `Docker Host URI` with the VM2 IP address along with the port where I have enabled docker remote API in step 3
   - ![jenkins_05](https://user-images.githubusercontent.com/76213115/102697735-1e70cc80-425e-11eb-9a85-a0e61695a212.png)

6. #### Configure Jenkins JNLP Agent

   - Build custom Docker Agent image.

     - For this I have created my own JNLP agent image based on original/official image

     - ```dockerfile
       # Original/Official JNLP inbound agent from Jenkins public repo
       FROM jenkins/inbound-agent:alpine
       
       # Switching to root user
       USER root
       
       # Updating and installing packages
       RUN apk update && apk add -u libcurl curl
       
       # Install Docker client
       ARG DOCKER_VERSION=18.03.0-ce
       ARG DOCKER_COMPOSE_VERSION=1.21.0
       RUN curl -fsSL https://download.docker.com/linux/static/stable/`uname -m`/docker-$DOCKER_VERSION.tgz | tar --strip-components=1 -xz -C /usr/local/bin docker/docker
       RUN curl -fsSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
       
       # Create docker group with 998 as GID and add jenkins user to docker group
       RUN addgroup --gid 998 -S docker && addgroup jenkins docker
       
       RUN touch /debug-flag
       
       # Falling back to user jenkins
       USER jenkins
       ```

     - ```shell
       docker build -t sriduttchirivella/jenkins-docker-agent .
       ```

     - The image is pushed to docker hub and is available publicly to pull

     - ```shell
       docker pull sriduttchirivella/jenkins-docker-agent
       ```

   - Docker Agent template config.

     - Now that I have an docker agent image. I will go ahead and configure docker agent template in Jenkins UI
     - ![jenkins_06](https://user-images.githubusercontent.com/76213115/102697737-1f096300-425e-11eb-9dbb-a4d703f04023.png)
     - The above template will allow Jenkins master to automatically provision a build agent container based on `sriduttchirivella/jenkins-docker-agent` image. It will also mount the `/var/run/docker.sock` from the host into the container to provide access to docker on the host and will enable us to build docker images from with in the container.
     - The above method is based on **Docker outside of Docker (i.e. mounting /var/run/docker.sock) mode.**
     - In an environment where we don't have access to host's docker.sock file we can actually use **Docker in Docker mode.**

7. #### Creating a pipeline Job

   - I have created a pipeline job to build a docker image inside Jenkins agent container
   - ![jenkins_07](https://user-images.githubusercontent.com/76213115/102697738-1fa1f980-425e-11eb-8237-26ad36b714eb.png)
   - In the above pipeline I have a single build stage where I'm trying to download a Dockerfile from Jenkins project public repo and using the same to build a sample docker image `test:v101`

8. #### Build Docker Image

     - Triggered the pipeline job to build docker image inside a Jenkins agent container
     - ![jenkins_09](https://user-images.githubusercontent.com/76213115/102698571-68f54780-4264-11eb-9e7e-a6c2887180be.png)

9. #### Challenges

     - I had to build docker agent image by adding specific group ID same as host docker GID to access docker.sock from container Jenkins user. If we use docker in docker mode we don't need this.

     - The Docker plugin failed to launch new Jenkins build agent containers in first place and was trowing following errors

          - ![jenkins_08](https://user-images.githubusercontent.com/76213115/102697740-203a9000-425e-11eb-9c10-94e8cc9865ec.png)
          - I have debugged this issue and found out that there is a know issue with the docker plugin when used with latest version of Jackson 2 API plugin.

          - Since this is a new Jenkins deployment it automatically deployed latest version (2.12.0) of Jackson 2 API plugin and I had to manually downgraded it to v2.11.3 to fix the issue
