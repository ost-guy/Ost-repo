# qt-wayland-config.py

# This script configures QT to run on Wayland

import os

# Set environment variable for Wayland
os.environ['QT_QPA_EGLFS_INTEGRATION'] = 'wayland'
os.environ['QT_QPA_PLATFORM'] = 'wayland'

# Additional configuration can be added here

print('QT Configuration for Wayland set successfully')