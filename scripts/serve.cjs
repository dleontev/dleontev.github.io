const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve('_site');
const types = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.json':'application/json','.png':'image/png','.webp':'image/webp','.ico':'image/x-icon','.jpg':'image/jpeg','.woff2':'font/woff2'};
http.createServer((req,res) => {
  let route;
  try { route = decodeURIComponent(new URL(req.url,'http://localhost').pathname); } catch { res.writeHead(400).end(); return; }
  const full = path.resolve(root, '.'+route);
  if (full !== root && !full.startsWith(root+path.sep)) { res.writeHead(403).end(); return; }
  const candidates = route.endsWith('/') ? [path.join(full,'index.html')] : [full,full+'.html',path.join(full,'index.html')];
  const file = candidates.find(p => fs.existsSync(p) && fs.statSync(p).isFile());
  if (!file) { res.writeHead(404,{'Content-Type':'text/html; charset=utf-8'}); res.end(fs.readFileSync(path.join(root,'404.html'))); return; }
  res.writeHead(200, {'Content-Type':types[path.extname(file)] || 'application/octet-stream'});
  fs.createReadStream(file).pipe(res);
}).listen(Number(process.env.PORT || 4000),'127.0.0.1',() => console.log('Preview: http://127.0.0.1:4000'));
