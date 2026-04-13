#!/bin/bash

NOMAD_JOB=$1

# Ensure the necessary values are available
if [ -z "${NOMAD_JOB}" ]; then
  echo "Usage: $0 <nomad_job_name>"
  exit 3
fi

# Get nomad token
if ! NOMAD_JOB_TOKEN="$(twctl secrets read nomad/management_token)"; then
  echo "UNKNOWN - Could not read nomad job token from vault. Please check if vault is unsealed."
  exit 3
fi

# Check if nomad is running
if ! systemctl is-active --quiet nomad; then
  echo "CRITICAL - Please check the state of the nomad service."
  exit 2
fi

# Get Nomad Job General Information
NOMAD_JOB_INFO=$(curl -s -H "X-Nomad-Token: ${NOMAD_JOB_TOKEN}" "http://localhost:4646/v1/job/${NOMAD_JOB}")

# Check Job Status
NOMAD_JOB_STATUS=$(echo "${NOMAD_JOB_INFO}" | jq -r '.Status')

if [ "${NOMAD_JOB_STATUS}" != "running" ]; then
  echo "CRITICAL - Nomad Job ${NOMAD_JOB} has the status ${NOMAD_JOB_STATUS} not running."
  exit 2
fi

# Get the number of desired allocations for the job
DESIRED_ALLOCATION_COUNT=$(echo "${NOMAD_JOB_INFO}" | jq '[.TaskGroups[].Count] | add')

# Get the number of running allocations for the job
RUNNING_COUNT=$(curl -s -H "X-Nomad-Token: ${NOMAD_JOB_TOKEN}" "http://localhost:4646/v1/job/${NOMAD_JOB}/allocations" | jq '[.[] | select(.ClientStatus == "running")] | length')

if [ "${RUNNING_COUNT}" -eq "${DESIRED_ALLOCATION_COUNT}" ]; then
  echo "OK - All allocations for Nomad Job ${NOMAD_JOB} are running"
  exit 0
else
  echo "CRITICAL - ${RUNNING_COUNT} from ${DESIRED_ALLOCATION_COUNT} allocations are running."
  exit 2
fi
