'use strict';

const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');

function methodFromURI(uri) {
  if (typeof uri !== 'string') return null;
  const match = /^luna:\/\/com\.biliwebos\.app\.service\/([A-Za-z][A-Za-z0-9]*)$/.exec(uri);
  return match ? match[1] : null;
}

function adaptServiceSource(source) {
  const mediaRoot = "path.join('/media/internal', ";
  const stateRoot = 'path.join(process.env.MMTV_BILITV_STATE_DIR, ';
  const stateReferences = source.split(mediaRoot).length - 1;
  if (stateReferences < 3) throw new Error('Unexpected BiliTV state path contract');
  let adapted = source.split(mediaRoot).join(stateRoot);

  const castPattern = /castLanServer\.start\(function \(\) \{[\s\S]*?\n\}\);\n\n\/\/ Keep service alive/;
  if (!castPattern.test(adapted)) throw new Error('Unexpected BiliTV cast startup contract');
  adapted = adapted.replace(castPattern, '// LAN cast listener disabled by BiliTVMac.\n\n// Keep service alive');
  return adapted;
}

class RegistrationStore {
  constructor() {
    this.handlers = new Map();
    this.activityManager = {
      create: (_name, callback) => callback({ complete() {} }),
    };
  }

  register(name, handler, cancelHandler) {
    this.handlers.set(name, { handler, cancelHandler });
  }
}

function createServiceHost({ serviceDirectory, stateDirectory }) {
  if (!path.isAbsolute(serviceDirectory) || !path.isAbsolute(stateDirectory)) {
    throw new Error('BiliTV service and state directories must be absolute');
  }
  fs.mkdirSync(stateDirectory, { recursive: true, mode: 0o700 });
  process.env.MMTV_BILITV_STATE_DIR = stateDirectory;

  const serviceFile = path.join(serviceDirectory, 'service.js');
  const source = adaptServiceSource(fs.readFileSync(serviceFile, 'utf8'));
  let registrations;
  class LocalWebOSService extends RegistrationStore {
    constructor() {
      super();
      registrations = this;
    }
  }

  const originalLoad = Module._load;
  Module._load = function(request, parent, isMain) {
    if (request === 'webos-service') return LocalWebOSService;
    return originalLoad.call(this, request, parent, isMain);
  };
  try {
    const serviceModule = new Module(serviceFile, module);
    serviceModule.filename = serviceFile;
    serviceModule.paths = Module._nodeModulePaths(serviceDirectory);
    serviceModule._compile(source, serviceFile);
  } finally {
    Module._load = originalLoad;
  }
  if (!registrations) throw new Error('BiliTV service did not initialize');

  const active = new Map();
  return {
    dispatch({ token, uri, payload = {}, respond }) {
      const method = methodFromURI(uri);
      const registration = method && registrations.handlers.get(method);
      if (!registration) {
        respond({ returnValue: false, error: 'Unsupported local service method' });
        return;
      }
      const message = {
        payload,
        isSubscription: payload.subscribe === true,
        uniqueToken: token,
        respond,
      };
      active.set(token, { message, registration });
      try {
        registration.handler(message);
      } catch (error) {
        active.delete(token);
        respond({ returnValue: false, error: error.message || String(error) });
      }
      if (!message.isSubscription) active.delete(token);
    },
    cancel(token) {
      const item = active.get(token);
      active.delete(token);
      if (item && item.registration.cancelHandler) item.registration.cancelHandler(item.message);
    },
  };
}

module.exports = { adaptServiceSource, createServiceHost, methodFromURI, RegistrationStore };
