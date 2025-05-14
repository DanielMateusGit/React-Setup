#!/bin/bash

# Show help message
help() {
  cat <<'EOF'
  ____                 _              _               
 |  _ \ ___  __ _  ___| |_   ___  ___| |_ _   _ _ __  
 | |_) / _ \/ _` |/ __| __| / __|/ _ \ __| | | | '_ \ 
 |  _ <  __/ (_| | (__| |_  \__ \  __/ |_| |_| | |_) |
 |_| \_\___|\__,_|\___|\__| |___/\___|\__|\__,_| .__/ 
                                               |_|    
                                               
React Vite Setup Script
This script helps you create, run, and manage a Dockerized React project.

What can you do?

  → Create a new React project with Vite and Docker setup
  → Run the React project inside a Docker container for development
  → Open an interactive terminal for a running Docker container
  → Stop and remove containers, networks, and volumes for the project
  → Install additional functionality into an existing app
  → Show this help message

Commands:

  ./react-vite-setup.sh create <app-name> [port]   
  ./react-vite-setup.sh run <app-name>                        
  ./react-vite-setup.sh terminal <app-name>             
  ./react-vite-setup.sh cleanup <app-name>                    
  ./react-vite-setup.sh install <dependency-name> in <app-name>    
  ./react-vite-setup.sh --help     

EOF
}

log() {
  echo -e "\e[32m[INFO] $1\e[0m"  # Green text for informational logs
}

error() {
  echo -e "\e[31m[ERROR] $1\e[0m" >&2  # Red text for error logs
}

# Check if Docker is installed and running
check_docker() {
  log "Checking if Docker is installed..."
  if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker and try again."
    exit 1
  fi

  log "Checking if Docker daemon is running..."
  if ! docker info &> /dev/null; then
    error "Docker daemon is not running. Please start Docker and try again."
    exit 1
  fi
  log "Docker is installed and running."
}

check_os() {
  log "Checking operating system..."
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    log "Warning: Running this script on Windows without WSL may cause issues. Consider using WSL."
  fi
}

validate_project_name() {
  log "Validating project name: $1"
  if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Invalid project name '$1'. Use only letters, numbers, dashes, and underscores."
    exit 1
  fi
  log "Project name '$1' is valid."
}

# Create a new React project with Vite and add Docker setup
create() {
  local app_name=${1:-jumpstart}  # Default to 'jumpstart' if no app name is provided
  local port=${2:-5173}  # Default to 5173 if no port is provided

  validate_project_name "$app_name"

  log "Creating a new React project: $app_name"

  # Create the Vite project with the React template
  log "Running Vite project creation command..."
  docker run --rm -v "$PWD":/app -w /app node:latest npx create-vite@latest "$app_name" --template react-ts --no-interactive

  # Navigate to the project directory
  if [ -d "$app_name" ]; then
    cd "$app_name" || exit
    log "Navigated to project directory: $app_name"
  else
    error "Failed to create project directory '$app_name'."
    exit 1
  fi

  # Add Dockerfile
  log "Creating Dockerfile..."
  cat <<EOF > Dockerfile
# Use the official Node.js image
FROM node:latest

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose the port Vite uses
EXPOSE ${port}

# Start the development server
CMD ["npm", "run", "dev", "--", "--host"]
EOF

  # Add docker-compose.yml
  log "Creating docker-compose.yml..."
  cat <<EOF > docker-compose.yml

services:
  react-app:
    container_name: ${app_name}
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "${port}:${port}" # Map the custom port
    volumes:
      - .:/app      # Mount the current directory to the container
      - /app/node_modules # Avoid overwriting node_modules
    stdin_open: true
    tty: true
    environment:
      - CHOKIDAR_USEPOLLING=true # Enable polling for file changes
EOF

  # Return to the original directory
  cd ..
  log "New React project: $app_name created successfully."
}

# Run the React project inside a Docker container for development
run() {
  local app_name=${1:-jumpstart}  # Default to 'jumpstart' if no app name is provided

  log "Attempting to run the React project: $app_name"

  # Navigate to the project directory
  if [ -d "$app_name" ]; then
    cd "$app_name" || exit
    log "Navigated to project directory: $app_name"

    # Start the Docker container using docker-compose
    log "Starting the Docker container for project: $app_name"
    docker-compose up
  else
    error "Project directory '$app_name' does not exist."
    exit 1
  fi
}

# Run the interactive terminal for a running Docker container
terminal() {
  local container_name=${1}  # The container name is passed as the first argument

  # Check if the container name is provided
  if [ -z "$container_name" ]; then
    error "No container name provided."
    echo "Usage: ./react-vite-setup.sh terminal <container-name>"
    exit 1
  fi

  log "Attempting to open an interactive terminal for container: $container_name"

  # Check if the container is running
  if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
    log "Container '$container_name' is running. Opening terminal..."
    # Open an interactive terminal in the container
    docker exec -it "$container_name" sh
  else
    error "Container '$container_name' is not running."
    exit 1
  fi
}

cleanup() {
  local app_name=${1:-jumpstart}  # Default to 'jumpstart' if no app name is provided

  # Check if the project directory exists
  if [ -d "$app_name" ]; then
    log "Stopping and removing Docker containers, networks, and volumes for project '$app_name'..."

    # Navigate to the project directory
    cd "$app_name" || exit

    # Stop and remove containers, networks, and volumes using docker-compose
    docker-compose down --volumes --remove-orphans

    # Navigate back to the parent directory
    cd ..

    # Remove the project directory
    log "Removing project directory '$app_name'..."
    rm -rf "$app_name"

    log "Cleanup complete for project '$app_name'."
  else
    error "Project directory '$app_name' does not exist."
    exit 1
  fi

  log "All Docker resources and project files have been cleaned up."
}

# Install dependencies
install() {
  local deps_dir="./deps"
  local dependency_name=$1
  local keyword=$2
  local app_name=$3
  local dependency_file="$deps_dir/$dependency_name.sh"

  # Validate input arguments
  if [ -z "$dependency_name" ] || [ "$keyword" != "in" ] || [ -z "$app_name" ]; then
    error "Invalid syntax. Usage: ./react-vite-setup.sh install <dependency-name> in <app-name>"
    exit 1
  fi

  # Validate the app directory
  if [ ! -d "$app_name" ]; then
    error "Project directory '$app_name' does not exist."
    exit 1
  fi

  # Validate the dependencies directory
  if [ ! -d "$deps_dir" ]; then
    error "Dependencies directory '$deps_dir' does not exist."
    exit 1
  fi

  # Validate the dependency file
  if [ ! -f "$dependency_file" ]; then
    error "Dependency file '$dependency_file' does not exist."
    exit 1
  fi

  # Source the dependency file
  log "Sourcing dependency file: $dependency_file"
  source "$dependency_file"

  # Check if the function exists in the sourced file
  if declare -f "$dependency_name" > /dev/null; then
    log "Executing function '$dependency_name' from '$dependency_file'..."
    "$dependency_name" "$app_name"  # Call the function and pass the app name
  else
    error "Function '$dependency_name' not found in the dependency file."
    exit 1
  fi
}

# Parse arguments to allow --help and similar formats
case "$1" in
  create|run|terminal|cleanup)
    check_os
    "$1" "${@:2}" || help
    ;;
  install)
    if [ "$2" ] && [ "$3" == "in" ] && [ "$4" ]; then
      check_os
      install "$2" "$3" "$4"
    else
      error "Invalid syntax. Usage: ./react-vite-setup.sh install <dependency-name> in <app-name>"
      exit 1
    fi
    ;;
  --help|-h)
    help
    ;;
  *)
    error "Unknown command '$1'"
    echo "Use --help to see available commands."
    exit 1
    ;;
esac