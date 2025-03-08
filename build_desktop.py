import os
import platform
import shutil
import subprocess

# Set output directory
OUT_DIR = "build/desktop"

# Create output directory if it doesn't exist
os.makedirs(OUT_DIR, exist_ok=True)

# Build the Odin project
ext = "exe" if platform.system() == "Windows" else "bin"
subprocess.run(["odin", "build", "source/main_desktop", f"-out:{OUT_DIR}/game_desktop.{ext}"], check=True)

# Copy assets folder to the output directory
# if os.path.exists("assets"):
#     # Remove destination directory if it exists to avoid errors
#     if os.path.exists(f"{OUT_DIR}/assets"):
#         shutil.rmtree(f"{OUT_DIR}/assets")
#     # Copy the assets folder
#     shutil.copytree("assets", f"{OUT_DIR}/assets")

print(f"Desktop build created in {OUT_DIR}")
