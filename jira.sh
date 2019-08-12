#!/bin/bash

BASE_PATH=$(dirname $0)

# creates a branch name of $USER-<JIRA>/<message>
function branch-name() {
  git branch | grep \* | cut -d ' ' -f2 | sed "s/$USER-//" | cut -d '/' -f1
}

# lists active jira
function jira-list() {
  RBENV_VERSION=2.5.3 ruby -r ${BASE_PATH}/jira.rb -e "print_jira_list"
}

# finds branch names that correspond to active jira's and prompts you to resume them
function jira-resume() {
  RBENV_VERSION=2.5.3 ruby -r ${BASE_PATH}/jira.rb -e "resume_jira"
}

# creates a new jira by prompting for a title
function jira-new() {
  RBENV_VERSION=2.5.3 ruby -r ${BASE_PATH}/jira.rb -e "new_jira"
}

# marks the current jira in progress
function jira-inprogress(){
  jira_num=`branch-name`
  jira progress $jira_num
}

# marks the current jira as done if no argument is supplied
# otherwise marks the argument as done (i.e. jira-done FOO-123)
function jira-done(){
  if [ "$1" '==' "" ];then 
    jira_num=`branch-name`
  else
    jira_num="$1"
  fi
  jira done $jira_num
}

# creates a new branch. either lets you create a new jira
# or marks the jira in progress if selecting an existing
function new-branch() {
  RBENV_VERSION=2.5.3 ruby -r $BASE_PATH/jira.rb -e "new_branch"
  jira-inprogress
}

# open's the current branch jira in jira
function jira-open() {
  jira_num=`branch-name`
  jira browse $jira_num
}

alias nb="new-branch"
alias open-jira="jira-open"
alias resume="jira-resume"
