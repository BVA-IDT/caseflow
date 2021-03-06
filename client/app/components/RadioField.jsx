import React from 'react';
import PropTypes from 'prop-types';

import RequiredIndicator from './RequiredIndicator';
import StringUtil from '../util/StringUtil';

/**
 * Radio button component.
 *
 * See StyleGuideRadioField.jsx for usage examples.
 *
 */

export default class RadioField extends React.Component {

  isVertical() {
    return this.props.vertical || this.props.options.length > 2;
  }

  render() {
    let {
      id,
      className,
      label,
      name,
      options,
      value,
      onChange,
      required,
      errorMessage,
      strongLabel,
      hideLabel,
      styling
    } = this.props;

    required = required || false;

    let radioClass = className.concat(
      this.isVertical() ? 'cf-form-radio' : 'cf-form-radio-inline'
    ).concat(
      errorMessage ? 'usa-input-error' : ''
    );

    let labelClass = '';

    if (hideLabel) {
      labelClass += ' usa-sr-only';
    }

    // Since HTML5 IDs should not contain spaces...
    let idPart = StringUtil.html5CompliantId(id || name);

    const labelContents = <span>{(label || name)} {(required && <RequiredIndicator />)}</span>;

    return <fieldset className={radioClass.join(' ')} {...styling}>
      <legend className={labelClass}>
        {
          strongLabel ?
            <strong>{labelContents}</strong> :
            labelContents
        }
      </legend>

      {errorMessage && <span className="usa-input-error-message">{errorMessage}</span>}

      <div className="cf-form-radio-options">
        {options.map((option, i) =>
          <div className="cf-form-radio-option" key={`${idPart}-${option.value}-${i}`}>
            <input
              name={name}
              onChange={(event) => {
                onChange(event.target.value);
              }}
              type="radio"
              id={`${idPart}_${option.value}`}
              value={option.value}
              checked={value === option.value}
              disabled={Boolean(option.disabled)}
            />
            <label className={option.disabled ? 'disabled' : ''}
              htmlFor={`${idPart}_${option.value}`}>{option.displayText || option.displayElem}</label>
          </div>
        )}
      </div>
    </fieldset>;
  }
}

RadioField.defaultProps = {
  className: ['usa-fieldset-inputs']
};

RadioField.propTypes = {
  id: PropTypes.string,
  className: PropTypes.arrayOf(PropTypes.string),
  required: PropTypes.bool,
  label: PropTypes.node,
  name: PropTypes.string.isRequired,
  onChange: PropTypes.func.isRequired,
  options: PropTypes.arrayOf(
    PropTypes.shape({
      displayText: PropTypes.node,
      value: PropTypes.string
    })
  ),
  value: PropTypes.string,
  styling: PropTypes.object
};
