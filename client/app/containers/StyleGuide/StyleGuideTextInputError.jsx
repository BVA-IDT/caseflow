import React from 'react';
import StyleGuideComponentTitle from '../../components/StyleGuideComponentTitle';
import TextField from '../../components/TextField';
import Button from '../../components/Button';

export default class StyleGuideTextInputError extends React.PureComponent {

  constructor(props) {
    super(props);

    this.state = {
      errorMessage: '',
      value: ''
    };
  }

  onButtonClick = () => {
    if (this.state.value === '') {
      this.setState({ errorMessage: 'Helpful error message' });
    } else {
      this.setState({ errorMessage: '' });
    }
  }

  render() {
    return <div>
      <StyleGuideComponentTitle
        title="Text Input Error"
        id="text-input-error"
        link="StyleGuideTextInputError.jsx"
        isSubsection
      />
      <p>Similar to the USWDS we mark fields with a “required” or “optional” label
       to the top fight of the form input type. Our required text is <code>secondary</code>
       as we’ve done research showing that this makes the demarcation more noticeable.
       Similarly, prompting questions have the “required” text immediately following
       the text.</p>
      <TextField
        name="Text Input Label (with error)"
        value={this.state.value}
        required
        onChange={(value) => {
          this.setState({ value });
        }}
        errorMessage={this.state.errorMessage} />
      <Button
        name="Submit"
        onClick={this.onButtonClick} />
    </div>;
  }
}
