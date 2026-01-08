
# STAGE 1: BUILDER - install all dependencies and compile the frontend application (Angular). 

FROM node:20 AS builder

WORKDIR /app

COPY package*.json ./

# Download and install all Node dependencies
RUN npm install

COPY . .

# Execute the production build command (Angular's compiler).
RUN npm run build --prod
# The resulting production optimized files are usually placed in a '/app/dist' subfolder.



# STAGE 2: RUNTIME - Use a minimal web server image (Nginx) and only copies the necessary files

FROM nginx:alpine

# Copy the static build artifacts from the previous stage
COPY --from=builder /app/dist/angular-conduit /usr/share/nginx/html

# Nginx's default port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 
# Start Nginx with 'daemon off;' for running Nginx in foreground as PID 1.