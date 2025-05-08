#!/bin/bash

# Show help message
help() {
  echo "React Vite Setup Script"
  echo "This script helps you create, run, and manage a Dockerized React project with Vite.js."
  echo
  echo "Usage:"
  echo "  ./react-vite-setup.sh create <app-name>   → Create a new React project with Vite and Docker setup"
  echo "  ./react-vite-setup.sh run <app-name>      → Run the React project inside a Docker container for development"
  echo "  ./react-vite-setup.sh terminal <container-name> → Open an interactive terminal for a running Docker container"
  echo "  ./react-vite-setup.sh --help              → Show this help message"
}

# Create a new React project with Vite and add Docker setup
create() {
  local app_name=${1:-jumpstart}  # Default to 'jumpstart' if no app name is provided

  # Create the Vite project
  docker run --rm -v "$PWD":/app -w /app node:18 npm create vite@latest "$app_name" -- --template react

  # Navigate to the project directory
  cd "$app_name" || exit

  # Add Dockerfile
  cat <<EOF > Dockerfile
# Use the official Node.js image
FROM node:18

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose the port Vite uses
EXPOSE 5173

# Start the development server
CMD ["npm", "run", "dev", "--", "--host"]
EOF

  # Add docker-compose.yml
  cat <<EOF > docker-compose.yml
version: '3.8'

services:
  react-app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "5173:5173" # Map Vite's default port to the host
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
}

# Run the React project inside a Docker container for development
run() {
  local app_name=${1:-jumpstart}  # Default to 'jumpstart' if no app name is provided

  # Navigate to the project directory
  if [ -d "$app_name" ]; then
    cd "$app_name" || exit

    # Start the Docker container using docker-compose
    docker-compose up
  else
    echo "Error: Project directory '$app_name' does not exist."
    exit 1
  fi
}

# Run the interactive terminal for a running Docker container
terminal() {
  local container_name=${1}  # The container name is passed as the first argument

  # Check if the container name is provided
  if [ -z "$container_name" ]; then
    echo "Error: No container name provided."
    echo "Usage: ./react-vite-setup.sh terminal <container-name>"
    exit 1
  fi

  # Check if the container is running
  if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
    # Open an interactive terminal in the container
    docker exec -it "$container_name" sh
  else
    echo "Error: Container '$container_name' is not running."
    exit 1
  fi
}

# Parse arguments to allow --help and similar formats
case "$1" in
  create|run|terminal)
    "$1" "${@:2}" || help
    ;;
  --help|-h)
    help
    ;;
  *)
    echo "Error: Unknown command '$1'"
    echo "Use --help to see available commands."
    exit 1
    ;;
esac