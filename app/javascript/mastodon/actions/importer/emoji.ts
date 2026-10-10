import type { ApiCustomEmojiJSON } from '@/mastodon/api_types/custom_emoji';
import { loadCustomEmoji } from '@/mastodon/features/emoji';
import { emojiLogger } from '@/mastodon/features/emoji/utils';

const log = emojiLogger('actions');

export async function importCustomEmoji(emojis: ApiCustomEmojiJSON[]) {
  // Avatar emojis are supplied by posts, rather than the custom emoji endpoint.
  emojis = emojis.filter((emoji) => !emoji.shortcode.startsWith('@'));

  if (emojis.length === 0) {
    return;
  }

  // First, check if we already have them all.
  const { searchCustomEmojisByShortcodes, clearCache } =
    await import('@/mastodon/features/emoji/database');

  const existingEmojis = await searchCustomEmojisByShortcodes(
    emojis.map((emoji) => emoji.shortcode),
  );

  // If there's a mismatch, re-import all custom emojis.
  if (existingEmojis.length > 0 && existingEmojis.length < emojis.length) {
    await clearCache('custom');
    await loadCustomEmoji();

    log('Custom emojis updated, reloaded cache and picker data.');
  }
}
