# Variables
CONTAINER_NAME := "rust-android-builder"
IMAGE_NAME := "rust-android:1.90-sdk-36"
USER := `whoami`
USER_ID := `id -u`
GROUP_ID := `id -g`

# Cache volumes - create directories first if they don't exist
CARGO_REGISTRY := env_var('HOME') + "/.cargo/registry"
CARGO_GIT := env_var('HOME') + "/.cargo/git"
GRADLE_CACHE := env_var('HOME') + "/.gradle"
ANDROID_SDK_HOME := env_var('HOME') + "/.android"

# Start container if not running
_start-container:
    #!/usr/bin/env bash
    if ! docker ps --format '{{{{.Names}}}}' | grep -q "^{{CONTAINER_NAME}}$"; then
        echo "Starting container {{CONTAINER_NAME}}..."
        docker run -d -it --rm \
            --name {{CONTAINER_NAME}} \
            -v "$(pwd):/src" \
            -w /src \
            --entrypoint /bin/bash \
            {{IMAGE_NAME}}

        # docker exec -it {{CONTAINER_NAME}} useradd -u {{USER_ID}} -g {{GROUP_ID}} -m -s /bin/bash {{USER}}

        # Wait for container to be ready
        sleep 2
        echo "Container started with UID={{USER_ID}} GID={{GROUP_ID}}"
    else
        echo "Container {{CONTAINER_NAME}} is already running"
    fi

# Stop and remove container
_stop-container:
    @echo "Stopping container {{CONTAINER_NAME}}..."
    docker kill {{CONTAINER_NAME}} 2>/dev/null || true
    docker rm {{CONTAINER_NAME}} 2>/dev/null || true

# Execute command in container
_exec +ARGS:
    # docker exec -it --user {{USER}} {{CONTAINER_NAME}} {{ARGS}}
    docker exec -it {{CONTAINER_NAME}} {{ARGS}}

# Generate signing key
genkey key_alias key_store: _start-container
    @echo "Generating key {{key_alias}}..."
    just _exec keytool -genkey -v -keystore {{key_store}} -alias {{key_alias}} -keyalg RSA -keysize 2048 -validity 10000

# Build project
build: _start-container
    @echo "Building..."
    just _exec gradle assembleRelease

# Sign APK
sign key_alias key_store: _start-container
    @echo "Signing APK..."
    just _exec apksigner sign --ks-key-alias {{key_alias}} --ks {{key_store}} android/build/outputs/apk/release/android-release-unsigned.apk
    sudo cp android/build/outputs/apk/release/android-release-unsigned.apk \
        android/build/outputs/apk/release/android-release-signed.apk

# Install APK on device
install:
    @echo "Installing..."
    adb install -r android/build/outputs/apk/release/android-release-signed.apk

# Full workflow: build, sign, install
run key_alias key_store: _start-container build (sign key_alias key_store) install _stop-container

# Clean project
clean: _start-container
    @echo "Cleaning project..."
    just _exec cargo clean
    just _exec gradle clean
    just _stop-container

# Stop container manually
stop: _stop-container

# Restart container
restart: _stop-container _start-container

# Show container status
status:
    @echo "Container status:"
    @docker ps -a --filter name={{CONTAINER_NAME}} --format "table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.Ports}}}}" || echo "Container does not exist"

# Open shell in container
shell: _start-container
    just _exec bash 2>/dev/null || true
    just _stop-container

# Show build logs
logs:
    @docker logs {{CONTAINER_NAME}} --tail 100 -f

# Show cache directories info
cache-info:
    @echo "Cache directories:"
    @echo "  Cargo registry: {{CARGO_REGISTRY}}"
    @echo "  Cargo git: {{CARGO_GIT}}"
    @echo "  Gradle: {{GRADLE_CACHE}}"
    @echo "  Android: {{ANDROID_SDK_HOME}}"
    @echo ""
    @echo "Container mounts:"
    @docker inspect {{CONTAINER_NAME}} --format '{{{{json .Mounts}}}}' 2>/dev/null | jq || echo "Container not running"

# Verify cache is working
test-cache: _start-container
    @echo "Testing cache..."
    just _exec ls -la /cargo_home/registry || echo "Cargo registry not mounted"
    just _exec ls -la /gradle_home || echo "Gradle cache not mounted"
