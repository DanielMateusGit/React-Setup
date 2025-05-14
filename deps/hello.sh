tailwind() {
    # The container name where i want to install the dependency 
    local container_name=${2} 

    # Install tailwind package in vite
    docker exec $container_name sh -c "npm install tailwindcss @tailwindcss/vite"

    # Change vite.config.ts file to add tailwindcss plugin
    # docker exec $container_name sh -c "echo \"import { defineConfig } from 'vite';\" > vite.config.ts"

}