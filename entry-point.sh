#!/bin/sh
set -e

# The following environment variables already exist
# GITHUB_REPOSITORY
# GITHUB_SHA
# GITHUB_RUN_NUMBER

# only log in if we have a password (assumes username without password doesn't do anything)
if [ -n "${INPUT_DOCKER_REGISTRY_PASSWORD}" ]; then
  echo ${INPUT_DOCKER_REGISTRY_PASSWORD} | docker login ${INPUT_DOCKER_REGISTRY} -u "${INPUT_DOCKER_REGISTRY_USERNAME}" --password-stdin
fi

if [ -z "${INPUT_DOCKER_REGISTRY}" ]; then
  # In the event there is no registry, then we'll assume its for the default docker hub registry,
  # in which case the format is username/container-name.
  # This is totally untested but a best guess at the moment...
  IMAGE_PREFIX="${INPUT_DOCKER_REGISTRY_USERNAME}"
else
  IMAGE_PREFIX="${INPUT_DOCKER_REGISTRY}"
fi

echo "PREFIX: ${IMAGE_PREFIX}"
echo "CONTAINER: ${INPUT_CONTAINER_NAME}"
echo "----------------------------------"

SHA=$(echo "${GITHUB_SHA}" | cut -c1-12)
TAG_SUFFIX="${GITHUB_RUN_NUMBER}"

# By adding the build number to the tag we are ensuring the deployment
# always updates even when the commit SHA is the same.
if [ -z "${TAG_SUFFIX}" ]; then
  # we don't have a tag suffix so just set tag to the SHA
  TAG="${SHA}"
else
  # combine SHA and stuffix for tag
  TAG="${SHA}-${TAG_SUFFIX}"
fi

IMAGE_TO_PULL="${IMAGE_PREFIX}/${INPUT_CONTAINER_NAME}"
IMAGE_TO_PUSH="${IMAGE_PREFIX}/${INPUT_CONTAINER_NAME}:${TAG}"
IMAGE_TO_PUSH_LATEST="${IMAGE_PREFIX}/${INPUT_CONTAINER_NAME}:latest"

echo "IMAGE INFO"
echo "----------------------------------"
echo "SHA: ${SHA}"
echo "TAG SUFFIX: ${TAG_SUFFIX}"
echo "TAG: ${TAG}"
echo "IMAGE TO PULL: ${IMAGE_TO_PULL}"
echo "IMAGE TO PUSH: ${IMAGE_TO_PUSH}"
echo "----------------------------------"

# Add Arguments For Caching
BUILDPARAMS=""
# try to pull container if exists
if docker pull ${IMAGE_TO_PULL} 2>/dev/null; then
  echo "Attempting to use ${IMAGE_TO_PULL} as build cache."
  BUILDPARAMS=" --cache-from ${IMAGE_TO_PULL}"
fi

# This is really bad... Fix this. We don't have bash so this will do for the moment.
eval "$INPUT_COMMAND_TO_RUN"

docker tag "${INPUT_CONTAINER_NAME}" "${IMAGE_TO_PUSH}"
docker push "${IMAGE_TO_PUSH}"

# only tag with latest if on production branch
if [ $INPUT_TAG_AS_LATEST = "yes" ]; then
  echo "adding the latest tag"
  docker tag "${INPUT_CONTAINER_NAME}" "${IMAGE_TO_PUSH_LATEST}"
  docker push "${IMAGE_TO_PUSH_LATEST}"
fi

# https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
echo "IMAGE_SHA=${SHA}" >> $GITHUB_OUTPUT
echo "IMAGE_URL=${IMAGE_TO_PUSH}" >> $GITHUB_OUTPUT
# echo "::set-output name=IMAGE_SHA::${SHA}"
# echo "::set-output name=IMAGE_URL::${IMAGE_TO_PUSH}"
