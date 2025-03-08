call build_web.bat
cd build/web
explorer http://localhost:8000/
python -m http.server 8000
