import React from 'react';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux';
import { LOGO_COLORS } from '../../constants/AppConstants';
import ApiUtil from '../../util/ApiUtil';
import LoadingDataDisplay from '../../components/LoadingDataDisplay';
import ReviewAssignments from '../components/ReviewAssignments';
import { onReceiveSchedulePeriod } from '../actions';

export class ReviewAssignmentsContainer extends React.Component {

  loadSchedulePeriod = () => {
    return ApiUtil.get(`/hearings/schedule_periods/${this.props.match.params.schedulePeriodId}`).then((response) => {
      const resp = ApiUtil.convertToCamelCase(JSON.parse(response.text));
      const schedulePeriod = resp.schedulePeriod;

      this.props.onReceiveSchedulePeriod(schedulePeriod);
    });
  };

  createLoadPromise = () => Promise.all([
    this.loadSchedulePeriod()
  ]);

  render() {
    const loadingDataDisplay = <LoadingDataDisplay
      createLoadPromise={this.createLoadPromise}
      loadingComponentProps={{
        spinnerColor: LOGO_COLORS.HEARING_SCHEDULE.ACCENT,
        message: 'Loading past schedule uploads...'
      }}
      failStatusMessageProps={{
        title: 'Unable to load past schedule uploads.'
      }}>
      <ReviewAssignments
        schedulePeriod={this.props.schedulePeriod}
      />
    </LoadingDataDisplay>;

    return <div>{loadingDataDisplay}</div>;
  }
}

const mapStateToProps = (state) => ({
  schedulePeriod: state.schedulePeriod
});

const mapDispatchToProps = (dispatch) => bindActionCreators({
  onReceiveSchedulePeriod
}, dispatch);

export default connect(mapStateToProps, mapDispatchToProps)(ReviewAssignmentsContainer);