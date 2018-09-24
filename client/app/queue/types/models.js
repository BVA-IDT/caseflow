// @flow

export type User = {
  id: number,
  station_id: string,
  css_id: string,
  full_name: string,
  email: ?string,
  roles: Array<string>,
  selected_regional_office: ?string,
  display_name: string,
  judge_css_id: ?string
};

export type Judges = { [string]: User };

export type Address = {
  address_line_1: string,
  address_line_2: string,
  city: string,
  state: string,
  zip: string,
  country: string
};

export type Issue = {
  levels: Array<string>,
  program?: string,
  type: string,
  codes: Array<string>,
  disposition: string,
  close_date: Date,
  note: string,
  id: Number,
  vacols_sequence_id?: Number,
  labels: Array<string>,
  readjudication: Boolean,
  remand_reasons: Array<Object>,
  description?: string
};

export type Issues = Array<Issue>;

export type Task = {
  action: string,
  appealId: number,
  appealType: string,
  externalAppealId: string,
  assignedOn: string,
  dueOn: ?string,
  assignedTo: {
    cssId: ?string,
    type: string,
    id: number
  },
  assignedBy: {
    firstName: string,
    lastName: string,
    cssId: string,
    pgId: number,
  },
  addedByName?: string,
  addedByCssId: ?string,
  taskId: string,
  documentId: ?string,
  workProduct: ?string,
  status?: string,
  placedOnHoldAt?: ?string,
  onHoldDuration?: ?number,
  previousTaskAssignedOn: ?string,
  instructions?: Array<string>,
  parentId?: number,
  decisionPreparedBy: ?{
    firstName: string,
    lastName: string,
  }
};

export type Tasks = { [string]: Task };

export type PowerOfAttorney = {
  representative_type: ?string,
  representative_name: ?string,
  representative_address: ?Address
}

export type AppealDetail = {
  issues: Array<Object>,
  hearings: Array<Object>,
  appellantFullName: string,
  appellantAddress: Address,
  appellantRelationship: string,
  locationCode: ?string,
  veteranDateOfBirth: string,
  veteranGender: string,
  externalId: string,
  status: string,
  decisionDate: string,
  certificationDate: ?string,
  powerOfAttorney: ?PowerOfAttorney,
  regionalOffice: Object,
  caseflowVeteranId: ?string,
  tasks: ?Array<Task>
};

export type AppealDetails = { [string]: AppealDetail };

export type BasicAppeal = {
  id: number,
  type: string,
  externalId: string,
  docketName: ?string,
  isLegacyAppeal: boolean,
  caseType: string,
  isAdvancedOnDocket: boolean,
  docketNumber: string,
  assignedAttorney: ?User,
  assignedJudge: ?User,
  veteranFullName: string,
  veteranFileNumber: string,
  isPaperCase: ?boolean,
  tasks?: Array<Task>
};

export type BasicAppeals = { [string]: BasicAppeal };

export type Appeal = AppealDetail & BasicAppeal;

export type Appeals = { [string]: Appeal };

export type Attorneys = {
  data?: Array<User>,
  error?: Object
};

export type TaskWithAppeal = Task & {
  appeal: Appeal
};
