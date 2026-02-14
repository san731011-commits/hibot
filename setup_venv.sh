#!/bin/bash
cd /home/san/.openclaw/workspace
source .venv/bin/activate
pip install --upgrade pip
pip install discord.py requests
python -c "import discord; print('discord.py:', discord.__version__)"
python -c "import requests; print('requests:', requests.__version__)"
echo "✅ 가상환경 설정 완료!"
echo ""
echo "사용법: source .venv/bin/activate"
