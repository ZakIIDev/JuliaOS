# To run this script, you will need:
# - Java 11+
# - openapi-generator-cli.jar, which can be downloaded from https://openapi-generator.tech/docs/installation/#jar

JARNAME="openapi-generator-cli.jar"

if [ ! -f "$JARNAME" ]; then
    echo "Missing $JARNAME. Please download it from https://openapi-generator.tech/docs/installation/#jar"
    exit 1
fi

java -jar $JARNAME generate \
    -i ./backend/src/api/spec/api-spec.yaml \
    -t ./backend/src/api/spec/templates/ \
    -g julia-server \
    -o ./backend/src/api/server \
    --additional-properties=packageName=JuliaOSServer \
    --additional-properties=exportModels=true