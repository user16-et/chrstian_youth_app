{{flutter_js}}
{{flutter_build_config}}

// Local development should always load the current Dart bundle.
if ('serviceWorker' in navigator) {
  const registrations = await navigator.serviceWorker.getRegistrations();
  await Promise.all(registrations.map((registration) => registration.unregister()));
}

await _flutter.loader.load();
