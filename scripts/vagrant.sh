#!/bin/bash
set -e

apt-get update
apt-get install -y ruby1.9.3
gem install bundler