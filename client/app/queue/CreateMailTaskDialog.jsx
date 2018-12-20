import * as React from 'react';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux';
import { withRouter } from 'react-router-dom';

import COPY from '../../COPY.json';
import { onReceiveAmaTasks } from './QueueActions';
import SearchableDropdown from '../components/SearchableDropdown';
import TextareaField from '../components/TextareaField';
import editModalBase from './components/EditModalBase';
import { requestSave } from './uiReducer/uiActions';
import {
  taskById,
  appealWithDetailSelector
} from './selectors';

class CreateMailTaskDialog extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      selectedValue: null,
      instructions: ''
    };
  }

  validateForm = () => this.state.selectedValue !== null && this.state.instructions !== '';

  submit = () => {
    const {
      appeal,
      task
    } = this.props;

    const payload = {
      data: {
        tasks: [{
          type: this.state.selectedValue,
          external_id: appeal.externalId,
          parent_id: task.taskId,
          instructions: this.state.instructions
        }]
      }
    };

    const label = this.taskActionData().options.find((option) => option.value === this.state.selectedValue).label;

    const successMsg = { title: `Created ${label} mail task` };

    return this.props.requestSave('/tasks', payload, successMsg).
      then((resp) => {
        const response = JSON.parse(resp.text);

        this.props.onReceiveAmaTasks(response.tasks.data);
      });
  }

  taskActionData = () => {
    const relevantAction = this.props.task.availableActions.
      find((action) => this.props.history.location.pathname.endsWith(action.value));

    if (relevantAction && relevantAction.data) {
      return relevantAction.data;
    }

    // We should never get here since any task action the creates this modal should provide data.
    throw new Error('Task action requires data');
  }

  render = () => {
    const {
      highlightFormItems,
      task
    } = this.props;

    if (!task || task.availableActions.length === 0) {
      return null;
    }

    return <React.Fragment>
      <SearchableDropdown
        name="Correspondence type selector"
        searchable
        hideLabel
        errorMessage={highlightFormItems && !this.state.selectedValue ? 'Choose one' : null}
        placeholder="Select correspondence type"
        value={this.state.selectedValue}
        onChange={(option) => this.setState({ selectedValue: option ? option.value : null })}
        options={this.taskActionData().options} />
      <br />
      <TextareaField
        name={COPY.ADD_COLOCATED_TASK_INSTRUCTIONS_LABEL}
        errorMessage={highlightFormItems && !this.state.instructions ? COPY.FORM_ERROR_FIELD_REQUIRED : null}
        id="taskInstructions"
        onChange={(value) => this.setState({ instructions: value })}
        value={this.state.instructions} />
    </React.Fragment>;
  }
}

const mapStateToProps = (state, ownProps) => {
  const { highlightFormItems } = state.ui;

  return {
    highlightFormItems,
    task: taskById(state, { taskId: ownProps.taskId }),
    appeal: appealWithDetailSelector(state, ownProps)
  };
};

const mapDispatchToProps = (dispatch) => bindActionCreators({
  requestSave,
  onReceiveAmaTasks
}, dispatch);

export default withRouter(connect(mapStateToProps, mapDispatchToProps)(
  editModalBase(CreateMailTaskDialog, { title: 'Created new mail task' })
));