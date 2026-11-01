const config = window.MUSIC_LINK_SUPABASE || {};
window.musicLinkBackend = null;
if (window.supabase && /^https:\/\//.test(config.url || "") && config.publishableKey) {
  window.musicLinkBackend = window.supabase.createClient(config.url, config.publishableKey);
}
