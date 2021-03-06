#!/bin/bash
#
# Starts tests from within the container
#
# License: according to LICENSE.md in the root directory of the PX4 Firmware repository
set -e

# handle cleaning command
do_clean=true
if [ "$1" = "-o" ]
then
	echo not cleaning
	do_clean=false
fi

# determine the directory of the source given the directory of this script
pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null
ORIG_SRC=$(dirname $SCRIPTPATH)

# set paths
JOB_DIR=$(dirname $ORIG_SRC)
CATKIN_DIR=$JOB_DIR/catkin
BUILD_DIR=$CATKIN_DIR/build/px4
SRC_DIR=${CATKIN_DIR}/src/px4

echo setting up ROS paths
if [ -f /opt/ros/indigo/setup.bash ]
then
	source /opt/ros/indigo/setup.bash
elif [ -f /opt/ros/kinetic/setup.bash ]
then
	source /opt/ros/kinetic/setup.bash
else
	echo "could not find /opt/ros/{ros-distro}/setup.bash"
	exit 1
fi
export ROS_HOME=$JOB_DIR/.ros
export ROS_LOG_DIR=$ROS_HOME/log
export ROS_TEST_RESULT_DIR=$ROS_HOME/test_results/px4

PX4_LOG_DIR=$ROS_HOME/rootfs/fs/microsd/log
TEST_RESULT_TARGET_DIR=$JOB_DIR/test_results

# TODO
# BAGS=$ROS_HOME
# CHARTS=$ROS_HOME/charts
# EXPORT_CHARTS=/sitl/testing/export_charts.py

echo setting up gazebo paths
source /usr/share/gazebo/setup.sh
source $SCRIPTPATH/setup_gazebo_ros.bash ${SRC_DIR} ${BUILD_DIR}

if $do_clean
then
	echo cleaning
	rm -rf $CATKIN_DIR
	rm -rf $ROS_HOME
	rm -rf $TEST_RESULT_TARGET_DIR
else
	echo skipping clean step
fi

echo "=====> compile ($SRC_DIR)"
mkdir -p $ROS_HOME
mkdir -p $CATKIN_DIR/src
mkdir -p $TEST_RESULT_TARGET_DIR
if ! [ -d $SRC_DIR ]
then
	ln -s $ORIG_SRC $SRC_DIR
	ln -s $ORIG_SRC/Tools/sitl_gazebo ${CATKIN_DIR}/src/mavlink_sitl_gazebo
fi
cd $CATKIN_DIR
catkin_make
. ./devel/setup.bash
echo "<====="

# print paths to user
echo -e "JOB_DIR\t\t: $JOB_DIR"
echo -e "ROS_HOME\t: $ROS_HOME"
echo -e "CATKIN_DIR\t: $CATKIN_DIR"
echo -e "BUILD_DIR\t: $BUILD_DIR"
echo -e "SRC_DIR\t\t: $SRC_DIR"
echo -e "ROS_TEST_RESULT_DIR\t: $ROS_TEST_RESULT_DIR"
echo -e "ROS_LOG_DIR\t\t: $ROS_LOG_DIR"
echo -e "PX4_LOG_DIR\t\t: $PX4_LOG_DIR"
echo -e "TEST_RESULT_TARGET_DIR\t: $TEST_RESULT_TARGET_DIR"

# don't exit on error anymore from here on (because single tests or exports might fail)
set +e
echo "=====> run tests"
rostest px4 mavros_posix_tests_iris.launch
rostest px4 mavros_posix_tests_standard_vtol.launch
TEST_RESULT=$?
echo "<====="

# TODO
echo "=====> process test results"
# cd $BAGS
# for bag in `ls *.bag`
# do
# 	echo "processing bag: $bag"
# 	python $EXPORT_CHARTS $CHARTS $bag
# done

echo "copy build test results to job directory"
cp -r $ROS_TEST_RESULT_DIR/* ${TEST_RESULT_TARGET_DIR}
cp -r $ROS_LOG_DIR/* ${TEST_RESULT_TARGET_DIR}
cp -r $PX4_LOG_DIR/* ${TEST_RESULT_TARGET_DIR}
# cp $BAGS/*.bag ${TEST_RESULT_TARGET_DIR}/
# cp -r $CHARTS ${TEST_RESULT_TARGET_DIR}/
echo "<====="

# need to return error if tests failed, else Jenkins won't notice the failure
exit $TEST_RESULT
