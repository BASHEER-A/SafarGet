#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SafarGet yt-dlp wrapper
Simple Python script to run yt-dlp with proper environment setup
"""

import os
import sys
import subprocess
import re

def setup_environment():
    """Setup environment for yt-dlp"""
    # Clear Python paths to avoid conflicts
    os.environ['PYTHONPATH'] = ''
    os.environ['PYTHONHOME'] = ''
    os.environ['PYTHONUNBUFFERED'] = '1'
    
    # Set LC_ALL to avoid locale issues
    os.environ['LC_ALL'] = 'C'
    
    # Disable SSL warnings
    os.environ['PYTHONWARNINGS'] = 'ignore:Unverified HTTPS request'

def find_yt_dlp_binary():
    """Find the yt-dlp binary in the app bundle"""
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    binary_path = os.path.join(script_dir, 'yt-dlp')
    
    if os.path.exists(binary_path) and os.access(binary_path, os.X_OK):
        return binary_path
    
    return None

def main():
    """Main function"""
    setup_environment()
    
    # Find the yt-dlp binary
    yt_dlp_path = find_yt_dlp_binary()
    
    if not yt_dlp_path:
        print("Error: yt-dlp binary not found", file=sys.stderr)
        sys.exit(1)
    
    # Prepare arguments
    args = [yt_dlp_path] + sys.argv[1:]
    
    try:
        # Run yt-dlp with the same arguments
        result = subprocess.run(args, check=False)
        sys.exit(result.returncode)
    except Exception as e:
        print(f"Error running yt-dlp: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main() 