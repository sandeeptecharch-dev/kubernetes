# TechUdaan - Day 4: build your own image and run it on kind,
# without pushing it to any registry.
#
# Build:  docker build -t techudaan-hello:1.0 my-app/
# Load:   kind load docker-image techudaan-hello:1.0 --name techudaan
# Run:    kubectl apply -f my-app/my-app.yaml
FROM nginx:1.27-alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
