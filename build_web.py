#!/usr/bin/env python3
import os
import subprocess
import shutil
import platform
import sys

# Point this to where you installed emscripten
EMSCRIPTEN_SDK_DIR = "L:\\emsdk"  # Change this to your emscripten path
OUT_DIR = "build/web"

# Create output directory if it doesn't exist
os.makedirs(OUT_DIR, exist_ok=True)

# Set up environment variables
os.environ["EMSDK_QUIET"] = "1"

# Call emscripten environment setup
if platform.system() == "Windows":
    emscripten_env_script = os.path.join(EMSCRIPTEN_SDK_DIR, "emsdk_env.bat")
else:  # Linux/macOS
    emscripten_env_script = os.path.join(EMSCRIPTEN_SDK_DIR, "emsdk_env.sh")

# Build with Odin
odin_cmd = [
    "odin", "build", "source/main_web",
    "-target:js_wasm32",
    "-build-mode:obj",
    "-define:RAYLIB_WASM_LIB=env.o",
    "-define:RAYGUI_WASM_LIB=env.o",
    "-vet",
    "-strict-style",
    f"-out:{OUT_DIR}/game"
]

result = subprocess.run(odin_cmd, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
if result.returncode != 0:
    print(f"Odin build failed: {result.stderr.decode()}")
    sys.exit(1)

# Get Odin root path
result = subprocess.run(["odin", "root"], capture_output=True, text=True)
ODIN_PATH = result.stdout.strip()

# Copy odin.js to output directory
shutil.copy(os.path.join(ODIN_PATH, "core", "sys", "wasm", "js", "odin.js"), OUT_DIR)

# Set up files for emcc
files = [
    f"{OUT_DIR}/game.wasm.o",
    f"{ODIN_PATH}/vendor/raylib/wasm/libraylib.a",
    f"{ODIN_PATH}/vendor/raylib/wasm/libraygui.a"
]

# Set up flags for emcc
flags = [
    "-sUSE_GLFW=3",
    "-sWASM_BIGINT",
    "-sWARN_ON_UNDEFINED_SYMBOLS=0",
    "-sASSERTIONS",
    f"--shell-file", "source/main_web/index_template.html"
]

# Run emcc
emcc_cmd = ["emcc", "-o", f"{OUT_DIR}/index.html"] + files + flags
result = subprocess.run(os.path.join(EMSCRIPTEN_SDK_DIR, "emsdk_env.bat") + " && " + ' '.join(emcc_cmd), shell=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
if result.returncode != 0:
    print("emcc failed")
    sys.exit(1)

# Clean up temporary file
if os.path.exists(f"{OUT_DIR}/game.wasm.o"):
    os.remove(f"{OUT_DIR}/game.wasm.o")

print(f"Web build created in {OUT_DIR}")
