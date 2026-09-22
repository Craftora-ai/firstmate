import json, sys, time, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
CFG=sys.argv[2]
class H(BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        cfg=json.load(open(CFG))
        auth=self.headers.get('Authorization','')
        q=list(body.get('questions',{}).keys())
        with open(os.path.join(os.path.dirname(CFG),'requests.log'),'a') as f:
            f.write(json.dumps({"questions":q,"auth_ok":auth=="Bearer test-key","path":self.path})+"\n")
        if 'stakes' in q:
            s=cfg['stakes']; time.sleep(s.get('delay',0))
            if s.get('http',200)!=200:
                self.send_response(s['http']); self.end_headers(); self.wfile.write(b'boom'); return
            resp={"model":"jev-latest","answers":{"stakes":s['answer']},"usage":{"input_tokens":10,"output_tokens":2}}
        else:
            opts=body['questions']['rule']['options'] if 'options' in body['questions']['rule'] else None
            a=dict(cfg['rule'])
            if a.get('confidence','__keep__') is None: a.pop('confidence')
            resp={"model":"jev-latest","answers":{"rule":a},"usage":{"input_tokens":100,"output_tokens":3}}
        b=json.dumps(resp).encode()
        self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1])),H).serve_forever()
