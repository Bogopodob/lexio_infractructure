FROM node:22-alpine

WORKDIR /usr/src/app

RUN apk add --no-cache libc6-compat

CMD ["sh", "-c", "if [ -f package.json ]; then npm install && npm run dev -- --host 0.0.0.0 --port 5173; else node -e \"const http=require('http');http.createServer((req,res)=>{res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end('<!doctype html><html><body><h1>q_frontend is running</h1><p>Add your Vite app to /frontend.</p></body></html>');}).listen(5173,'0.0.0.0')\"; fi"]
