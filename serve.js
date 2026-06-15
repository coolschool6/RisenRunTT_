var http = require('http');
var fs = require('fs');
var path = require('path');
var root = __dirname;
var mime = { '.html':'text/html','.css':'text/css','.js':'application/javascript','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml','.ico':'image/x-icon' };
http.createServer(function(req,res){
  var urlPath = req.url.split('?')[0];
  var file = path.join(root, urlPath === '/' ? 'index.html' : urlPath);
  fs.readFile(file, function(err, data){
    if(err){ res.writeHead(404); res.end('404'); return; }
    res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'text/plain' });
    res.end(data);
  });
}).listen(5500, '127.0.0.1', function(){ console.log('Server running at http://127.0.0.1:5500'); });
