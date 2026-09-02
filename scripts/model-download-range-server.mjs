#!/usr/bin/env node

import http from "node:http";

const port = Number(process.argv[2] || 8765);
const total = Number(process.argv[3] || 64 * 1024 * 1024);
const chunkSize = 256 * 1024;
const etag = '"matths-model-download-qa-v1"';

const server = http.createServer((request, response) => {
  const range = /^bytes=(\d+)-(\d*)$/.exec(request.headers.range || "");
  const start = range ? Number(range[1]) : 0;
  const requestedEnd = range?.[2] ? Number(range[2]) : total - 1;
  const end = Math.min(total - 1, requestedEnd);
  if (!Number.isFinite(start) || start < 0 || start >= total || end < start) {
    response.writeHead(416, { "Content-Range": `bytes */${total}` });
    response.end();
    return;
  }
  const partial = Boolean(range);
  const headers = {
    "Accept-Ranges": "bytes",
    "Cache-Control": "no-store",
    "Content-Length": end - start + 1,
    "Content-Type": "application/octet-stream",
    ETag: etag,
    "Last-Modified": "Tue, 12 Aug 2026 00:00:00 GMT",
  };
  if (partial) headers["Content-Range"] = `bytes ${start}-${end}/${total}`;
  response.writeHead(partial ? 206 : 200, headers);

  let offset = start;
  const pump = () => {
    if (offset > end) {
      response.end();
      return;
    }
    const count = Math.min(chunkSize, end - offset + 1);
    const data = Buffer.alloc(count, 0x5a);
    if (offset === 0 && count >= 4) data.set(Buffer.from("GGUF"), 0);
    offset += count;
    if (!response.write(data)) response.once("drain", () => setTimeout(pump, 18));
    else setTimeout(pump, 18);
  };
  pump();
});

server.listen(port, "0.0.0.0", () => {
  process.stdout.write(`READY http://0.0.0.0:${port}/model.gguf bytes=${total}\n`);
});
