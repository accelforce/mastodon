import { useCallback } from "react";

import { FormattedMessage, defineMessages, useIntl } from "react-intl";

import { Link } from "react-router-dom";

import { useDispatch, useSelector } from "react-redux";

import BarChart4BarsIcon from 'mastodon/../material-icons/400-24px/bar_chart_4_bars.svg?react';
import CloseIcon from 'mastodon/../material-icons/400-24px/close.svg?react';
import PhotoLibraryIcon from 'mastodon/../material-icons/400-24px/photo_library.svg?react';
import { cancelReplyCompose } from "mastodon/actions/compose";
import { Avatar } from "mastodon/components/avatar";
import { DisplayName } from "mastodon/components/display_name";
import { Icon } from "mastodon/components/icon";
import { IconButton } from "mastodon/components/icon_button";

const messages = defineMessages({
  cancel: { id: 'reply_indicator.cancel', defaultMessage: 'Cancel' },
});

export const QuoteIndicator = () => {
  const intl = useIntl();
  const dispatch = useDispatch();
  const id = useSelector(state => state.getIn(['compose', 'quote_from']));
  const status = useSelector(state => state.getIn(['statuses', id]));
  const account = useSelector(state => state.getIn(['accounts', status?.get('account')]));

  const handleCancelClick = useCallback(() => {
    dispatch(cancelReplyCompose());
  }, [dispatch]);

  if (!status) {
    return null;
  }

  const content = { __html: status.get('contentHtml') };

  return (
    <div className='edit-indicator'>
      <div className='edit-indicator__header'>
        <Link to={`/@${account.get('acct')}`} className='status__display-name'>
          <Avatar account={account} size={46} />
          <DisplayName account={account} />
        </Link>

        <div className='edit-indicator__cancel'>
          <IconButton title={intl.formatMessage(messages.cancel)} icon='times' iconComponent={CloseIcon} onClick={handleCancelClick} inverted />
        </div>
      </div>

      <div className='edit-indicator__content translate' dangerouslySetInnerHTML={content} />

      {(status.get('poll') || status.get('media_attachments').size > 0) && (
        <div className='edit-indicator__attachments'>
          {status.get('poll') && <><Icon icon={BarChart4BarsIcon} /><FormattedMessage id='reply_indicator.poll' defaultMessage='Poll' /></>}
          {status.get('media_attachments').size > 0 && <><Icon icon={PhotoLibraryIcon} /><FormattedMessage id='reply_indicator.attachments' defaultMessage='{count, plural, one {# attachment} other {# attachments}}' values={{ count: status.get('media_attachments').size }} /></>}
        </div>
      )}
    </div>
  );
};