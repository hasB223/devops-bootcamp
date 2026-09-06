#!/bin/bash
curl -fsSL https://get.docker.com | sh
docker run -d -p 80:80 nginx
docker run -d --network host cloudflare/cloudflared:latest \
  tunnel --no-autoupdate run --token ${tunnel_token}
