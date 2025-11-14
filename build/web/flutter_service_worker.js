'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "01b2aa08446ce23151bbb3e8e822a471",
"assets/AssetManifest.bin.json": "64ef4a5c384d5f769490ff0c68aa290e",
"assets/AssetManifest.json": "160046f382fcd17ebec03167d77b7094",
"assets/assets/avatar.png": "63a0722ab0366695346211f77ce05b7b",
"assets/assets/emp-directory/Hariprasad%2520B-Tech%2520Trainee.jpg": "00ee6408f95d4d229dfe792a9a5d1c5f",
"assets/assets/emp-directory/Hemeswari%2520D-Tech%2520Trainee.jpg": "53a57f59f12f7dbbcb08fa63e5fb74f1",
"assets/assets/emp-directory/Karthick%2520K-Tech%2520Trainee.jpg": "a716e1c493ff1e0a0f102231b5026137",
"assets/assets/emp-directory/Karthik%2520K%2520-%2520BDE.jpg": "d3894b0e32b7017c9c5924412d6f7f1d",
"assets/assets/emp-directory/Uday%2520kiran%2520M%2520-%2520Tech%2520Trainee.jpg": "0d93ada156fc9014c06fa04349c7461c",
"assets/assets/emp-directory/Vishal%2520-%2520UXD%2520-%2520Intern.JPG": "8087679f2a9ba5790e20ae8cbd273feb",
"assets/assets/event-png/anniversary.png": "d5d2d0529500a814310385ea64ef25a8",
"assets/assets/event-png/cake.png": "4f66b5206f845fd40d7e1ca2bc727ecf",
"assets/assets/event-png/christmas.png": "d93227606442a52036499eca2b6c6dcd",
"assets/assets/event-png/Director.png": "1d1f5e5971982edaa4120e21c0ff3ac8",
"assets/assets/event-png/diwali.png": "e0239e5db5381642bad1337cbd7c5fea",
"assets/assets/event-png/environment.jpg": "5dd8dd640df3888a8db3221a230ab36f",
"assets/assets/event-png/meeting.png": "9cde4e4e16a2416c19a0545afb65ae02",
"assets/assets/event-png/microsoft_aws.png": "6f34fa64c0a063dd48c130c4874ae745",
"assets/assets/event-png/miro.png": "b7ed1ca38764572a427bd21416f8fa06",
"assets/assets/event-png/onboarding.png": "01e41b3c1f46e679bbdb8f0d191a5d56",
"assets/assets/event-png/pongal.png": "113a26eacb7addd1df038fa2f40143f1",
"assets/assets/event-png/ramzan.png": "2ebaf89a09b52d76d16bf6114d07f92e",
"assets/assets/logo_z.png": "d1222f04d8a0463e631e9c802bd20847",
"assets/assets/logo_zeai.png": "e68ffda132fbf5eaff4c4bb2b27922f4",
"assets/assets/png1.png": "ab88bd34c1225ff57b25da1abb643bdb",
"assets/assets/profile.png": "fc435972f6d5251d541fd1f85fb1734a",
"assets/assets/sounds/alert.mp3": "1f981fff7ebd187d4872b3ea41c23bd2",
"assets/FontManifest.json": "5a32d4310a6f5d9a6b651e75ba0d7372",
"assets/fonts/MaterialIcons-Regular.otf": "d430c6ea8f29d229207c14d9a2ee1cb1",
"assets/NOTICES": "17778938d06c98a354f8b8ec5437c508",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf": "15d54d142da2f2d6f2e90ed1d55121af",
"assets/packages/font_awesome_flutter/lib/fonts/fa-regular-400.ttf": "262525e2081311609d1fdab966c82bfc",
"assets/packages/font_awesome_flutter/lib/fonts/fa-solid-900.ttf": "269f971cec0d5dc864fe9ae080b19e23",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"flutter_bootstrap.js": "05e74dd2f82af7489583af85124c77d0",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "c049b0e00dd21201abb6a77cb84737a8",
"/": "c049b0e00dd21201abb6a77cb84737a8",
"main.dart.js": "cf36edb0a4f951b88e9818fa48e2fb45",
"manifest.json": "391c0d7af772245e120cd01a698ff12a",
"version.json": "ef140923367eb4aaba332df3074b5ff0",
"_redirects": "c62c109df475b368db5e075d5e2f0052"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
