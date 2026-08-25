// Date A Live: Spirit Echo — redirect + SDK bypass + update skip + packet dump
// Personal research / preservation. Spawn-inject this before resume.

'use strict';

const HTTP_LOCAL = 'http://127.0.0.1:18099';
const GAME_IP = '127.0.0.1';
const GAME_PORT = 18100;

const HOST_RE = /heitaoglobal\.com|datealive\.com|moonramble\.com|heitao2014\.com|192\.168\.38\.|43\.130\.144\.246|43\.138\.118\.87/i;

function rewriteUrl(u) {
  if (!u) return u;
  try {
    if (HOST_RE.test(u)) {
      const path = u.replace(/^https?:\/\/[^/]+/i, '');
      return HTTP_LOCAL + (path.charAt(0) === '/' ? path : '/' + path);
    }
  } catch (e) {}
  return u;
}

send({ t: 'ready', msg: 'offline.js loaded' });

function hookJava() {
  if (typeof Java === 'undefined') {
    send({ t: 'java', skip: 'no-Java-runtime' });
    return;
  }
  if (!Java.available) return;
  Java.perform(function () {
    // OkHttp
    try {
      const Request = Java.use('okhttp3.Request');
      const Builder = Java.use('okhttp3.Request$Builder');
      Builder.url.overload('java.lang.String').implementation = function (u) {
        const n = rewriteUrl(u);
        if (n !== u) send({ t: 'http', from: u, to: n });
        return this.url(n);
      };
      Builder.url.overload('okhttp3.HttpUrl').implementation = function (u) {
        try {
          const s = u.toString();
          const n = rewriteUrl(s);
          if (n !== s) {
            send({ t: 'http', from: s, to: n });
            const HttpUrl = Java.use('okhttp3.HttpUrl');
            return this.url(HttpUrl.parse(n));
          }
        } catch (e) {}
        return this.url(u);
      };
    } catch (e) {}

    try {
      const URL = Java.use('java.net.URL');
      URL.$init.overload('java.lang.String').implementation = function (u) {
        const n = rewriteUrl(u);
        if (n !== u) send({ t: 'http', from: u, to: n });
        return this.$init(n);
      };
    } catch (e) {}

    // Phanta HttpClient
    try {
      const HC = Java.use('org.phanta.util.HttpClient');
      const methods = HC.class.getDeclaredMethods();
      send({ t: 'java', cls: 'HttpClient', n: methods.length });
    } catch (e) {}

    // Heitao SDK — fake a logged-in user so we never hit the live SDK
    const sdkNames = [
      'org.cocos2dx.TerransForce.HeitaoSdkManager',
      'com.heitao.sdk.HTSDK',
    ];
    sdkNames.forEach(function (cn) {
      try {
        const C = Java.use(cn);
        const names = [];
        C.class.getDeclaredMethods().forEach(function (m) { names.push(m.getName()); });
        send({ t: 'sdk', cls: cn, methods: names.slice(0, 80) });
        ['isLogined', 'isLogin', 'hasLogin'].forEach(function (mn) {
          try {
            C[mn].overloads.forEach(function (ovl) {
              ovl.implementation = function () { return true; };
            });
          } catch (e) {}
        });
        ['getuserid', 'getUserId', 'getUid', 'userid'].forEach(function (mn) {
          try {
            C[mn].overloads.forEach(function (ovl) {
              ovl.implementation = function () { return 'offline'; };
            });
          } catch (e) {}
        });
        ['gettoken', 'getToken', 'token'].forEach(function (mn) {
          try {
            C[mn].overloads.forEach(function (ovl) {
              ovl.implementation = function () { return 'offline_local_token'; };
            });
          } catch (e) {}
        });
        ['login', 'Login'].forEach(function (mn) {
          try {
            C[mn].overloads.forEach(function (ovl) {
              ovl.implementation = function () {
                send({ t: 'sdk', ev: 'login-stub', cls: cn });
                return true;
              };
            });
          } catch (e) {}
        });
      } catch (e) {}
    });
  });
}

function hookNative() {
  const curl = Module.findExportByName(null, 'curl_easy_setopt');
  if (curl) {
    Interceptor.attach(curl, {
      onEnter(args) {
        if (args[1].toInt32() !== 10002) return; // CURLOPT_URL
        let u;
        try { u = args[2].readUtf8String(); } catch (e) { return; }
        const n = rewriteUrl(u);
        if (n !== u) {
          this._k = Memory.allocUtf8String(n);
          args[2] = this._k;
          send({ t: 'curl', from: u, to: n });
        }
      }
    });
    send({ t: 'armed', what: 'curl' });
  }

  // TFClientSocket::Connect(ip, port) — C++ mangled names vary; also hook connect()
  const conn = Module.findExportByName(null, 'connect');
  if (conn) {
    Interceptor.attach(conn, {
      onEnter(args) {
        try {
          const sa = args[1];
          const family = sa.readU16();
          // AF_INET = 2 on Android
          if (family !== 2 && family !== 0x0002) return;
          const port = (sa.add(2).readU8() << 8) | sa.add(3).readU8();
          const a = sa.add(4).readU8(), b = sa.add(5).readU8(),
                c = sa.add(6).readU8(), d = sa.add(7).readU8();
          const ip = a + '.' + b + '.' + c + '.' + d;
          if (port === GAME_PORT && ip === GAME_IP) return;
          // rewrite game-server ports (common 10086 / 808x / high ports except 80/443)
          if (port > 1024 && port !== 8082 && HOST_RE.test(ip) === false) {
            // still rewrite unknown high-port TCP to our game server
            if (port === 10086 || port === GAME_PORT || port > 7000) {
              sa.add(2).writeU8((GAME_PORT >> 8) & 0xff);
              sa.add(3).writeU8(GAME_PORT & 0xff);
              sa.add(4).writeByteArray([127, 0, 0, 1]);
              send({ t: 'tcp', from: ip + ':' + port, to: GAME_IP + ':' + GAME_PORT });
            }
          }
        } catch (e) {}
      }
    });
    send({ t: 'armed', what: 'connect' });
  }
}

