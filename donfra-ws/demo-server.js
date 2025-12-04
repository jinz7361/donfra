
/**
 * @type {any}
 */
const WebSocket = require('ws')
const http = require('http')
const https = require('https')
const StaticServer = require('node-static').Server
const ywsUtils = require('y-websocket/bin/utils')
const setupWSConnection = ywsUtils.setupWSConnection
const docs = ywsUtils.docs
const env = require('lib0/environment')
const nostatic = env.hasParam('--nostatic')

const production = process.env.PRODUCTION != null
const port = process.env.PORT || 6789

const staticServer = nostatic ? null : new StaticServer('../', { cache: production ? 3600 : false, gzip: production })

const server = http.createServer((request, response) => {
  // health check
  if (request.url === '/health') {
    response.writeHead(200, { 'Content-Type': 'application/json' })
    response.end(JSON.stringify({ response: 'ok' }))
    return
  }

  // control endpoint: close a Yjs room and notify connected clients
  if ((request.method === 'POST') && (request.url === '/room/close' || request.url === '/api/room/close')) {
    let body = ''
    request.on('data', (chunk) => { body += chunk })
    request.on('end', () => {
      try {
        const payload = body ? JSON.parse(body) : {}
        const room = payload.room || payload.id || 'default-codepad-room'

        if (!docs.has(room)) {
          response.writeHead(404, { 'Content-Type': 'application/json' })
          response.end(JSON.stringify({ ok: false, message: 'room not found' }))
          return
        }

        const entry = docs.get(room)
        // log closure intent
        try {
          const connsCount = entry && entry.conns ? entry.conns.size : 0
          console.log(`${new Date().toISOString()} Closing room '${room}' with ${connsCount} connection(s)`)
        } catch (err) { /* ignore logging errors */ }

        // notify each connected socket before closing
        try {
          if (entry && entry.conns) {
            for (const conn of entry.conns.keys()) {
              try {
                conn.send(JSON.stringify({ type: 'donfra:room_closed', room }))
              } catch (err) { /* ignore send errors */ }
            }
            // close connections
            for (const conn of entry.conns.keys()) {
              try { conn.close(4000, 'room closed') } catch (err) { }
            }
          }
        } catch (err) {
          // best-effort; continue to delete doc
        }

        // remove doc from memory so new connections will start fresh
        try {
          docs.delete(room)
          console.log(`${new Date().toISOString()} Room '${room}' deleted from docs`)
        } catch (err) { /* ignore deletion errors */ }

        response.writeHead(200, { 'Content-Type': 'application/json' })
        response.end(JSON.stringify({ ok: true }))
        return
      } catch (err) {
        response.writeHead(500, { 'Content-Type': 'application/json' })
        response.end(JSON.stringify({ ok: false, error: String(err) }))
        return
      }
    })
    return
  }

})
const wss = new WebSocket.Server({ server })

wss.on('connection', (conn, req) => {
  setupWSConnection(conn, req, { gc: req.url.slice(1) !== 'ws/prosemirror-versions' })
})

// log some stats
setInterval(() => {
  let conns = 0
  docs.forEach(doc => { conns += doc.conns.size })
  const stats = {
    conns,
    docs: docs.size,
    websocket: `ws://localhost:${port}`,
    http: `http://localhost:${port}`
  }
  console.log(`${new Date().toISOString()} Stats: ${JSON.stringify(stats)}`)
  // If the number of connections changed since last check, POST headcount to API
  if (typeof global.__lastConns === 'undefined') global.__lastConns = -1
  if (conns !== global.__lastConns) {
    global.__lastConns = conns
    const updateUrl = process.env.ROOM_UPDATE_URL || 'http://localhost:8080/api/room/update-people'
    try {
      const payload = JSON.stringify({ headcount: conns })
      const u = new URL(updateUrl)
      const options = {
        hostname: u.hostname,
        port: u.port || (u.protocol === 'https:' ? 443 : 80),
        path: u.pathname + (u.search || ''),
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload)
        }
      }

      const reqLib = u.protocol === 'https:' ? https : http
      const req = reqLib.request(options, res => {
        let body = ''
        res.setEncoding('utf8')
        res.on('data', chunk => { body += chunk })
        res.on('end', () => {
          console.log(`${new Date().toISOString()} Posted headcount ${conns} to ${updateUrl}: ${body}`)
        })
      })
      req.on('error', err => {
        console.error(`${new Date().toISOString()} Error posting to ${updateUrl}: ${err.message}`)
      })
      req.write(payload)
      req.end()
    } catch (err) {
      console.error(`${new Date().toISOString()} Error building request for ${updateUrl}: ${err.message}`)
    }
  }
}, 3000)

server.listen(port, '0.0.0.0')

console.log(`Listening to http://localhost:${port} (${production ? 'production + ' : ''} ${nostatic ? 'no static content' : 'serving static content'})`)
