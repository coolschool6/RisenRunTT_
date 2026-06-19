var http = require('http');
var fs = require('fs');
var path = require('path');
var root = __dirname;
var mime = {
  '.html':'text/html',
  '.css':'text/css',
  '.js':'application/javascript',
  '.json':'application/json',
  '.png':'image/png',
  '.jpg':'image/jpeg',
  '.svg':'image/svg+xml',
  '.ico':'image/x-icon',
  '.webmanifest':'application/manifest+json'
};

var staticFiles = {
  '/manifest.json': 'application/manifest+json',
  '/sw.js': 'application/javascript'
};

http.createServer(function(req, res){
  var urlPath = req.url.split('?')[0];

  // Security headers
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

  var file = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
  var ext = path.extname(file);
  var contentType = staticFiles[urlPath] || mime[ext] || 'text/plain';

  fs.readFile(file, function(err, data){
    if(err){
      // Try serving index.html for SPA-like fallback (for confirmation page etc.)
      if (urlPath !== '/' && !path.extname(urlPath)) {
        var fallback = path.join(root, urlPath.replace(/^\//, ''));
        fs.readFile(fallback, function(err2, data2){
          if(err2){ res.writeHead(404); res.end('404'); return; }
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end(data2);
        });
        return;
      }
      res.writeHead(404); res.end('404'); return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
}).listen(5500, '127.0.0.1', function(){ console.log('Rise & Run TT server running at http://127.0.0.1:5500'); });
