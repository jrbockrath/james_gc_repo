#!/bin/bash

# Define the base directory
BASE_DIR="startover"
CHARTS_DIR="$BASE_DIR/helm-charts"

# Function to remove unnecessary directories and files
cleanup_directory_structure() {
    echo "Cleaning up unnecessary files and directories..."

    # Remove unnecessary directories and files in app1
    rm -rf $BASE_DIR/app1/charts
    rm -rf $BASE_DIR/app1/templates
    rm -f $BASE_DIR/app1/app.py $BASE_DIR/app1/Dockerfile $BASE_DIR/app1/linkedin-poster-vertex.py $BASE_DIR/app1/requirements.txt

    # Remove unnecessary directories app2 and app3 if they are empty
    rmdir $BASE_DIR/app2 2>/dev/null
    rmdir $BASE_DIR/app3 2>/dev/null

    # Remove any empty or incorrect charts/ directories from helm-charts/app1-chart
    if [ -d "$CHARTS_DIR/app1-chart/charts" ]; then
        echo "Removing unnecessary 'charts/' folder from $CHARTS_DIR/app1-chart..."
        rm -rf "$CHARTS_DIR/app1-chart/charts"
    fi

    # Ensure app2-chart and app3-chart have the correct structure
    for chart in app2-chart app3-chart; do
        if [ ! -f "$CHARTS_DIR/$chart/Chart.yaml" ] || [ ! -f "$CHARTS_DIR/$chart/values.yaml" ]; then
            echo "Copying Chart.yaml and values.yaml from app1-chart to $chart..."
            cp $CHARTS_DIR/app1-chart/Chart.yaml $CHARTS_DIR/$chart/
            cp $CHARTS_DIR/app1-chart/values.yaml $CHARTS_DIR/$chart/
        fi

        # Ensure templates directory exists
        mkdir -p $CHARTS_DIR/$chart/templates
    done
}

# Execute the cleanup functions
cleanup_directory_structure

echo "Cleanup completed successfully!"
