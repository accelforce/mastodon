import type { ApiCustomEmojiJSON } from '@/mastodon/api_types/custom_emoji';
import { loadCustomEmoji } from '@/mastodon/features/emoji';
import {
  clearCache,
  searchCustomEmojisByShortcodes,
} from '@/mastodon/features/emoji/database';

import { importCustomEmoji } from './emoji';

vi.mock('@/mastodon/features/emoji', () => ({ loadCustomEmoji: vi.fn() }));
vi.mock('@/mastodon/features/emoji/database', () => ({
  clearCache: vi.fn(),
  searchCustomEmojisByShortcodes: vi.fn(),
}));

const emoji = (shortcode: string): ApiCustomEmojiJSON => ({
  shortcode,
  url: `https://example.com/${shortcode}.png`,
  static_url: `https://example.com/${shortcode}.png`,
  visible_in_picker: !shortcode.startsWith('@'),
});

describe('importCustomEmoji', () => {
  beforeEach(() => vi.clearAllMocks());

  test('does not reload the picker when a post adds avatar emojis to installed custom emojis', async () => {
    vi.mocked(searchCustomEmojisByShortcodes).mockResolvedValue([
      { ...emoji('wave'), tokens: ['wave'] },
    ]);

    await importCustomEmoji([emoji('wave'), emoji('@alice')]);

    expect(searchCustomEmojisByShortcodes).toHaveBeenCalledWith(['wave']);
    expect(clearCache).not.toHaveBeenCalled();
    expect(loadCustomEmoji).not.toHaveBeenCalled();
  });

  test('still reloads when an ordinary custom emoji is missing', async () => {
    vi.mocked(searchCustomEmojisByShortcodes).mockResolvedValue([
      { ...emoji('wave'), tokens: ['wave'] },
    ]);

    await importCustomEmoji([emoji('wave'), emoji('smile'), emoji('@alice')]);

    expect(clearCache).toHaveBeenCalledWith('custom');
    expect(loadCustomEmoji).toHaveBeenCalledOnce();
  });

  test('does not query installed emojis for an avatar-only post', async () => {
    await importCustomEmoji([emoji('@alice')]);

    expect(searchCustomEmojisByShortcodes).not.toHaveBeenCalled();
  });
});
