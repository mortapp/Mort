{{flutter_js}}
{{flutter_build_config}}

const mortLoader = document.querySelector('#mort-loader');
const mortLoaderStatus = document.querySelector('#mort-loader-status');
const mortLoaderRetry = document.querySelector('#mort-loader-retry');

function setMortLoaderStatus(message) {
  if (mortLoaderStatus) mortLoaderStatus.textContent = message;
}

function showMortLoaderError() {
  setMortLoaderStatus('MORT could not start. Check your connection and retry.');
  if (mortLoaderRetry) {
    mortLoaderRetry.hidden = false;
    mortLoaderRetry.addEventListener('click', () => window.location.reload(), {
      once: true,
    });
  }
}

(async () => {
  try {
    await _flutter.loader.load({
      onEntrypointLoaded: async (engineInitializer) => {
        setMortLoaderStatus('Starting MORT...');
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
        mortLoader?.remove();
      },
    });
  } catch (_) {
    showMortLoaderError();
  }
})();
