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
