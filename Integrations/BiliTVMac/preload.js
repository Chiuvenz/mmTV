'use strict';

const { contextBridge, ipcRenderer } = require('electron');

const active = new Map();
const nativeBridge = {
  call(token, uri, payloadJSON, callback) {
    if (!/^bridge-\d+$/.test(token) || typeof callback !== 'function') return;
    let payload = {};
    try { payload = payloadJSON ? JSON.parse(payloadJSON) : {}; }
    catch (_error) {
      queueMicrotask(() => callback({ returnValue: false, error: 'Invalid service payload' }));
      return;
    }
    const channel = `mmtv-bilitv-response:${token}`;
    const subscription = payload.subscribe === true;
    const listener = (_event, response) => {
      try { callback(response); }
      finally {
        if (!subscription) {
          ipcRenderer.removeListener(channel, listener);
          active.delete(token);
        }
      }
    };
    active.set(token, { channel, listener });
    ipcRenderer.on(channel, listener);
    ipcRenderer.send('mmtv-bilitv-call', { token, uri, payload });
  },
  cancel(token) {
    const item = active.get(token);
    if (item) ipcRenderer.removeListener(item.channel, item.listener);
    active.delete(token);
    ipcRenderer.send('mmtv-bilitv-cancel', { token });
  },
};

contextBridge.exposeInMainWorld('__mmtvNativeBridge', nativeBridge);
contextBridge.executeInMainWorld({
  func: () => {
    let sequence = 0;
    window.PalmServiceBridge = class PalmServiceBridge {
      constructor() {
        this.onservicecallback = null;
        this.token = null;
      }
      call(uri, payloadJSON) {
        this.cancel();
        this.token = `bridge-${++sequence}`;
        window.__mmtvNativeBridge.call(this.token, uri, payloadJSON, response => {
          if (typeof this.onservicecallback === 'function') this.onservicecallback(JSON.stringify(response));
        });
      }
      cancel() {
        if (this.token) window.__mmtvNativeBridge.cancel(this.token);
        this.token = null;
      }
    };
    window.webOSSystem = window.webOSSystem || {
      locale: 'zh-CN',
      platformBack() { window.close(); },
    };
    window.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        event.preventDefault();
        window.dispatchEvent(new Event('tv-back'));
      }
    }, true);
  },
});
