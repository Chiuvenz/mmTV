'use strict';

const path = require('node:path');
const fs = require('node:fs');
const { app, BrowserWindow, ipcMain } = require('electron');
const { createServiceHost } = require('./service-host');

let mainWindow;
let serviceHost;

function serviceCall(uri, payload = {}) {
  return new Promise(resolve => {
    const token = `smoke-${Date.now()}`;
    serviceHost.dispatch({ token, uri, payload, respond: resolve });
  });
}
async function runSmokeTest(outputPath) {
  const result = { startedAt: new Date().toISOString() };
  try {
    mainWindow.webContents.setAudioMuted(true);
    result.service = await serviceCall('luna://com.biliwebos.app.service/ping');
    const api = await serviceCall('luna://com.biliwebos.app.service/fetch', {
      url: 'https://api.bilibili.com/x/web-interface/popular?pn=1&ps=1',
      method: 'GET',
    });
    result.api = { returnValue: api.returnValue, status: api.status };
    if (api.body) {
      const parsed = JSON.parse(api.body);
      result.api.code = parsed.code;
      result.api.items = parsed.data?.list?.length || 0;
    }
    await new Promise(resolve => setTimeout(resolve, 500));
    await mainWindow.webContents.executeJavaScript(`(() => {
      const item = Array.from(document.querySelectorAll('.sidebar-item'))
        .find(element => (element.innerText || '').trim() === '推荐');
      item?.click();
    })()`);
    for (let attempt = 0; attempt < 40; attempt += 1) {
      await new Promise(resolve => setTimeout(resolve, 500));
      const page = await mainWindow.webContents.executeJavaScript(`({
        title: document.title,
        text: (document.body.innerText || '').slice(0, 500),
        rootChildren: document.getElementById('root')?.childElementCount || 0,
        videoCards: document.querySelectorAll('.video-card').length
      })`);
      result.page = page;
      if (page.videoCards > 0) break;
      if (attempt > 0 && attempt % 4 === 0 && page.text.includes('内容加载失败')) {
        await mainWindow.webContents.executeJavaScript(`(() => {
          const retry = Array.from(document.querySelectorAll('button'))
            .find(element => (element.innerText || '').includes('重试'));
          retry?.click();
        })()`);
      }
    }
    result.input = {
      before: await mainWindow.webContents.executeJavaScript("document.querySelector('.focused')?.dataset.focusId || null"),
    };
    for (const direction of ['Right', 'Left', 'Down', 'Up']) {
      mainWindow.webContents.sendInputEvent({ type: 'keyDown', keyCode: direction });
      mainWindow.webContents.sendInputEvent({ type: 'keyUp', keyCode: direction });
      await new Promise(resolve => setTimeout(resolve, 200));
      result.input.after = await mainWindow.webContents.executeJavaScript("document.querySelector('.focused')?.dataset.focusId || null");
      if (result.input.before && result.input.after && result.input.before !== result.input.after) {
        result.input.direction = direction;
        break;
      }
    }
    result.input.moved = Boolean(result.input.before && result.input.after && result.input.before !== result.input.after);
    const focusedContent = result.input.after?.startsWith('content-');
    if (focusedContent) {
      mainWindow.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'Enter' });
      mainWindow.webContents.sendInputEvent({ type: 'keyUp', keyCode: 'Enter' });
    } else {
      await mainWindow.webContents.executeJavaScript(`(() => {
        const card = document.querySelectorAll('.video-card')[1];
        card?.dispatchEvent(new MouseEvent('mouseover', { bubbles: true }));
        card?.click();
      })()`);
    }
    result.playback = { started: false, activation: focusedContent ? 'remote-enter' : 'deterministic-card-click' };
    for (let attempt = 0; attempt < 60; attempt += 1) {
      await new Promise(resolve => setTimeout(resolve, 500));
      const playback = await mainWindow.webContents.executeJavaScript(`(() => {
        const video = document.querySelector('video');
        return video ? {
          present: true,
          readyState: video.readyState,
          currentTime: video.currentTime,
          paused: video.paused,
          error: video.error ? { code: video.error.code, message: video.error.message } : null
        } : { present: false };
      })()`);
      result.playback = { ...playback, started: playback.present && playback.readyState >= 2 && playback.currentTime > 0 };
      if (result.playback.started || result.playback.error) break;
    }
    if (result.playback.started) {
      mainWindow.webContents.sendInputEvent({ type: 'keyDown', keyCode: 'Escape' });
      mainWindow.webContents.sendInputEvent({ type: 'keyUp', keyCode: 'Escape' });
      await new Promise(resolve => setTimeout(resolve, 500));
      result.playback.returned = await mainWindow.webContents.executeJavaScript("!document.querySelector('video')");
    }
    const image = await mainWindow.webContents.capturePage();
    const screenshotPath = outputPath.replace(/\.json$/i, '.png');
    fs.writeFileSync(screenshotPath, image.toPNG());
    result.screenshotPath = screenshotPath;
    result.ok = result.service.returnValue === true && result.api.returnValue === true &&
      result.api.status === 200 && result.api.code === 0 && result.page.videoCards > 0 && result.input.moved &&
      result.playback.started && result.playback.returned;
  } catch (error) {
    result.ok = false;
    result.error = error.stack || String(error);
  }
  fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
  app.exit(result.ok ? 0 : 1);
}

