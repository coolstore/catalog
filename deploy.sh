#!/bin/bash
set -e


################################################################################
# BASE CONFIGURATION                                                                #
################################################################################
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
SCRIPT_NAME=$(basename $0)
BASE_DIR=$(cd $SCRIPT_DIR/.. && pwd)
MODULE_NAME=catalog


if [ ! -f ${BASE_DIR}/common/common.sh ]; then
  echo "Missing file ../common/common.sh. Please make sure that all required modules are downloaded or run the download.sh script from $BASE_DIR."
  exit
fi

source ${BASE_DIR}/common/common.sh



################################################################################
# FUNCTIONS                                                                    #
################################################################################
function build_local() {
  echo_header "Build the project local and create an build from the artifact"
  
  oc get bc/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME" && echo "A build config for $MODULE_NAME already exists, skipping" || { oc new-build openshift/jboss-webserver30-tomcat8-openshift --name=$MODULE_NAME --binary > /dev/null; }

  echo_header "Starting build"
  if ! oc get build 2>/dev/null | grep "^$MODULE_NAME"| grep -q Complete || $REBUILD; then
    if mvn -q clean package -DskipTest -Popenshift; then 
      ######### WORK AROUND FOR ISSUE WITH --from-file DEPLOYMENTS IN THE JBOSS WEB SERVER XPAAS IMAGE ##########
      tmpdir=$(mktemp -d XXXXXX)
      mkdir -p $tmpdir/deployments
      cp target/ROOT.war $tmpdir/deployments/
      oc start-build $MODULE_NAME --from-dir=$tmpdir > /dev/null;
      rm -rf $tmpdir
      ######### WORK AROUND FOR ISSUE WITH --from-file DEPLOYMENTS IN THE JBOSS WEB SERVER XPAAS IMAGE ##########
       # oc start-build $MODULE_NAME --from-file=target/ROOT.war > /dev/null;
    else
      echo "Local maven build faild, please fix the issue and re-run the script"
      exit 5
    fi

   
  else
    echo "A completed build already exists, skipping"
  fi  

  # wait_while_empty "$MODULE_NAME starting build" 600 "oc get builds 2>/dev/null| grep \"^$MODULE_NAME\" | grep Running"
  # wait_while_empty "$MODULE_NAME build" 600 "oc get builds 2>/dev/null| grep \"^$MODULE_NAME\" | tail -1 | grep -v Running" 

}

function create_service_and_route() {
  
  if ! $BUILD_ONLY; then
    sleep 2 # Make sure that builds are started
    echo_header "Checking that build is done..."
  
    if oc get svc/$MODULE_NAME 2>/dev/null | grep -q "^$MODULE_NAME"; then
      echo_header "Deleting existing service, deployment config and route"
      oc process -f main-template.yaml | oc delete -f -
    fi

    echo_header "Creating service, deployment config and route"
    oc process -f main-template.yaml | oc create -f -
    
  fi
}


################################################################################
# MAIN: DEPLOY                                                                 #
################################################################################
pushd $SCRIPT_DIR > /dev/null

# echo_header "Running pre-checks...."
# pre_checks

# echo_header "Initialize the settings"
# init

# echo_header "Configuration"
# print_info

echo_header "Building the catalog service locally"
build_local

echo_header "Createing service, deployment config and route"
create_service_and_route



popd  > /dev/null

















