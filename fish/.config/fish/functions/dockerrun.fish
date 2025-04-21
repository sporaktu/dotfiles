function dockerrun
    # Ensure Docker daemon is running
    if not pgrep -x dockerd > /dev/null
        echo "Starting Docker daemon..."
        sudo systemctl start docker
    end

    # Execute the Docker command
    docker $argv

    # Check if there are any running containers
    if not docker ps -q | read
        echo "No active containers. Stopping Docker daemon..."
        sudo systemctl stop docker
    end
end

