const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '../web/index.html'), 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
const redirectScript = scripts.at(-1)[1];

function visit({host, pathname, query, userAgent}) {
  const redirects = [];
  const bootstraps = [];
  const document = {
    createElement: () => ({}),
    body: {appendChild: (element) => bootstraps.push(element.src)},
  };
  const window = {
    location: {
      hostname: host,
      pathname,
      search: query,
      replace: (url) => redirects.push(url),
    },
  };
  vm.runInNewContext(redirectScript, {
    document,
    window,
    navigator: {userAgent},
    URLSearchParams,
  });
  return {redirects, bootstraps};
}

test('las asociaciones móviles contienen identificadores y huella pública válidos', () => {
  const wellKnown = path.join(__dirname, '../web/.well-known');
  const [statement] = JSON.parse(fs.readFileSync(
    path.join(wellKnown, 'assetlinks.json'), 'utf8',
  ));
  assert.deepEqual(statement.relation, ['delegate_permission/common.handle_all_urls']);
  assert.equal(statement.target.namespace, 'android_app');
  assert.equal(statement.target.package_name, 'com.ones.events');
  const fingerprints = statement.target.sha256_cert_fingerprints;
  assert.equal(fingerprints.length, 1);
  assert.match(fingerprints[0], /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/);
  assert.equal(fingerprints[0],
    '73:FB:5E:44:88:AB:CF:7C:8E:47:A6:F9:EC:39:CB:7F:77:12:DA:99:68:C5:AB:F8:52:E9:03:7B:86:80:E0:58');

  const aasa = JSON.parse(fs.readFileSync(
    path.join(wellKnown, 'apple-app-site-association'), 'utf8',
  ));
  assert.equal(aasa.applinks.details[0].appID, 'HXK6M35VWH.co.ones.onesapp');
  assert.deepEqual(aasa.applinks.details[0].paths, ['/invitation']);
});

test('Android de producción envía a Play sin compartir el token', () => {
  const result = visit({
    host: 'app.ones.events',
    pathname: '/invitation',
    query: '?token=test-private-token&action=accept',
    userAgent: 'Mozilla/5.0 (Linux; Android 16)',
  });
  assert.deepEqual(result.redirects, [
    'https://play.google.com/store/apps/details?id=com.ones.events&hl=en',
  ]);
  assert.deepEqual(result.bootstraps, []);
});

test('iPhone, escritorio, dev y URLs ajenas siguen en Flutter web', () => {
  const base = {
    host: 'app.ones.events',
    pathname: '/invitation',
    query: '?token=test-private-token',
    userAgent: 'Mozilla/5.0 (Linux; Android 16)',
  };
  for (const scenario of [
    {...base, userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)'},
    {...base, userAgent: 'Mozilla/5.0 (Windows NT 10.0)'},
    {...base, host: 'appdev.ones.events'},
    {...base, pathname: '/events'},
    {...base, query: ''},
  ]) {
    assert.deepEqual(visit(scenario), {
      redirects: [], bootstraps: ['flutter_bootstrap.js'],
    });
  }
});
