#!/bin/bash

# Read input properties
for prop in $(cat $1|egrep -v '^#')
do
    name=$(echo $prop|cut -d'=' -f1)
    export ${!name}=$(echo $prop|cut -d'=' -f2-)
done

# Setup environment
if [ ! -z "$infaHome" ]
then
    export INFA_HOME="$infaHome"

    if [ ! -z "$LD_LIBRARY_PATH" ]
    then
        export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$infaHome/server/bin"
    else
        export LD_LIBRARY_PATH="$infaHome/server/bin"
    fi

    if [ ! -z "$LIBPATH" ]
    then
        export LIBPATH="$LIBPATH:$infaHome/server/bin"
    else
        export LIBPATH="$infaHome/server/bin"
    fi
fi

# Change home directory to working directory, so connections are tied to this deployment
export HOME=$(readlink -f .)

# Connect to repository
connect_command="pmrep connect -r $srcrepo -n $srcusername -x $srcpassword"

if [ !-z "$srcsecurityDomain" ]
then
    connect_command="$connect_command -s $srcsecurityDomain"
fi

if [ !-z "$srcdomain" ]
then
    connect_command="$connect_command -d $srcdomain"
else
    connect_command="$connect_command -h $srchost -o $srcport"
fi

# Run connection command
$connect_command

# See if both source and destination folder mappings are defined:
if ( [ ! -z "$folder" ] && [ ! -z "$folderDest"] )
then
    folder_list="$folder"
else if [ ! -z "$folder" ]

else
    # Get list of folders from source, to use to build the source folder override in the control file
    # This will just specify all folders as potential source folders, pmrep does not support listing folders under a deploymentgroup
    folder_list=$(pmrep -)

# Change copydeploymentgroup to YES/NO from true/false
if [ ${copydeploymentgroup,,} == "true" ]
then
    export copydeploymentgroup="YES"
else
    export copydeploymentgroup="NO"
fi

def control = new File(controlFile)
read -r -d '' controlFile << EOM
<DEPLOYPARAMS
    COPYDEPENDENCY="YES"
    COPYDEPLOYMENTGROUP="${copydeploymentgroup}"
    COPYMAPVARPERVALS="YES"
    COPYPROGRAMINFO="YES"
    COPYWFLOWSESSLOGS="NO"
    COPYWFLOWVARPERVALS="YES"
    LATESTVERSIONONLY="YES"
    RETAINGENERATEDVAL="YES"
    RETAINSERVERNETVALS="YES">
  <DEPLOYGROUP CLEARSRCDEPLOYGROUP="NO">
EOM

