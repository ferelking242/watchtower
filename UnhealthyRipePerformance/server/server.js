'use strict';
const app = require('./src/api');

const PORT = parseInt(process.env.PORT || '8080', 10);

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[Watchtower Server] listening on :${PORT}`);
  console.log(`[Watchtower Server] API key: ${process.env.API_KEY || '(none — set API_KEY env var)'}`);
});
