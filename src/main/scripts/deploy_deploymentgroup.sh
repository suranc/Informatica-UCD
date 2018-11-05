#!/bin/bash

set -e

# Read input properties
OLDIFS=$IFS
IFS=$(echo -en "\n\b")
for prop in $(cat $1|egrep -v '^#')
do
    name=$(echo $prop|cut -d'=' -f1)
    value=\"$(echo $prop|cut -d'=' -f2-)\"
    eval "$name=$value"
done
IFS=$OLDIFS

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

if [ ! -z "$srcsecurityDomain" ]
then
    connect_command="$connect_command -s $srcsecurityDomain"
fi

if [ ! -z "$srcdomain" ]
then
    connect_command="$connect_command -d $srcdomain"
else
    connect_command="$connect_command -h $srchost -o $srcport"
fi

# Run connection command
echo -ne "\n\n------------------------------------------------\nRunning: "
echo $connect_command
echo -ne "------------------------------------------------\n"
$connect_command

# See if both source and destination folder mappings are defined:
if ( [ ! -z "$folder" ] && [ ! -z "$folderDest"] )
then
    folder_source_list=($(echo $folder|sed 's#\\n# #g'|tr ',' ' '))
    folder_destination_list=($(echo $folderDest|sed 's#\\n# #g'|tr ',' ' '))
elif [ ! -z "$folder" ]
then
    folder_source_list=($(echo $folder|sed 's#\\n# #g'|tr ',' ' '))
else
    # Get list of folders from source, to use to build the source folder override in the control file
    # This will just specify all folders as potential source folders, pmrep does not support listing folders under a deploymentgroup
    folder_source_list=($(pmrep listobjects -o folder | tail -n +9 | head -n -3))
fi

# Change copydeploymentgroup to YES/NO from true/false
if [ ${copydeploymentgroup,,} == "true" ]
then
    export copydeploymentgroup="YES"
else
    export copydeploymentgroup="NO"
fi

cat >controlFile.ctl <<EOM
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

# Output folder lists to folder override mappings in control file.  If arrays are unequal, only use source, as long as source is defined.
if ( [ ! -z "$folder_source_list" ] && [ ! -z "$folder_destination_list" ]  && [ ${#folder_source_list[@]} -eq ${#folder_destination_list[@]} ] )
then
    for i in $(seq 1 $(expr ${#folder_source_list[@]} - 1))
    do
        cat >>controlFile.ctl <<EOM
    <OVERRIDEFOLDER SOURCEFOLDERNAME="${folder_source_list[i]}" SOURCEFOLDERTYPE="LOCAL"
      TARGETFOLDERNAME="${folder_destination_list[i]}" TARGETFOLDERTYPE="LOCAL" MODIFIEDMANUALLY="YES"/>
EOM
    done
elif [ ! -z "$folder_source_list" ]
then
    for i in $(seq 1 $(expr ${#folder_source_list[@]} - 1))
    do
        cat >>controlFile.ctl <<EOM
    <OVERRIDEFOLDER SOURCEFOLDERNAME="${folder_source_list[i]}" SOURCEFOLDERTYPE="LOCAL"
      TARGETFOLDERNAME="${folder_source_list[i]}" TARGETFOLDERTYPE="LOCAL" MODIFIEDMANUALLY="YES"/>
EOM
    done
else
    echo "Error:  No folder source mapping could be obtained.  Do you have folders defined in your source?"
    exit 1
fi

# Add label to control file if defined
if [ ! -z "$label" ]
then
    cat >>controlFile.ctl <<EOM
    <APPLYLABEL SOURCELABELNAME = "$label" SOURCEMOVELABEL = "NO"
      TARGETLABELNAME = "$label" TARGETMOVELABEL = "NO"/>
EOM
fi

# Add end tags to control file
echo -e "  </DEPLOYGROUP>\n</DEPLOYPARAMS>" >> controlFile.ctl

# Build command to execute deploy deploymentgroup using the control file we built
deploy_command="pmrep deploydeploymentgroup -p $groupname -c controlFile.ctl -r $repo -n $username -x $password"

if [ ! -z "$securityDomain" ]
then
    deploy_command="$deploy_command -s $securityDomain"
fi

# If target domain is set, use that, otherwise use host and port.
if [ ! -z "$domain" ]
then
    deploy_command="$deploy_command -d $domain"
else
    deploy_command="$deploy_command -h $host -o $port"
fi

# Execute deploy
echo -ne "\n\n------------------------------------------------\nRunning: "
echo $deploy_command
echo -ne "------------------------------------------------\n"
$deploy_command