function hookLuaLoad() {
  const names = ['luaL_loadbufferx', 'luaL_loadbuffer'];
  names.forEach(function (nm) {
    const p = Module.findExportByName('libTerransForce.so', nm) || Module.findExportByName(null, nm);
    if (!p) return;
    Interceptor.attach(p, {
      onEnter(args) {
        try {
          const sz = args[2].toInt32();
          if (sz <= 0 || sz > 8 * 1024 * 1024) return;
          let name = '';
          try { name = args[3].readUtf8String(); } catch (e) {}
          let src;
          try { src = args[1].readUtf8String(sz); } catch (e) { return; }
          if (!src) return;
          let nsrc = src;
          if (nsrc.indexOf('function UpdateLayer_new:updateVision') !== -1) {
            nsrc = nsrc.replace(
              'function UpdateLayer_new:updateVision()',
              'function UpdateLayer_new:updateVision()\n    restartLuaEngine("CompleteUpdate")\n    do return end\n    local function __dal_orig_updateVision()'
            );
            send({ t: 'lua', patch: 'skip-update', name: name, n: sz });
          }
          if (nsrc.indexOf('URL_LOGIN') !== -1 && nsrc.indexOf('heitaoglobal') !== -1) {
            nsrc = nsrc.replace(/VERSION_DEBUG = false/g, 'VERSION_DEBUG = true');
            nsrc = nsrc.replace(/https:\/\/dal-login-us\.heitaoglobal\.com:8082\/account/g, 'http://127.0.0.1:18099/account');
            nsrc = nsrc.replace(/https:\/\/dal-login-us\.heitaoglobal\.com:8082\/account\/querydate/g, 'http://127.0.0.1:18099/account/querydate');
            nsrc = nsrc.replace(/https:\/\/dal-login-us\.heitaoglobal\.com:8082\/globalNotice\/get_global_notice/g, 'http://127.0.0.1:18099/globalNotice/get_global_notice');
            send({ t: 'lua', patch: 'login-url', name: name, n: sz });
          }
          if (nsrc !== src) {
            const mem = Memory.allocUtf8String(nsrc);
            this._keep = mem;
            args[1] = mem;
            args[2] = ptr(nsrc.length);
          } else if (name && /UtilHelper|LogonHelper|UpdateLayer/.test(name)) {
            send({ t: 'lua', name: name, n: sz });
          }
        } catch (e) {
          send({ t: 'lua-err', e: '' + e });
        }
      }
    });
    send({ t: 'armed', what: nm });
  });
}

function hookDlopen() {
  const names = ['android_dlopen_ext', 'dlopen'];
  names.forEach(function (nm) {
    const p = Module.findExportByName(null, nm);
    if (!p) return;
    Interceptor.attach(p, {
      onEnter(args) {
        try { this.path = args[0].readUtf8String(); } catch (e) { this.path = ''; }
      },
      onLeave() {
        if (this.path && /TerransForce|libgame|libcocos/i.test(this.path)) {
          send({ t: 'dlopen', path: this.path });
          setTimeout(waitLib, 50);
        }
      }
    });
    send({ t: 'armed', what: nm });
  });
}

let _libTries = 0;
function waitLib() {
  let m = Process.findModuleByName('libTerransForce.so');
  if (!m) {
    _libTries++;
    if (_libTries === 1 || _libTries === 20) {
      const names = Process.enumerateModules().map(function (mod) { return mod.name; });
      send({ t: 'mods', n: names.length, names: names, tries: _libTries });
    }
    setTimeout(waitLib, 300);
    return;
  }
  send({ t: 'lib', base: m.base.toString(), size: m.size });
  hookNative();
  hookLuaLoad();
  send({ t: 'armed', what: 'native' });
}

setImmediate(function () {
  try { hookJava(); } catch (e) { send({ t: 'java-err', e: '' + e }); }
  try { hookDlopen(); } catch (e) { send({ t: 'dl-err', e: '' + e }); }
  try { waitLib(); } catch (e) { send({ t: 'lib-err', e: '' + e }); }
  setTimeout(function () {
    try { hookJava(); } catch (e) {}
    try { waitLib(); } catch (e) {}
  }, 1500);
  setTimeout(function () {
    try { hookJava(); } catch (e) {}
    try { waitLib(); } catch (e) {}
  }, 4000);
});