function upstreamRoot() {
  return app.isPackaged
    ? path.join(process.resourcesPath, 'bilitv')
    : path.join(__dirname, 'vendor');
}

function createWindow() {
  const root = upstreamRoot();
  const applicationDirectory = path.join(root, 'usr/palm/applications/com.biliwebos.app');
  const serviceDirectory = path.join(root, 'usr/palm/services/com.biliwebos.app.service');
  const stateDirectory = path.join(app.getPath('userData'), 'state');
  serviceHost = createServiceHost({ serviceDirectory, stateDirectory });

  mainWindow = new BrowserWindow({
    title: 'BiliTVMac',
    width: 1280,
    height: 720,
    minWidth: 960,
    minHeight: 540,
    backgroundColor: '#0d0d1a',
    autoHideMenuBar: true,
    fullscreen: process.argv.includes('--tv-fullscreen'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: false,
    },
  });
  mainWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  mainWindow.webContents.session.setPermissionRequestHandler((_webContents, _permission, callback) => callback(false));
  mainWindow.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith('file://')) event.preventDefault();
  });
  mainWindow.loadFile(path.join(applicationDirectory, 'index.html'));
  const smokeIndex = process.argv.indexOf('--smoke-test');
  if (smokeIndex >= 0 && process.argv[smokeIndex + 1]) {
    mainWindow.webContents.once('did-finish-load', () => runSmokeTest(path.resolve(process.argv[smokeIndex + 1])));
  }
  mainWindow.on('closed', () => { mainWindow = null; });
}

ipcMain.on('mmtv-bilitv-call', (event, request) => {
  if (!serviceHost || event.sender !== mainWindow?.webContents || !request ||
      typeof request.token !== 'string' || !/^bridge-\d+$/.test(request.token)) return;
  serviceHost.dispatch({
    ...request,
    respond(response) {
      if (!event.sender.isDestroyed()) event.sender.send(`mmtv-bilitv-response:${request.token}`, response);
    },
  });
});
ipcMain.on('mmtv-bilitv-cancel', (event, request) => {
  if (serviceHost && event.sender === mainWindow?.webContents && request &&
      typeof request.token === 'string' && /^bridge-\d+$/.test(request.token)) {
    serviceHost.cancel(request.token);
  }
});

if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => {
    if (mainWindow) { if (mainWindow.isMinimized()) mainWindow.restore(); mainWindow.focus(); }
  });
  app.whenReady().then(createWindow);
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
  app.on('window-all-closed', () => app.quit());
}
