'use strict';

const OLD = 'https://dal-login-us.heitaoglobal.com:8082/account';
const NEW = 'http://127.0.0.1:18099/account';
// NEW is shorter — pad? We must not overflow. NEW is shorter so pad with spaces or rewrite query.
// http://127.0.0.1:18099/account is 32 chars
// https://dal-login-us.heitaoglobal.com:8082/account is 52 chars
// pad with /../ leftover path that still hits our catch-all, or spaces (may break URL parse)
const NEW_PAD = NEW + '/'.repeat(OLD.length - NEW.length);

function patchStr(hay, needle, repl) {
  let n = 0;
  const nb = Memory.allocUtf8String(needle);
  const rb = Memory.allocUtf8String(repl);
  const nlen = needle.length;
  Process.enumerateRanges('rw-').forEach(function (r) {
    try {
      Memory.scanSync(r.base, r.size, needle.split('').map(function (c) {
        return ('0' + c.charCodeAt(0).toString(16)).slice(-2);
      }).join(' ')).forEach(function (m) {
        try {
          m.address.writeUtf8String(repl);
          n++;
        } catch (e) {}
      });
    } catch (e) {}
  });
  return n;
}

function run() {
  const a = patchStr(null, OLD, NEW_PAD);
  const b = patchStr(null, 'https://dal-login-us.heitaoglobal.com:8082', 'http://127.0.0.1:18099'.padEnd(41, '/'));
  send({ t: 'patched', login: a, host: b, new: NEW_PAD });
}

send({ t: 'ready' });
setTimeout(run, 3000);
setInterval(run, 8000);
