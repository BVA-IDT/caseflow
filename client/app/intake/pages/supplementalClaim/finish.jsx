import React from 'react';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux';
import Button from '../../../components/Button';
import CancelButton from '../../components/CancelButton';
import IssueCounter from '../../components/IssueCounter';
import { completeIntake } from '../../actions/decisionReview';
import { REQUEST_STATE, FORM_TYPES } from '../../constants';
import { issueCountSelector } from '../../selectors';

class FinishNextButton extends React.PureComponent {
  handleClick = () => {
    this.props.completeIntake(this.props.intakeId, this.props.supplementalClaim).then(
      (completeWasSuccessful) => {
        if (completeWasSuccessful) {
          this.props.history.push('/completed');
        }
      }
    );
  }

  buttonText = () => {
    if (this.props.supplementalClaim.processedInCaseflow) {
      return `Establish ${FORM_TYPES.SUPPLEMENTAL_CLAIM.shortName}`;
    }

    return 'Establish EP';
  }

  render = () =>
    <Button
      name="finish-intake"
      onClick={this.handleClick}
      loading={this.props.requestState === REQUEST_STATE.IN_PROGRESS}
      disabled={!this.props.issueCount && !this.props.addedIssues}
    >
      {this.buttonText()}
    </Button>;
}

const FinishNextButtonConnected = connect(
  ({ supplementalClaim, intake }) => ({
    requestState: supplementalClaim.requestStatus.completeIntake,
    intakeId: intake.id,
    supplementalClaim,
    issueCount: issueCountSelector(supplementalClaim)
  }),
  (dispatch) => bindActionCreators({
    completeIntake
  }, dispatch)
)(FinishNextButton);

const mapStateToProps = (state) => {
  return {
    issueCount: issueCountSelector(state.supplementalClaim)
  };
};

const IssueCounterConnected = connect(mapStateToProps)(IssueCounter);

export class FinishButtons extends React.PureComponent {
  render = () =>
    <div>
      <CancelButton />
      <FinishNextButtonConnected history={this.props.history} />
      <IssueCounterConnected />
    </div>
}

