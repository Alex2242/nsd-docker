#!/bin/bash

set -e

shellcheck bin/*.sh test/*.sh

~/halolint Dockerfile
