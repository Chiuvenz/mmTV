'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { adaptServiceSource, methodFromURI, RegistrationStore } = require('../service-host');

test('accepts only the pinned BiliTV Luna service namespace', () => {
  assert.equal(methodFromURI('luna://com.biliwebos.app.service/fetch'), 'fetch');
  assert.equal(methodFromURI('luna://other.service/fetch'), null);
  assert.equal(methodFromURI('https://com.biliwebos.app.service/fetch'), null);
  assert.equal(methodFromURI('luna://com.biliwebos.app.service/../clearCookies'), null);
});
test('adapts state paths and disables LAN cast startup', () => {
  const source = [
    "path.join('/media/internal', 'a')",
    "path.join('/media/internal', 'b')",
    "path.join('/media/internal', 'c')",
    'castLanServer.start(function () {',
    "  console.log('cast');",
    '});',
    '',
    '// Keep service alive',
  ].join('\n');
  const adapted = adaptServiceSource(source);
  assert.equal(adapted.includes('/media/internal'), false);
  assert.equal(adapted.includes('castLanServer.start'), false);
  assert.equal(adapted.match(/MMTV_BILITV_STATE_DIR/g).length, 3);
});

test('registration store captures handlers without a webOS runtime', () => {
  const store = new RegistrationStore();
  const handler = () => {};
  const cancel = () => {};
  store.register('fetch', handler, cancel);
  assert.deepEqual(store.handlers.get('fetch'), { handler, cancelHandler: cancel });
  let completed = false;
  store.activityManager.create('keepAlive', activity => { activity.complete(); completed = true; });
  assert.equal(completed, true);
});
