import { countableText } from './counter';

describe('countableText', () => {
  test('keeps avatar references at full length while discounting ordinary remote mentions', () => {
    expect(
      countableText(':@alice@remote.example: @alice@remote.example:'),
    ).toBe(':@alice@remote.example: @alice:');
  });
});
