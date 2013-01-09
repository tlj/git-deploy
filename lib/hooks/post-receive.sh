#!/bin/bash
set -e

if [ "$GIT_DIR" = "." ]; then
  # The script has been called as a hook; chdir to the working copy
  cd ..
  unset GIT_DIR
fi

# try to obtain the usual system PATH
if [ -f /etc/profile ]; then
  PATH=$(source /etc/profile; echo $PATH)
  export PATH
fi

# make sure rvm is loaded if it exists
if [ -f $HOME/.rvm/scripts/rvm ]; then
  source $HOME/.rvm/scripts/rvm
elif [ -f /usr/local/rvm/scripts/rvm ]; then
  source /usr/local/rvm/scripts/rvm
fi

# load rvmrc if it exists and rvm is started
if [ -f .rvmrc ]; then
  if [ ! -z "$rvm_path" ]; then
    source .rvmrc
  else
    echo "We have a .rvmrc file, but RVM is not loaded. Aborting."
    exit
  fi
fi

# get the current branch
head="$(git symbolic-ref HEAD)"

# read the STDIN to detect if this push changed the current branch
while read oldrev newrev refname
do
  [ "$refname" = "$head" ] && break
done

# abort if there's no update, or in case the branch is deleted
if [ -z "${newrev//0}" ]; then
  exit
fi

# check out the latest code into the working copy
umask 002
git reset --hard

logfile=log/deploy.log
restart=tmp/restart.txt

if [ -z "${oldrev//0}" ]; then
  # this is the first push; this branch was just created
  mkdir -p log tmp
  chmod 0775 log tmp
  touch $logfile $restart
  chmod 0664 $logfile $restart

  # init submodules
  git submodule update --init | tee -a $logfile
else
  # log timestamp
  echo ==== $(date) ==== >> $logfile

  # execute the deploy hook in background
  [ -x deploy/after_push ] && nohup deploy/after_push $oldrev $newrev 1>>$logfile 2>>$logfile &
fi
