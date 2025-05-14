tailwind() {
    # app_name and container_name are the same
    local app_name=${1:-jumpstart}  
    local container_name=${app_name} # Assuming container_name matches app_name

    # Check if the app_name directory exists
    if [ ! -d "$app_name" ]; then
        error "Project directory '$app_name' does not exist."
        exit 1
    fi

    # Check if the Docker container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        error "Docker container '$container_name' is not running. Run the project before install dependencies."
        exit 1
    fi

    # Check if vite.config.ts exists in the app directory
    if ! docker exec "$container_name" sh -c "test -f vite.config.ts"; then
        error "File 'vite.config.ts' does not exist in the container '$container_name'."
        exit 1
    fi

    # Install TailwindCSS package in Vite
    log "Installing TailwindCSS and its Vite plugin..."
    if ! docker exec "$container_name" sh -c "npm install tailwindcss @tailwindcss/vite"; then
        error "Failed to install TailwindCSS and its Vite plugin."
        exit 1
    fi

    # Modify vite.config.ts to add TailwindCSS plugin
    log "Modifying vite.config.ts to include TailwindCSS plugin..."
    if ! docker exec "$container_name" sh -c "
        sed -i '1i import tailwindcss from \"@tailwindcss/vite\";' vite.config.ts &&
        sed -i '/plugins: \\[/ s/\(.*\)\]/\1, tailwindcss()]/' vite.config.ts
    "; then
        error "Failed to modify vite.config.ts to include TailwindCSS plugin."
        exit 1
    fi
    log "TailwindCSS plugin added to vite.config.ts."

    # Check if src/App.css exists
    if ! docker exec "$container_name" sh -c "test -f src/App.css"; then
        error "File 'src/App.css' does not exist in the container '$container_name'."
        exit 1
    fi

    # Modify src/App.css to include TailwindCSS directives
    log "Adding TailwindCSS directives to src/App.css..."
    if ! docker exec "$container_name" sh -c "
        sed -i '1i @import \"tailwindcss\";' src/App.css
    "; then
        error "Failed to add TailwindCSS directives to src/App.css."
        exit 1
    fi
    log "TailwindCSS directives added to src/App.css."
    log "TailwindCSS has been successfully installed and configured."
}