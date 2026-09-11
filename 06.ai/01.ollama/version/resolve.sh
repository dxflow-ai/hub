# Ollama is re-published from the upstream image; the web interface is built with
# the current node LTS line, which is the even majors.

echo "VERSION=$(docker_tag ollama/ollama '^[0-9]+\.[0-9]+\.[0-9]+$')"
echo "NODE=$(docker_tag library/node '^[0-9]*[02468]-alpine$' -alpine | sed 's/-alpine$//')"
