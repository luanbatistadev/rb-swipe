#!/bin/bash

APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

find "$APP_PATH" -name '*_sim.framework' -type d | while read -r SIMULATOR_FRAMEWORK
do
    echo "Removing simulator framework: $SIMULATOR_FRAMEWORK"
    rm -rf "$SIMULATOR_FRAMEWORK"
done

find "$APP_PATH" -name '*Simulator*.framework' -type d | while read -r SIMULATOR_FRAMEWORK
do
    echo "Removing simulator framework: $SIMULATOR_FRAMEWORK"
    rm -rf "$SIMULATOR_FRAMEWORK"
done
