#!/usr/bin/node

const r = require('rethinkdb');
const note = process.env.STF_PROVIDER_NOTE;
const hostname = process.env.HOSTNAME;

if (!note) {
  console.log("Note is not provided. Exiting");
  process.exit(0);
}

r.connect({
  host: process.env.RETHINKDB_URL,
  port: process.env.RETHINKDB_PORT,
  db: 'stf',
  authKey: process.env.RETHINKDB_ENV_AUTHKEY
}, (err, conn) => {
  if (err) throw err;

  r.table('devices')
    .filter({
      provider: {
          name: `${hostname}`
          }
    })
    .update({notes: `${note}`})
    .run(conn, (err, result) => {
      if (err) throw err;

      conn.close();
      console.log(`Note ${note} added to all devices from ${hostname}`);
    });
});
