// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

import "../css/app.css"
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket, type LiveSocketInstanceInterface} from "phoenix_live_view"
import topbar from "topbar";
import {getHooks} from "live_svelte"
import { LiveViewTiptapHook } from "elim";
import SvelteHooks from "./hooks/svelte_hooks";

// import * as Components from "../svelte/**/*.svelte"
const modules: Record<string, any> = import.meta.glob('../svelte/**/*.svelte', {
    eager: true
});

console.log('=== LIVE_SVELTE DEBUG START ===');
console.log('Raw modules found:', Object.keys(modules));

// Create components object with simple name mapping
const Components: Record<string, any> = {};

import { useRegisterServiceWorker } from "./hooks/useRegisterServiceWorker.js";
Components.LiveViewTiptap = LiveViewTiptapHook;
Components.ServiceWorker = useRegisterServiceWorker;

Object.entries(modules).forEach(([path, module]) => {
    // Extract the relative path from ../svelte/ and remove .svelte extension
    const relativePath = path.replace('../svelte/', '').replace('.svelte', '');
    // Also create a simple name mapping for backward compatibility
    const componentName = path.split('/').pop()?.replace('.svelte', '') || path;

    // Map both path-based name and simple name
    Components[relativePath] = (module as any).default;
    Components[componentName] = (module as any).default;

    console.log(`Mapped component: "${relativePath}" and "${componentName}" from path: "${path}"`);
    console.log('Component export:', (module as any).default);
});

console.log('Final Components keys:', Object.keys(Components));
console.log('Looking for "Editor" component:', !!Components.Editor);

// Generate hooks and debug
const svelteHooks = getHooks(Components);
const hooks = {
  ...svelteHooks,
  ...SvelteHooks,
};
console.log('Generated hooks keys:', Object.keys(hooks));
console.log('=== LIVE_SVELTE DEBUG END ===');

// interface LiveViewSocket extends LiveSocketInstanceInterface {
//   isConnected: () => boolean;
// }

// declare global {
//   interface Window {
//     liveSocket: LiveViewSocket;
//   }
// }

function reconnectLiveViewIfDisconnected() {
  if (window.liveSocket && !window.liveSocket.isConnected()) {
    window.location.reload();
  }
}

useRegisterServiceWorker("/sw.js");

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: { ...hooks, LiveViewTiptapHook },
  params: { _csrf_token: csrfToken },
});



// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

liveSocket.getSocket().onOpen(async () => {
  try {
    const url = new URL(window.location.href);
    url.searchParams.set("bypass_service_worker", Date.now().toString());

    const response = await fetch(url);
    if (response.redirected) {
      window.location.replace(response.url);
    }
  } catch (error) {
    console.error("Error while checking for redirection on LiveView socket connection.", error);
  }
});

// Check for when the page becomes visible and refresh to ensure the socket is
// reconnected. This is mainly for the case where a user switches away from the
// app window and returns after an extended period where the socket may have
// been disconnected.
window.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") {
    reconnectLiveViewIfDisconnected();
  }
});

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true
      );

      window.liveReloader = reloader;
    }
  );
}
