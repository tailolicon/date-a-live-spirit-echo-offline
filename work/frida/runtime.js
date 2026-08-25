'use strict';
// 32-bit attach: no Java. Patch login URL strings on the heap and
// rewrite libc connect() so account HTTP + game TCP stay on the PC.

function pad(oldS, newS) {
  if (newS.length > oldS.length) return null;
  return newS + '/'.repeat(oldS.length - newS.length);
}

const LOGIN_OLD = 'https://dal-login-us.heitaoglobal.com:8082/account';
const LOGIN_NEW = pad(LOGIN_OLD, 'http://127.0.0.1:18099/account');
const Q_OLD = 'https://dal-login-us.heitaoglobal.com:8082/account/querydate';
const Q_NEW = pad(Q_OLD, 'http://127.0.0.1:18099/account/querydate');
const N_OLD = 'https://dal-login-us.heitaoglobal.com:8082/globalNotice/get_global_notice';
const N_NEW = pad(N_OLD, 'http://127.0.0.1:18099/globalNotice/get_global_notice');
const HOST_OLD = 'dal-login-us.heitaoglobal.com';
const HOST_NEW = pad(HOST_OLD, '127.0.0.1');

function toHex(s) {
  return s.split('').map(function (c) {
    return ('0' + c.charCodeAt(0).toString(16)).slice(-2);
  }).join(' ');
}

function patchOne(oldS, newS, tag) {
  if (!oldS || !newS || oldS.length !== newS.length) {
    send({ t: 'len-mismatch', tag: tag, old: oldS ? oldS.length : -1, neu: newS ? newS.length : -1 });
    return 0;
  }
  const pattern = toHex(oldS);
  let n = 0;
  Process.enumerateRanges('r--').concat(Process.enumerateRanges('rw-')).forEach(function (r) {
    if (r.size > 64 * 1024 * 1024) return;
    try {
      Memory.scanSync(r.base, r.size, pattern).forEach(function (m) {
        try {
          m.address.writeUtf8String(newS);
          n++;
        } catch (e) {}
      });
    } catch (e) {}
  });
  if (n) send({ t: 'patch', tag: tag, n: n });
  return n;
}

function patchAll() {
  // Restore a previous HTTP localhost rewrite back to the official HTTPS URL.
  // Hosts + connect() then send TLS to 10.0.2.2:18082. Scan once — not on an interval.
  patchOne(LOGIN_NEW, LOGIN_OLD, 'restore-login');
  patchOne(N_NEW, N_OLD, 'restore-notice');
  patchOne(Q_NEW, Q_OLD, 'restore-query');
}

function rewritePort(sa, port) {
  sa.add(2).writeU8((port >> 8) & 0xff);
  sa.add(3).writeU8(port & 0xff);
}

function rewriteIp(sa, a, b, c, d) {
  sa.add(4).writeByteArray([a, b, c, d]);
}

function hookConnect() {
  let p = null;
  try { p = Process.getModuleByName('libc.so').getExportByName('connect'); } catch (e) {}
  try { if (!p) p = Module.getGlobalExportByName('connect'); } catch (e) {}
  if (!p) {
    send({ t: 'connect', err: 'no libc connect' });
    return;
  }
  send({ t: 'connect-ptr', p: p.toString() });
  Interceptor.attach(p, {
    onEnter(args) {
      this.sa = args[1];
      try {
        const sa = args[1];
        const family = sa.readU16();
        if (family !== 2) { this.skip = true; return; }
        const port = (sa.add(2).readU8() << 8) | sa.add(3).readU8();
        const a = sa.add(4).readU8(), b = sa.add(5).readU8();
        const c = sa.add(6).readU8(), d = sa.add(7).readU8();
        const ip = a + '.' + b + '.' + c + '.' + d;
        this.ip = ip; this.port = port;
        send({ t: 'conn', ip: ip, port: port });
        // MuMu: app connect() to 127.0.0.1 fails (rv=-1). Host is 10.0.2.2.
        const HOST = [10, 0, 2, 2];
        if (port === 8082 || port === 18082) {
          rewritePort(sa, 18082);
          rewriteIp(sa, HOST[0], HOST[1], HOST[2], HOST[3]);
          this.port = 18082;
          send({ t: 'tcp', from: ip + ':' + port, to: '10.0.2.2:18082' });
        } else if (port === 443) {
          rewritePort(sa, 18082);
          rewriteIp(sa, HOST[0], HOST[1], HOST[2], HOST[3]);
          this.port = 18082;
          send({ t: 'tcp', from: ip + ':443', to: '10.0.2.2:18082' });
        } else if (port === 18099 || (a === 127 && port === 18099)) {
          rewriteIp(sa, HOST[0], HOST[1], HOST[2], HOST[3]);
          this.port = 18099;
          send({ t: 'tcp', from: ip + ':18099', to: '10.0.2.2:18099' });
        } else if (port === 18100 || port === 10086 || (port > 7000 && port < 20000 &&
            port !== 8081 && port !== 18082 && port !== 18099)) {
          rewritePort(sa, 18100);
          rewriteIp(sa, HOST[0], HOST[1], HOST[2], HOST[3]);
          this.port = 18100;
          send({ t: 'tcp', from: ip + ':' + port, to: '10.0.2.2:18100' });
        }
      } catch (e) {}
    },
    onLeave(retval) {
      try {
        if (this.skip) return;
        send({ t: 'conn-ret', ip: this.ip, port: this.port, rv: retval.toInt32() });
      } catch (e) {}
    }
  });
  try {
    const snd = Process.getModuleByName('libc.so').getExportByName('send');
    Interceptor.attach(snd, {
      onEnter(args) {
        try {
          const n = args[2].toInt32();
          if (n < 1 || n > 8192) return;
          const b0 = args[1].readU8();
          if (b0 !== 0x16 && b0 !== 0x47 && b0 !== 0x50 && b0 !== 0x43) return;
          send({ t: 'send', n: n, b0: b0, head: hexdump(args[1], { length: Math.min(n, 32), header: false, ansi: false }) });
        } catch (e) {}
      }
    });
  } catch (e) {}
  send({ t: 'armed', what: 'connect' });
}

function hookSsl() {
  const names = ['SSL_get_verify_result', 'SSL_CTX_set_verify'];
  Process.enumerateModules().forEach(function (mod) {
    names.forEach(function (nm) {
      let p = null;
      try { p = mod.getExportByName(nm); } catch (e) {}
      if (!p) return;
      try {
        if (nm === 'SSL_get_verify_result') {
          Interceptor.replace(p, new NativeCallback(function () { return 0; }, 'int', ['pointer']));
        } else {
          Interceptor.attach(p, {
            onEnter(args) { args[1] = ptr(0); }
          });
        }
        send({ t: 'ssl', hook: nm, mod: mod.name });
      } catch (e) {
        send({ t: 'ssl-err', hook: nm, e: '' + e });
      }
    });
  });
}

send({ t: 'ready', arch: Process.arch, ptr: Process.pointerSize });
try { hookConnect(); } catch (e) { send({ t: 'connect-err', e: '' + e }); }
try { hookSsl(); } catch (e) { send({ t: 'ssl-err', e: '' + e }); }
send({ t: 'skip-scan', why: 'urls already restored; connect rewrite only' });
